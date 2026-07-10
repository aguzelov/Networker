//
//  MockHTTPRequest.swift
//  NetworkerTests
//
//  Created by Clax on 09.07.26.
//

import Foundation
@testable import Networker

struct MockHTTPRequest: HTTPRequestProtocol {
	var id: UUID = UUID()
	var baseURL: String = "https://example.com"
	var path: String = "/resource"
	var method: HTTPMethod = .get
	var headers: [String: String] = [:]
	var parameters: Encodable?
	var queryParameters: [String: String]?
	var encoding: HTTPEncoding = .jsonEncoded
	var isExtendSession: Bool = false
	var timeoutInterval: TimeInterval = 180
	var retryPolicy: RetryPolicy = .none
	var cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
	var requestInterceptors: [RequestInterceptor] = []
	var responseInterceptors: [ResponseInterceptor] = []
}
