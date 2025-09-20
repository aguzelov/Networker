//
//  HTTPRequestProtocol.swift
//  Torbichka
//
//  Created by Clax on 20.09.25.
//

import Foundation

public protocol HTTPRequestProtocol {
	var id: UUID { get }
	var baseURL: String { get }
	var path: String { get }
	var method: HTTPMethod { get }
	var headers: [String: String] { get }
	var parameters: Encodable? { get }
	var queryParameters: [String: String]? { get }
	var encoding: HTTPEncoding { get }
	var isExtendSession: Bool { get }
}
