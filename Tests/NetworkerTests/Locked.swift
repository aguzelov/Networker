//
//  Locked.swift
//  NetworkerTests
//

import Foundation

/// Mutable test state shared across tasks. Every access goes through the lock, which is what makes the
/// `@unchecked Sendable` promise true.
final class Locked<Value>: @unchecked Sendable {
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
