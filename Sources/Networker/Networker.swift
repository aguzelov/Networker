//
//  Networker.swift
//  Networker
//
//  Created by Clax on 20.09.25.
//

import Foundation
import SwiftUI

final public class Networker: NSObject, URLSessionDelegate {
	private var session: URLSessionProtocol
	private let reachability: NetworkReachabilityProvider
	private let sessionConfig = URLSessionConfiguration.default
	private let taskRegistry = TaskRegistry()

	private let sessionTimeout = 180 //Move to config

	public init(session: URLSessionProtocol = URLSession.shared, reachability: NetworkReachabilityProvider = NWPathReachability()) {
		self.session = session
		self.reachability = reachability
		super.init()
	}

	public func cancel(id: UUID) {
		Task { await taskRegistry.cancel(id: id) }
	}

	public func cancelAll() {
		Task { await taskRegistry.cancelAll() }
	}

	public func request(request: HTTPRequestProtocol, logger: RequestLoggerProtocol?) async throws -> Data {

		let urlString = request.baseURL + request.path
		guard var url = URL(string: urlString) else { throw NetworkingError.invalidURL(request.path) }

		if let queryParameters = request.queryParameters, !queryParameters.isEmpty {
			var queryItems: [URLQueryItem] = []
			queryParameters.forEach { key, value in
				queryItems.append(URLQueryItem(name: key, value: value))
			}
			url.append(queryItems: queryItems)
		}

		var urlRequest = URLRequest(url: url)
		urlRequest.timeoutInterval = request.timeoutInterval
		urlRequest.cachePolicy = request.cachePolicy
		urlRequest.httpMethod = request.method.value

		if let body = request.parameters {
			let httpBody = encodeHttpBody(body, usingEncoding: request.encoding)
			urlRequest.httpBody = httpBody
		}

		request.headers.forEach {
			urlRequest.setValue($1, forHTTPHeaderField: $0)
		}

		if request.isExtendSession {
			sessionConfig.timeoutIntervalForRequest = TimeInterval(sessionTimeout)
			sessionConfig.timeoutIntervalForResource = TimeInterval(sessionTimeout)
			session = URLSession(configuration: sessionConfig)
		}

		let task = Task<Data, Error> {
			try await self.executeRequestWithRetry(
				baseRequest: urlRequest,
				policy: request.retryPolicy,
				requestID: request.id,
				originalRequest: request,
				logger: logger
			)
		}
		await taskRegistry.register({ task.cancel() }, for: request.id)

		do {
			let data = try await task.value
			await taskRegistry.remove(id: request.id)
			return data
		} catch {
			await taskRegistry.remove(id: request.id)
			if error is CancellationError {
				throw NetworkingError.cancelled
			}
			throw error
		}
	}

	public func download(request: HTTPRequestProtocol, destinationURL: URL, logger: RequestLoggerProtocol?) async throws -> URL {
		let urlString = request.baseURL + request.path
		guard let requestURL = URL(string: urlString) else { throw NetworkingError.invalidURL(request.path) }

		var urlRequest = URLRequest(url: requestURL)
		urlRequest.timeoutInterval = request.timeoutInterval
		urlRequest.cachePolicy = request.cachePolicy
		request.headers.forEach {
			urlRequest.setValue($1, forHTTPHeaderField: $0)
		}

		if request.isExtendSession {
			sessionConfig.timeoutIntervalForRequest = TimeInterval(sessionTimeout)
			sessionConfig.timeoutIntervalForResource = TimeInterval(sessionTimeout)
			session = URLSession(configuration: sessionConfig)
		}

		let task = Task<URL, Error> {
			try await self.executeDownloadWithRetry(
				baseRequest: urlRequest,
				policy: request.retryPolicy,
				requestID: request.id,
				originalRequest: request,
				destinationURL: destinationURL,
				logger: logger
			)
		}
		await taskRegistry.register({ task.cancel() }, for: request.id)

		do {
			let url = try await task.value
			await taskRegistry.remove(id: request.id)
			return url
		} catch {
			await taskRegistry.remove(id: request.id)
			if error is CancellationError {
				throw NetworkingError.cancelled
			}
			throw error
		}
	}

	private func executeRequestWithRetry(
		baseRequest: URLRequest,
		policy: RetryPolicy,
		requestID: UUID,
		originalRequest: HTTPRequestProtocol,
		logger: RequestLoggerProtocol?
	) async throws -> Data {
		var attempt = 1
		while true {
			try Task.checkCancellation()

			if !reachability.isNetworkAvailable() {
				throw NetworkingError.networkNotAvailable
			}

			var urlRequest = baseRequest
			for interceptor in originalRequest.requestInterceptors {
				urlRequest = try await interceptor.intercept(urlRequest, for: originalRequest)
			}

			logger?.log(urlRequest, with: requestID)

			do {
				var (data, response) = try await session.data(for: urlRequest)
				for interceptor in originalRequest.responseInterceptors {
					(data, response) = try await interceptor.intercept(data, response, for: originalRequest)
				}

				logger?.log(response, for: requestID, with: data)

				if let httpResponse = response as? HTTPURLResponse,
				   !(200...299).contains(httpResponse.statusCode) {
					if attempt < policy.maxAttempts, policy.retryableStatusCodes.contains(httpResponse.statusCode) {
						try await Task.sleep(nanoseconds: delayNanoseconds(for: policy.backoff, attempt: attempt))
						attempt += 1
						continue
					}

					throw NetworkingError.badStatus(statusCode: httpResponse.statusCode, data: data, response: httpResponse)
				}

				return data
			} catch let error as URLError {
				if attempt < policy.maxAttempts, policy.retryTransportErrors {
					try await Task.sleep(nanoseconds: delayNanoseconds(for: policy.backoff, attempt: attempt))
					attempt += 1
					continue
				}
				throw NetworkingError.transport(error)
			}
		}
	}

	private func executeDownloadWithRetry(
		baseRequest: URLRequest,
		policy: RetryPolicy,
		requestID: UUID,
		originalRequest: HTTPRequestProtocol,
		destinationURL: URL,
		logger: RequestLoggerProtocol?
	) async throws -> URL {
		var attempt = 1
		while true {
			try Task.checkCancellation()

			if !reachability.isNetworkAvailable() {
				throw NetworkingError.networkNotAvailable
			}

			var urlRequest = baseRequest
			for interceptor in originalRequest.requestInterceptors {
				urlRequest = try await interceptor.intercept(urlRequest, for: originalRequest)
			}

			logger?.log(urlRequest, with: requestID)

			do {
				let (url, response) = try await session.download(for: urlRequest)
				logger?.log(response, for: requestID, with: url)

				let httpResponse = response as? HTTPURLResponse

				if let httpResponse, (200...299).contains(httpResponse.statusCode) {
					try FileManager.default.moveItem(at: url, to: destinationURL)
					return destinationURL
				}

				if let httpResponse,
				   attempt < policy.maxAttempts,
				   policy.retryableStatusCodes.contains(httpResponse.statusCode) {
					try await Task.sleep(nanoseconds: delayNanoseconds(for: policy.backoff, attempt: attempt))
					attempt += 1
					continue
				}

				guard let httpResponse else {
					throw NetworkingError.transport(URLError(.badServerResponse))
				}

				let data = (try? Data(contentsOf: url)) ?? Data()
				throw NetworkingError.badStatus(statusCode: httpResponse.statusCode, data: data, response: httpResponse)
			} catch let error as URLError {
				if attempt < policy.maxAttempts, policy.retryTransportErrors {
					try await Task.sleep(nanoseconds: delayNanoseconds(for: policy.backoff, attempt: attempt))
					attempt += 1
					continue
				}
				throw NetworkingError.transport(error)
			}
		}
	}

	private func delayNanoseconds(for backoff: RetryPolicy.Backoff, attempt: Int) -> UInt64 {
		let seconds = backoff.delay(forAttempt: attempt)
		guard seconds > 0 else { return 0 }
		return UInt64(seconds * 1_000_000_000)
	}

	private func encodeHttpBody<Body: Encodable>(_ body: Body, usingEncoding encoding: HTTPEncoding) -> Data? {
		let encoder = JSONEncoder()
		let jsonData = try? encoder.encode(body)
		switch encoding {
			case .jsonEncoded:
				return jsonData
			case .urlFormEncoded:
				guard let jsonData,
					  let json = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any]
				else {
					return nil
				}
				var components = URLComponents()
				components.queryItems = json.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
				return components.query?.data(using: .utf8)
		}
	}
}
