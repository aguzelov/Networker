//
//  URLBuildingTests.swift
//  NetworkerTests
//
//  Created by Clax on 09.07.26.
//

import XCTest
@testable import Networker

final class URLBuildingTests: XCTestCase {
	func testInvalidURLThrows() async throws {
		let session = MockURLSession()
		let networker = Networker(session: session, reachability: MockReachability())
		var request = MockHTTPRequest()
		request.baseURL = ""
		request.path = ""

		do {
			_ = try await networker.request(request: request, logger: nil)
			XCTFail("Expected invalidURL error")
		} catch NetworkingError.invalidURL {
			// expected
		}
	}

	func testQueryParametersAreAppended() async throws {
		let session = MockURLSession()
		let response = HTTPURLResponse(url: URL(string: "https://example.com/resource")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
		session.results = [.success(Data(), response)]

		let networker = Networker(session: session, reachability: MockReachability())
		var request = MockHTTPRequest()
		request.queryParameters = ["a": "1", "b": "2"]

		_ = try await networker.request(request: request, logger: nil)

		let sentURL = try XCTUnwrap(session.recordedRequests.first?.url)
		let components = URLComponents(url: sentURL, resolvingAgainstBaseURL: false)
		let queryItems = try XCTUnwrap(components?.queryItems)
		XCTAssertEqual(Set(queryItems), Set([URLQueryItem(name: "a", value: "1"), URLQueryItem(name: "b", value: "2")]))
	}
}
