//
//  WebSocketTests.swift
//  NetworkerTests
//

import Foundation
import Testing
@testable import Networker

/// Plays back scripted `receive()` results, then waits until cancelled, like a quiet open connection.
final class MockWebSocketTask: WebSocketTaskProtocol {
	enum Step: Sendable {
		case message(URLSessionWebSocketTask.Message)
		case failure(URLError)
	}

	private struct State {
		var steps: [Step]
		var sent: [URLSessionWebSocketTask.Message] = []
		var closeCode: URLSessionWebSocketTask.CloseCode?
		var resumed = false
		var waiting: CheckedContinuation<URLSessionWebSocketTask.Message, any Error>?
	}

	private let state: Locked<State>
	let response: URLResponse?

	init(steps: [Step], response: URLResponse? = nil) {
		self.state = Locked(State(steps: steps))
		self.response = response
	}

	var sent: [URLSessionWebSocketTask.Message] { state.value.sent }
	var closeCode: URLSessionWebSocketTask.CloseCode? { state.value.closeCode }
	var resumed: Bool { state.value.resumed }

	func resume() { state.withValue { $0.resumed = true } }

	func receive() async throws -> URLSessionWebSocketTask.Message {
		let next: Step? = state.withValue { $0.steps.isEmpty ? nil : $0.steps.removeFirst() }
		switch next {
			case .message(let message): return message
			case .failure(let error): throw error
			case nil:
				// No more scripted steps: stay open until `cancel(with:reason:)`.
				return try await withCheckedThrowingContinuation { continuation in
					let alreadyClosed = state.withValue { state in
						if state.closeCode != nil { return true }
						state.waiting = continuation
						return false
					}
					if alreadyClosed { continuation.resume(throwing: URLError(.cancelled)) }
				}
		}
	}

	func send(_ message: URLSessionWebSocketTask.Message) async throws {
		state.withValue { $0.sent.append(message) }
	}

	func sendPing(pongReceiveHandler: @escaping @Sendable ((any Error)?) -> Void) {
		pongReceiveHandler(response == nil ? nil : URLError(.badServerResponse))
	}

	func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
		let waiting = state.withValue { state in
			state.closeCode = closeCode
			defer { state.waiting = nil }
			return state.waiting
		}
		waiting?.resume(throwing: URLError(.cancelled))
	}
}

final class MockWebSocketSession: WebSocketSessionProtocol {
	private let requests = Locked<[URLRequest]>([])
	let task: MockWebSocketTask

	init(task: MockWebSocketTask) {
		self.task = task
	}

	var recordedRequests: [URLRequest] { requests.value }

	func makeWebSocketTask(with request: URLRequest) -> any WebSocketTaskProtocol {
		requests.withValue { $0.append(request) }
		return task
	}
}

private struct LiveRequest: HTTPRequestProtocol {
	let id = UUID()
	var baseURL: String { "https://api.example.com" }
	var path: String { "/v1/live" }
	var method: HTTPMethod { .get }
	var headers: [String: String] { ["Accept": "application/json"] }
	var parameters: (any Encodable & Sendable)? { nil }
	var queryParameters: [String: String]? { ["room": "family"] }
	var encoding: HTTPEncoding { .jsonEncoded }
	var requestInterceptors: [any RequestInterceptor] { [BearerInterceptor()] }
}

private struct BearerInterceptor: RequestInterceptor {
	func intercept(_ urlRequest: URLRequest, for request: any HTTPRequestProtocol) async throws -> URLRequest {
		var urlRequest = urlRequest
		urlRequest.setValue("Bearer abc", forHTTPHeaderField: "Authorization")
		return urlRequest
	}
}

@Suite("WebSocket")
struct WebSocketTests {
	private func networker(_ session: MockWebSocketSession, reachable: Bool = true) -> Networker {
		Networker(session: MockURLSession(), webSocketSession: session, reachability: MockReachability(isAvailable: reachable))
	}

	@Test("The upgrade request uses ws(s), the query, headers and request interceptors")
	func buildsRequest() async throws {
		let session = MockWebSocketSession(task: MockWebSocketTask(steps: []))
		let connection = try await networker(session).webSocket(request: LiveRequest())
		defer { connection.close() }

		let request = try #require(session.recordedRequests.first)
		#expect(request.url?.absoluteString == "wss://api.example.com/v1/live?room=family")
		#expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer abc")
		#expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
		#expect(session.task.resumed)
	}

	@Test("Messages arrive in order; close() ends the stream normally")
	func receivesThenCloses() async throws {
		let task = MockWebSocketTask(steps: [.message(.string("one")), .message(.data(Data([1, 2])))])
		let connection = try await networker(MockWebSocketSession(task: task)).webSocket(request: LiveRequest())

		var received: [WebSocketMessage] = []
		for try await message in connection.messages {
			received.append(message)
			if received.count == 2 { connection.close() }
		}
		#expect(received == [.text("one"), .data(Data([1, 2]))])
		#expect(task.closeCode == .normalClosure)
	}

	@Test("A refused handshake ends the stream with the HTTP status")
	func refusedHandshake() async throws {
		let response = HTTPURLResponse(url: URL(string: "wss://api.example.com/v1/live")!, statusCode: 401, httpVersion: nil, headerFields: nil)
		let task = MockWebSocketTask(steps: [.failure(URLError(.badServerResponse))], response: response)
		let connection = try await networker(MockWebSocketSession(task: task)).webSocket(request: LiveRequest())

		do {
			for try await _ in connection.messages {}
			Issue.record("Expected the stream to fail")
		} catch let NetworkingError.badStatus(statusCode, _, _) {
			#expect(statusCode == 401)
		}
	}

	@Test("A ping before a refused handshake reports the HTTP status")
	func pingRefused() async throws {
		let response = HTTPURLResponse(url: URL(string: "wss://api.example.com/v1/live")!, statusCode: 401, httpVersion: nil, headerFields: nil)
		let task = MockWebSocketTask(steps: [.failure(URLError(.badServerResponse))], response: response)
		let connection = try await networker(MockWebSocketSession(task: task)).webSocket(request: LiveRequest())
		defer { connection.close() }

		do {
			try await connection.ping()
			Issue.record("Expected the ping to fail")
		} catch let NetworkingError.badStatus(statusCode, _, _) {
			#expect(statusCode == 401)
		}
	}

	@Test("A dropped connection ends the stream with a transport error")
	func dropped() async throws {
		let task = MockWebSocketTask(steps: [.message(.string("hi")), .failure(URLError(.networkConnectionLost))])
		let connection = try await networker(MockWebSocketSession(task: task)).webSocket(request: LiveRequest())

		await #expect(throws: NetworkingError.self) {
			for try await _ in connection.messages {}
		}
	}

	@Test("send() forwards text to the socket")
	func sends() async throws {
		let session = MockWebSocketSession(task: MockWebSocketTask(steps: []))
		let connection = try await networker(session).webSocket(request: LiveRequest())
		defer { connection.close() }
		try await connection.send(.text("hello"))
		try await connection.ping()

		guard case .string(let text) = session.task.sent.first else {
			Issue.record("Expected a text message")
			return
		}
		#expect(text == "hello")
	}

	@Test("No network fails before connecting")
	func offline() async {
		let session = MockWebSocketSession(task: MockWebSocketTask(steps: []))
		await #expect(throws: NetworkingError.self) {
			_ = try await networker(session, reachable: false).webSocket(request: LiveRequest())
		}
		#expect(session.recordedRequests.isEmpty)
	}
}
