//
//  MockRequestLogger.swift
//  NetworkerTests
//
//  Created by Clax on 09.07.26.
//

import Foundation
@testable import Networker

final class MockRequestLogger: RequestLoggerProtocol {
	private let requests = Locked<[(URLRequest, UUID)]>([])
	private let dataResponses = Locked<[(URLResponse, UUID, Data)]>([])
	private let urlResponses = Locked<[(URLResponse, UUID, URL)]>([])

	var loggedRequests: [(URLRequest, UUID)] { requests.value }
	var loggedDataResponses: [(URLResponse, UUID, Data)] { dataResponses.value }
	var loggedURLResponses: [(URLResponse, UUID, URL)] { urlResponses.value }

	func log(_ request: URLRequest, with requestID: UUID) {
		requests.withValue { $0.append((request, requestID)) }
	}

	func log(_ response: URLResponse, for requestID: UUID, with data: Data) {
		dataResponses.withValue { $0.append((response, requestID, data)) }
	}

	func log(_ response: URLResponse, for requestID: UUID, with url: URL) {
		urlResponses.withValue { $0.append((response, requestID, url)) }
	}
}
