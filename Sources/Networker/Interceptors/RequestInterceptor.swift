//
//  RequestInterceptor.swift
//  Networker
//
//  Created by Clax on 09.07.26.
//

import Foundation

public protocol RequestInterceptor: Sendable {
	func intercept(_ urlRequest: URLRequest, for request: any HTTPRequestProtocol) async throws -> URLRequest
}
