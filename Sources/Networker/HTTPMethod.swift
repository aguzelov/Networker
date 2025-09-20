//
//  HTTPMethod.swift
//  Torbichka
//
//  Created by Clax on 20.09.25.
//

import Foundation

public enum HTTPEncoding {
	case urlFormEncoded
	case jsonEncoded
}

public enum HTTPMethod: String {
	case get
	case post
	case put
	case patch
	case delete
	
	public var value: String {
		self.rawValue.uppercased()
	}
}
