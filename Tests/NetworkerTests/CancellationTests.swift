//
//  CancellationTests.swift
//  NetworkerTests
//
//  Created by Clax on 09.07.26.
//
import XCTest
@testable import Networker

final class SlowMockURLSession: URLSessionProtocol {
	func data(for request: URLRequest) async throws -> (Data, URLResponse) {
		try await Task.sleep(nanoseconds: 2_000_000_000)
		let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
		return (Data(), response)
	}

	func download(for request: URLRequest) async throws -> (URL, URLResponse) {
		try await Task.sleep(nanoseconds: 2_000_000_000)
		let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
		return (FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), response)
	}
}

final class CancellationTests: XCTestCase {
	func testCancelByIDThrowsCancelled() async throws {
		let networker = Networker(session: SlowMockURLSession(), reachability: MockReachability())
		let request = MockHTTPRequest()

		let resultTask = Task {
			try await networker.request(request: request, logger: nil)
		}

		try await Task.sleep(nanoseconds: 100_000_000)
		networker.cancel(id: request.id)

		do {
			_ = try await resultTask.value
			XCTFail("Expected cancellation error")
		} catch NetworkingError.cancelled {
			// expected
		}
	}

	func testCancelAllCancelsMultipleInFlightRequests() async throws {
		let networker = Networker(session: SlowMockURLSession(), reachability: MockReachability())
		let requestA = MockHTTPRequest()
		let requestB = MockHTTPRequest()

		let taskA = Task { try await networker.request(request: requestA, logger: nil) }
		let taskB = Task { try await networker.request(request: requestB, logger: nil) }

		try await Task.sleep(nanoseconds: 100_000_000)
		networker.cancelAll()

		for task in [taskA, taskB] {
			do {
				_ = try await task.value
				XCTFail("Expected cancellation error")
			} catch NetworkingError.cancelled {
				// expected
			}
		}
	}
}
