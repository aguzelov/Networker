//
//  NetworkReachability.swift
//  Networker
//

import Foundation
import Network
import os

public protocol NetworkReachabilityProvider {
	func isNetworkAvailable() -> Bool
}

private let reachabilityLogger = Logger(subsystem: "Networker", category: "Reachability")

public final class NWPathReachability: NetworkReachabilityProvider {
	private let monitor = NWPathMonitor()

	public init() {
		let queue = DispatchQueue(label: "NetworkMonitoring")
		monitor.pathUpdateHandler = { path in
			reachabilityLogger.debug("Network status changed to: \(path.status == .satisfied ? "available" : "not available")")
		}
		monitor.start(queue: queue)
	}

	deinit {
		monitor.cancel()
	}

	public func isNetworkAvailable() -> Bool {
		monitor.currentPath.status == .satisfied
	}
}
