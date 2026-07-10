//
//  TaskRegistry.swift
//  Networker
//
//  Created by Clax on 09.07.26.
//

import Foundation

actor TaskRegistry {
	private var cancelHandlers: [UUID: @Sendable () -> Void] = [:]

	func register(_ cancel: @escaping @Sendable () -> Void, for id: UUID) {
		cancelHandlers[id] = cancel
	}

	func remove(id: UUID) {
		cancelHandlers[id] = nil
	}

	func cancel(id: UUID) {
		cancelHandlers[id]?()
		cancelHandlers[id] = nil
	}

	func cancelAll() {
		cancelHandlers.values.forEach { $0() }
		cancelHandlers.removeAll()
	}
}
