//
//  RequestInterceptor.swift
//  Networker
//
//  Created by Clax on 09.07.26.
//

import Foundation

public protocol RequestInterceptor {
	func intercept(_ urlRequest: URLRequest, for request: HTTPRequestProtocol) async throws -> URLRequest
}
