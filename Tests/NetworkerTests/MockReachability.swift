//
//  MockReachability.swift
//  NetworkerTests
//

import Foundation
@testable import Networker

struct MockReachability: NetworkReachabilityProvider {
	var isAvailable: Bool = true

	func isNetworkAvailable() -> Bool {
		isAvailable
	}
}
