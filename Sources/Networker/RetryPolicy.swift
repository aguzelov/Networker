//
//  RetryPolicy.swift
//  Networker
//
//  Created by Clax on 09.07.26.
//

import Foundation

public struct RetryPolicy {
	public enum Backoff {
		case none
		case fixed(delay: TimeInterval)
		case exponential(baseDelay: TimeInterval, multiplier: Double = 2.0, maxDelay: TimeInterval = 30)

		func delay(forAttempt attempt: Int) -> TimeInterval {
			switch self {
				case .none:
					return 0
				case .fixed(let delay):
					return delay
				case .exponential(let baseDelay, let multiplier, let maxDelay):
					let computed = baseDelay * pow(multiplier, Double(attempt - 1))
					return min(computed, maxDelay)
			}
		}
	}

	public var maxAttempts: Int
	public var backoff: Backoff
	public var retryableStatusCodes: Set<Int>
	public var retryTransportErrors: Bool

	public init(
		maxAttempts: Int,
		backoff: Backoff,
		retryableStatusCodes: Set<Int>,
		retryTransportErrors: Bool
	) {
		self.maxAttempts = maxAttempts
		self.backoff = backoff
		self.retryableStatusCodes = retryableStatusCodes
		self.retryTransportErrors = retryTransportErrors
	}

	public static let none = RetryPolicy(maxAttempts: 1, backoff: .none, retryableStatusCodes: [], retryTransportErrors: false)

	public static func fixed(
		attempts: Int,
		delay: TimeInterval,
		statusCodes: Set<Int> = [408, 429, 500, 502, 503, 504],
		retryTransportErrors: Bool = true
	) -> RetryPolicy {
		RetryPolicy(
			maxAttempts: attempts,
			backoff: .fixed(delay: delay),
			retryableStatusCodes: statusCodes,
			retryTransportErrors: retryTransportErrors
		)
	}

	public static func exponential(
		attempts: Int,
		baseDelay: TimeInterval = 0.5,
		multiplier: Double = 2.0,
		maxDelay: TimeInterval = 30,
		statusCodes: Set<Int> = [408, 429, 500, 502, 503, 504],
		retryTransportErrors: Bool = true
	) -> RetryPolicy {
		RetryPolicy(
			maxAttempts: attempts,
			backoff: .exponential(baseDelay: baseDelay, multiplier: multiplier, maxDelay: maxDelay),
			retryableStatusCodes: statusCodes,
			retryTransportErrors: retryTransportErrors
		)
	}
}
