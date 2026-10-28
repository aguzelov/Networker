//
//  WebSocketSessionProtocol.swift
//  Networker
//

import Foundation

/// The parts of `URLSessionWebSocketTask` that `WebSocketConnection` uses. A seam for tests, like `URLSessionProtocol`.
public protocol WebSocketTaskProtocol: Sendable {
	/// The handshake response, once there is one. Used to report why a connection was refused (e.g. `401`).
	var response: URLResponse? { get }
	func resume()
	func receive() async throws -> URLSessionWebSocketTask.Message
	func send(_ message: URLSessionWebSocketTask.Message) async throws
	func sendPing(pongReceiveHandler: @escaping @Sendable ((any Error)?) -> Void)
	func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
}

/// Creates WebSocket tasks. `URLSession` conforms; tests inject a mock.
public protocol WebSocketSessionProtocol: Sendable {
	func makeWebSocketTask(with request: URLRequest) -> any WebSocketTaskProtocol
}

extension URLSessionWebSocketTask: WebSocketTaskProtocol {}

extension URLSession: WebSocketSessionProtocol {
	public func makeWebSocketTask(with request: URLRequest) -> any WebSocketTaskProtocol {
		webSocketTask(with: request)
	}
}
