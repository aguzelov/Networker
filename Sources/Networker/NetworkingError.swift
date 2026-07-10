//
//  NetworkingError.swift
//  Networker
//
//  Created by Clax on 09.07.26.
//

import Foundation

public enum NetworkingError: Error {
	case invalidURL(String)
	case networkNotAvailable
	case transport(URLError)
	case badStatus(statusCode: Int, data: Data, response: HTTPURLResponse)
	case cancelled
}

extension NetworkingError: LocalizedError {
	public var errorDescription: String? {
		switch self {
			case .invalidURL(let path):
				return "Invalid URL: \(path)"
			case .networkNotAvailable:
				return "Network not available"
			case .transport(let error):
				return error.localizedDescription
			case .badStatus(let statusCode, let data, _):
				var message = "Status Code: \(statusCode)"
				if let body = String(data: data, encoding: .utf8), !body.isEmpty {
					message.append(" \n Error: \(body)")
				}
				return message
			case .cancelled:
				return "Request cancelled"
		}
	}
}
