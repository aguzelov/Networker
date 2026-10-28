//
//  ResponseInterceptor.swift
//  Networker
//
//  Created by Clax on 09.07.26.
//
import Foundation

public protocol ResponseInterceptor: Sendable {
	func intercept(_ data: Data, _ response: URLResponse, for request: any HTTPRequestProtocol) async throws -> (Data, URLResponse)
}
