//
//  MockRequestLogger.swift
//  NetworkerTests
//
//  Created by Clax on 09.07.26.
//

import Foundation
@testable import Networker

final class MockRequestLogger: RequestLoggerProtocol {
	private(set) var loggedRequests: [(URLRequest, UUID)] = []
	private(set) var loggedDataResponses: [(URLResponse, UUID, Data)] = []
	private(set) var loggedURLResponses: [(URLResponse, UUID, URL)] = []

	func log(_ request: URLRequest, with requestID: UUID) {
		loggedRequests.append((request, requestID))
	}

	func log(_ response: URLResponse, for requestID: UUID, with data: Data) {
		loggedDataResponses.append((response, requestID, data))
	}

	func log(_ response: URLResponse, for requestID: UUID, with url: URL) {
		loggedURLResponses.append((response, requestID, url))
	}
}
