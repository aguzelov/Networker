//
//  MockURLSession.swift
//  NetworkerTests
//
//  Created by Clax on 09.07.26.
//

import Foundation
@testable import Networker

final class MockURLSession: URLSessionProtocol {
	enum Result {
		case success(Data, URLResponse)
		case failure(Error)
	}

	private(set) var recordedRequests: [URLRequest] = []

	/// One result per call to `data(for:)`/`download(for:)`, consumed in order.
	/// If fewer results than calls are provided, the last one is reused.
	var results: [Result] = []
	private var callCount = 0

	/// Optional temp file location used to back `download(for:)` results.
	var downloadFileURL: URL?

	func data(for request: URLRequest) async throws -> (Data, URLResponse) {
		recordedRequests.append(request)
		let result = nextResult()
		switch result {
			case .success(let data, let response):
				return (data, response)
			case .failure(let error):
				throw error
		}
	}

	func download(for request: URLRequest) async throws -> (URL, URLResponse) {
		recordedRequests.append(request)
		let result = nextResult()
		switch result {
			case .success(_, let response):
				let url = downloadFileURL ?? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
				return (url, response)
			case .failure(let error):
				throw error
		}
	}

	private func nextResult() -> Result {
		defer { callCount += 1 }
		guard !results.isEmpty else {
			fatalError("MockURLSession has no configured results")
		}
		let index = min(callCount, results.count - 1)
		return results[index]
	}

	var callCountValue: Int { callCount }
}
