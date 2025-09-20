//
//  RequestLogger.swift
//  Torbichka
//
//  Created by Clax on 20.09.25.
//

import Foundation

public protocol RequestLoggerProtocol {
	func log(_ request: URLRequest, with requestID: UUID)
	func log(_ response: URLResponse, for requestID: UUID, with data: Data)
	func log(_ response: URLResponse, for requestID: UUID, with url: URL)
}
