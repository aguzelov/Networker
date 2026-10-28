//
//  WebSocketConnection.swift
//  Networker
//

import Foundation

/// A message received or sent over a WebSocket.
public enum WebSocketMessage: Sendable, Equatable {
	case text(String)
	case data(Data)
}

/// An open WebSocket. Incoming messages arrive on `messages`, an `AsyncThrowingStream`:
///
/// - It finishes normally after `close()`.
/// - It finishes with a `NetworkingError` when the connection fails: `.badStatus` when the server refused the
///   handshake (e.g. `401`), `.transport` when the connection dropped.
///
/// There is no automatic reconnect: when to retry, and how often, is the app's decision.
public final class WebSocketConnection: Sendable {
	public let messages: AsyncThrowingStream<WebSocketMessage, any Error>

	private let task: any WebSocketTaskProtocol
	private let closed = ProtectedValue(false)

	init(task: any WebSocketTaskProtocol) {
		self.task = task
		let (stream, continuation) = AsyncThrowingStream<WebSocketMessage, any Error>.makeStream()
		self.messages = stream

		let closed = self.closed
		let receiveLoop = Task {
			do {
				while !Task.isCancelled {
					switch try await task.receive() {
						case .string(let text): continuation.yield(.text(text))
						case .data(let data): continuation.yield(.data(data))
						@unknown default: continue
					}
				}
				continuation.finish()
			} catch {
				// Closing on purpose makes `receive()` throw too; that's a normal end, not a failure.
				closed.value ? continuation.finish() : continuation.finish(throwing: Self.map(error, response: task.response))
			}
		}
		// Stopping iteration (e.g. the consuming task was cancelled) closes the socket.
		continuation.onTermination = { [weak self] _ in
			receiveLoop.cancel()
			self?.close()
		}
		task.resume()
	}

	public func send(_ message: WebSocketMessage) async throws {
		do {
			switch message {
				case .text(let text): try await task.send(.string(text))
				case .data(let data): try await task.send(.data(data))
			}
		} catch {
			throw Self.map(error, response: task.response)
		}
	}

	/// Sends a ping and waits for the pong: a quick way to check that the connection is still alive.
	/// Before the handshake has finished, it also reports a refused handshake (e.g. `.badStatus(401)`).
	public func ping() async throws {
		let task = self.task
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
			task.sendPing { error in
				if let error { continuation.resume(throwing: Self.map(error, response: task.response)) } else { continuation.resume() }
			}
		}
	}

	/// Closes the connection. `messages` then finishes normally. Calling it again does nothing.
	public func close() {
		let alreadyClosed = closed.withValue { closed in
			defer { closed = true }
			return closed
		}
		guard !alreadyClosed else { return }
		task.cancel(with: .normalClosure, reason: nil)
	}

	/// A refused handshake shows up as a failed `receive()`; the task's HTTP response tells why.
	static func map(_ error: any Error, response: URLResponse?) -> NetworkingError {
		if let http = response as? HTTPURLResponse, http.statusCode != 101 {
			return .badStatus(statusCode: http.statusCode, data: Data(), response: http)
		}
		if let error = error as? NetworkingError { return error }
		if let error = error as? URLError { return error.code == .cancelled ? .cancelled : .transport(error) }
		return .transport(URLError(.networkConnectionLost))
	}
}

/// A value shared across tasks; every access goes through the lock, which is what makes `@unchecked Sendable` true.
final class ProtectedValue<Value>: @unchecked Sendable {
	private let lock = NSLock()
	private var storage: Value

	init(_ value: Value) {
		self.storage = value
	}

	var value: Value {
		get { lock.withLock { storage } }
		set { lock.withLock { storage = newValue } }
	}

	func withValue<T>(_ body: (inout Value) throws -> T) rethrows -> T {
		try lock.withLock { try body(&storage) }
	}
}
