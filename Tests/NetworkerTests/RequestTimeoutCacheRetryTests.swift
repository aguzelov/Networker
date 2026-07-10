//
//  RequestTimeoutCacheRetryTests.swift
//  NetworkerTests
//
//  Created by Clax on 09.07.26.
//

import XCTest
@testable import Networker

final class RequestTimeoutCacheRetryTests: XCTestCase {
	func testTimeoutAndCachePolicyAreAppliedFromRequest() async throws {
		let session = MockURLSession()
		let response = HTTPURLResponse(url: URL(string: "https://example.com/resource")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
		session.results = [.success(Data(), response)]

		let networker = Networker(session: session, reachability: MockReachability())
		var request = MockHTTPRequest()
		request.timeoutInterval = 42
		request.cachePolicy = .reloadIgnoringLocalCacheData

		_ = try await networker.request(request: request, logger: nil)

		let sent = try XCTUnwrap(session.recordedRequests.first)
		XCTAssertEqual(sent.timeoutInterval, 42)
		XCTAssertEqual(sent.cachePolicy, .reloadIgnoringLocalCacheData)
	}

	func testRetriesOnRetryableStatusCodeUntilSuccess() async throws {
		let session = MockURLSession()
		let url = URL(string: "https://example.com/resource")!
		let failing = HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: nil)!
		let succeeding = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
		session.results = [
			.success(Data(), failing),
			.success(Data(), failing),
			.success(Data(), succeeding),
		]

		let networker = Networker(session: session, reachability: MockReachability())
		var request = MockHTTPRequest()
		request.retryPolicy = .fixed(attempts: 3, delay: 0)

		_ = try await networker.request(request: request, logger: nil)

		XCTAssertEqual(session.recordedRequests.count, 3)
	}

	func testStopsRetryingAfterMaxAttemptsAndThrowsBadStatus() async throws {
		let session = MockURLSession()
		let url = URL(string: "https://example.com/resource")!
		let failing = HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: nil)!
		session.results = [.success(Data(), failing)]

		let networker = Networker(session: session, reachability: MockReachability())
		var request = MockHTTPRequest()
		request.retryPolicy = .fixed(attempts: 2, delay: 0)

		do {
			_ = try await networker.request(request: request, logger: nil)
			XCTFail("Expected badStatus error")
		} catch NetworkingError.badStatus(let statusCode, _, _) {
			XCTAssertEqual(statusCode, 503)
			XCTAssertEqual(session.recordedRequests.count, 2)
		}
	}

	func testRetriesOnTransportErrorWhenEnabled() async throws {
		let session = MockURLSession()
		let url = URL(string: "https://example.com/resource")!
		let succeeding = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
		session.results = [
			.failure(URLError(.timedOut)),
			.success(Data(), succeeding),
		]

		let networker = Networker(session: session, reachability: MockReachability())
		var request = MockHTTPRequest()
		request.retryPolicy = .fixed(attempts: 2, delay: 0)

		_ = try await networker.request(request: request, logger: nil)

		XCTAssertEqual(session.recordedRequests.count, 2)
	}

	func testDoesNotRetryWhenPolicyIsNone() async throws {
		let session = MockURLSession()
		let url = URL(string: "https://example.com/resource")!
		let failing = HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: nil)!
		session.results = [.success(Data(), failing)]

		let networker = Networker(session: session, reachability: MockReachability())
		let request = MockHTTPRequest() // retryPolicy defaults to .none

		do {
			_ = try await networker.request(request: request, logger: nil)
			XCTFail("Expected badStatus error")
		} catch NetworkingError.badStatus {
			XCTAssertEqual(session.recordedRequests.count, 1)
		}
	}
}
