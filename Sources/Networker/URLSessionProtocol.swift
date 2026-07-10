//
//  URLSessionProtocol.swift
//  Networker
//
//  Created by Clax on 09.07.26.
//

import Foundation

public protocol URLSessionProtocol {
	func data(for request: URLRequest) async throws -> (Data, URLResponse)
	func download(for request: URLRequest) async throws -> (URL, URLResponse)
}

extension URLSession: URLSessionProtocol {
	public func download(for request: URLRequest) async throws -> (URL, URLResponse) {
		try await download(for: request, delegate: nil)
	}
}
