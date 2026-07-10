//
//  InterceptorTests.swift
//  NetworkerTests
//
//  Created by Clax on 09.07.26.
//

import XCTest
@testable import Networker

private final class RecordingRequestInterceptor: RequestInterceptor {
	let tag: String
	static var callOrder: [String] = []

	init(tag: String) {
		self.tag = tag
	}

	func intercept(_ urlRequest: URLRequest, for request: HTTPRequestProtocol) async throws -> URLRequest {
		Self.callOrder.append(tag)
		var urlRequest = urlRequest
		urlRequest.setValue(tag, forHTTPHeaderField: "X-\(tag)")
		return urlRequest
	}
}

private struct RecordingResponseInterceptor: ResponseInterceptor {
	func intercept(_ data: Data, _ response: URLResponse, for request: HTTPRequestProtocol) async throws -> (Data, URLResponse) {
		let transformed = data + "-transformed".data(using: .utf8)!
		return (transformed, response)
	}
}

final class InterceptorTests: XCTestCase {
	override func setUp() {
		super.setUp()
		RecordingRequestInterceptor.callOrder = []
	}

	func testRequestInterceptorsRunInOrderAndMutateHeaders() async throws {
		let session = MockURLSession()
		let url = URL(string: "https://example.com/resource")!
		let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
		session.results = [.success(Data(), response)]

		let networker = Networker(session: session, reachability: MockReachability())
		var request = MockHTTPRequest()
		request.requestInterceptors = [
			RecordingRequestInterceptor(tag: "first"),
			RecordingRequestInterceptor(tag: "second"),
		]

		_ = try await networker.request(request: request, logger: nil)

		XCTAssertEqual(RecordingRequestInterceptor.callOrder, ["first", "second"])
		let sent = try XCTUnwrap(session.recordedRequests.first)
		XCTAssertEqual(sent.value(forHTTPHeaderField: "X-first"), "first")
		XCTAssertEqual(sent.value(forHTTPHeaderField: "X-second"), "second")
	}

	func testResponseInterceptorTransformsData() async throws {
		let session = MockURLSession()
		let url = URL(string: "https://example.com/resource")!
		let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
		session.results = [.success("original".data(using: .utf8)!, response)]

		let networker = Networker(session: session, reachability: MockReachability())
		var request = MockHTTPRequest()
		request.responseInterceptors = [RecordingResponseInterceptor()]

		let data = try await networker.request(request: request, logger: nil)

		XCTAssertEqual(String(data: data, encoding: .utf8), "original-transformed")
	}
}
