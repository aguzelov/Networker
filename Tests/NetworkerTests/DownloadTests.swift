//
//  DownloadTests.swift
//  NetworkerTests
//
//  Created by Clax on 09.07.26.
//

import XCTest
@testable import Networker

final class DownloadTests: XCTestCase {
	private func makeTempFile(contents: Data) throws -> URL {
		let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try contents.write(to: url)
		return url
	}

	func testNonExact200StatusStillSucceeds() async throws {
		let session = MockURLSession()
		let url = URL(string: "https://example.com/file")!
		let response = HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: nil)!
		let contents = "file contents".data(using: .utf8)!
		session.downloadFileURL = try makeTempFile(contents: contents)
		session.results = [.success(Data(), response)]

		let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		defer { try? FileManager.default.removeItem(at: destination) }

		let networker = Networker(session: session, reachability: MockReachability())
		let resultURL = try await networker.download(request: MockHTTPRequest(), destinationURL: destination, logger: nil)

		XCTAssertEqual(resultURL, destination)
		XCTAssertEqual(try Data(contentsOf: destination), contents)
	}

	func testNonSuccessStatusThrowsInsteadOfReturningNil() async throws {
		let session = MockURLSession()
		let url = URL(string: "https://example.com/file")!
		let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
		session.downloadFileURL = try makeTempFile(contents: Data())
		session.results = [.success(Data(), response)]

		let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

		let networker = Networker(session: session, reachability: MockReachability())

		do {
			_ = try await networker.download(request: MockHTTPRequest(), destinationURL: destination, logger: nil)
			XCTFail("Expected badStatus error")
		} catch NetworkingError.badStatus(let statusCode, _, _) {
			XCTAssertEqual(statusCode, 404)
		} catch let error {
			if error is NetworkingError {
				print(error)
			}
		}
	}

	func testSuccessMovesRatherThanCopiesTheDownloadedFile() async throws {
		let session = MockURLSession()
		let url = URL(string: "https://example.com/file")!
		let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
		let sourceURL = try makeTempFile(contents: "payload".data(using: .utf8)!)
		session.downloadFileURL = sourceURL
		session.results = [.success(Data(), response)]

		let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		defer { try? FileManager.default.removeItem(at: destination) }

		let networker = Networker(session: session, reachability: MockReachability())
		_ = try await networker.download(request: MockHTTPRequest(), destinationURL: destination, logger: nil)

		XCTAssertFalse(FileManager.default.fileExists(atPath: sourceURL.path), "source temp file should have been moved, not copied")
		XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
	}
}
