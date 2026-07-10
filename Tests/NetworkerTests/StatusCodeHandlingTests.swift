//
//  StatusCodeHandlingTests.swift
//  NetworkerTests
//
//  Created by Clax on 09.07.26.
//

import XCTest
@testable import Networker

final class StatusCodeHandlingTests: XCTestCase {
	func testSuccessStatusReturnsData() async throws {
		let session = MockURLSession()
		let url = URL(string: "https://example.com/resource")!
		let response = HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: nil)!
		let payload = "hello".data(using: .utf8)!
		session.results = [.success(payload, response)]

		let networker = Networker(session: session, reachability: MockReachability())
		let data = try await networker.request(request: MockHTTPRequest(), logger: nil)

		XCTAssertEqual(data, payload)
	}

	func testNonSuccessStatusThrowsBadStatusWithBody() async throws {
		let session = MockURLSession()
		let url = URL(string: "https://example.com/resource")!
		let response = HTTPURLResponse(url: url, statusCode: 400, httpVersion: nil, headerFields: nil)!
		let body = "bad input".data(using: .utf8)!
		session.results = [.success(body, response)]

		let networker = Networker(session: session, reachability: MockReachability())

		do {
			_ = try await networker.request(request: MockHTTPRequest(), logger: nil)
			XCTFail("Expected badStatus error")
		} catch NetworkingError.badStatus(let statusCode, let data, _) {
			XCTAssertEqual(statusCode, 400)
			XCTAssertEqual(data, body)
		}
	}
}
