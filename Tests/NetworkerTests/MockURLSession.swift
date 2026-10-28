//
//  MockURLSession.swift
//  NetworkerTests
//
//  Created by Clax on 09.07.26.
//

import Foundation
@testable import Networker

final class MockURLSession: URLSessionProtocol {
	enum Result: Sendable {
		case success(Data, URLResponse)
		case failure(any Error & Sendable)
	}

	private struct State {
		var recordedRequests: [URLRequest] = []
		var results: [Result] = []
		var callCount = 0
		var downloadFileURL: URL?
	}

	private let state = Locked(State())

	var recordedRequests: [URLRequest] { state.value.recordedRequests }

	/// One result per call to `data(for:)`/`download(for:)`, consumed in order.
	/// If fewer results than calls are provided, the last one is reused.
	var results: [Result] {
		get { state.value.results }
		set { state.withValue { $0.results = newValue } }
	}

	/// Optional temp file location used to back `download(for:)` results.
	var downloadFileURL: URL? {
		get { state.value.downloadFileURL }
		set { state.withValue { $0.downloadFileURL = newValue } }
	}

	var callCountValue: Int { state.value.callCount }

	func data(for request: URLRequest) async throws -> (Data, URLResponse) {
		switch nextResult(recording: request) {
			case .success(let data, let response):
				return (data, response)
			case .failure(let error):
				throw error
		}
	}

	func download(for request: URLRequest) async throws -> (URL, URLResponse) {
		switch nextResult(recording: request) {
			case .success(_, let response):
				let url = downloadFileURL ?? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
				return (url, response)
			case .failure(let error):
				throw error
		}
	}

	private func nextResult(recording request: URLRequest) -> Result {
		state.withValue { state in
			state.recordedRequests.append(request)
			defer { state.callCount += 1 }
			guard !state.results.isEmpty else {
				fatalError("MockURLSession has no configured results")
			}
			return state.results[min(state.callCount, state.results.count - 1)]
		}
	}
}
