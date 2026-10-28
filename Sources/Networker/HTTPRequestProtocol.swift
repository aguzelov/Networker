//
//  HTTPRequestProtocol.swift
//  Networker
//
//  Created by Clax on 20.09.25.
//

import Foundation

public protocol HTTPRequestProtocol: Sendable {
	var id: UUID { get }
	var baseURL: String { get }
	var path: String { get }
	var method: HTTPMethod { get }
	var headers: [String: String] { get }
	var parameters: (any Encodable & Sendable)? { get }
	var queryParameters: [String: String]? { get }
	var encoding: HTTPEncoding { get }
	var timeoutInterval: TimeInterval { get }
	var retryPolicy: RetryPolicy { get }
	var cachePolicy: URLRequest.CachePolicy { get }
	var requestInterceptors: [any RequestInterceptor] { get }
	var responseInterceptors: [any ResponseInterceptor] { get }
}

public extension HTTPRequestProtocol {
	var timeoutInterval: TimeInterval { 180 }
	var retryPolicy: RetryPolicy { return .none }
	var cachePolicy: URLRequest.CachePolicy { return .useProtocolCachePolicy }
	var requestInterceptors: [any RequestInterceptor] { [] }
	var responseInterceptors: [any ResponseInterceptor] { [] }
}
