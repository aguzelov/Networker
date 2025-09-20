//
//  Networker.swift
//  Torbichka
//
//  Created by Clax on 20.09.25.
//

import Foundation
import SwiftUI
import Loggable

enum NetworkError: Error {
	case invalidURL(String)
	case badRequest(statusCode: String)
	case networkNotAvailable
}

final public class Networker: NSObject, URLSessionDelegate, NetworkReachabilityProtocol, Loggable {
	internal var networkPathMonitor: NetworkPathMonitor?
	
	private var session = URLSession.shared
	private let sessionConfig = URLSessionConfiguration.default
	
	private let requestTimeout = 180 //Move to config
	private let sessionTimeout = 180 //Move to config
	
	public override init() {
		super.init()
		self.startNetworkMonitoring()
	}
	
	deinit {
		self.stopNetworkMonitoring()
	}
	
	public func request(request: HTTPRequestProtocol, logger: RequestLoggerProtocol?) async throws -> Data {
		
		let urlString = request.baseURL + request.path
		guard var url = URL(string: urlString) else { throw NetworkError.invalidURL(request.path) }
		
		if let queryParameters = request.queryParameters, !queryParameters.isEmpty {
			var queryItems: [URLQueryItem] = []
			queryParameters.forEach { key, value in
				queryItems.append(URLQueryItem(name: key, value: value))
			}
			url.append(queryItems: queryItems)
		}
		
		var urlRequest = URLRequest(url: url)
		urlRequest.timeoutInterval = TimeInterval(requestTimeout)
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
		
		if !isNetworkAvailable() {
			throw NetworkError.networkNotAvailable
		}
		
		logger?.log(urlRequest, with: request.id)
		
		let (data, response) = try await session.data(for: urlRequest)
		
		logger?.log(response, for: request.id, with: data)
		
		if let statusCode = (response as? HTTPURLResponse)?.statusCode,
		   !(200...299).contains(statusCode) {
			var errorMessage = "Statu Code: \(statusCode)"
			if let error = String(data: data, encoding: .utf8) {
				errorMessage.append(" \n Error: \(error)")
			}
			throw NetworkError.badRequest(statusCode: errorMessage)
		}
		
		return data
	}
	
	public func download(request: HTTPRequestProtocol, destinationURL: URL, logger: RequestLoggerProtocol?) async throws -> URL? {
		let urlString = request.baseURL + request.path
		guard let requestURL = URL(string: urlString) else { throw NetworkError.invalidURL(request.path) }
		
		var urlRequest = URLRequest(url: requestURL)
		request.headers.forEach {
			urlRequest.setValue($1, forHTTPHeaderField: $0)
		}
		
		if request.isExtendSession {
			sessionConfig.timeoutIntervalForRequest = TimeInterval(sessionTimeout)
			sessionConfig.timeoutIntervalForResource = TimeInterval(sessionTimeout)
			session = URLSession(configuration: sessionConfig)
		}
		
		if !isNetworkAvailable() {
			throw NetworkError.networkNotAvailable
		}
		
		logger?.log(urlRequest, with: request.id)
		let (url, response) = try await session.download(for: urlRequest)
		logger?.log(response, for: request.id, with: url)
		if let response = response as? HTTPURLResponse, response.statusCode == 200 {
			let imageData = try Data(contentsOf: url)
			try imageData.write(to: destinationURL)
			return destinationURL
		} else {
			return nil
		}
	}
	
	func networkStatusChanged(isConnected: Bool) {
		logDebug("NetworkStatusChanged called - \(isConnected)", subsystem: "\(Networker.self)")
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
