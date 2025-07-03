//
//  MutantLogStruct.swift
//  MutantInjector
//
//  Created by samuel Ailemen on 6/26/25.
//

import Foundation

public struct RequestLogInfo: Sendable {
    public let method: String
    public let url: String
    public let headers: [String: String]?
    public let body: Data?
    
    public init(method: String, url: String, headers: [String: String]? = nil, body: Data? = nil) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

