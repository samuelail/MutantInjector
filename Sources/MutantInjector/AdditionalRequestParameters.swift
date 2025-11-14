//
//  AdditionalRequestParameters.swift
//  MutantInjector
//
//  Created by samuel Ailemen on 11/13/25.
//

import Foundation
/**
 The AdditionalRequestParameters struct will be used to pass additional conditions into
 the request filtering / response mocking process
 */
public struct AdditionalRequestParameters: Sendable {
    /// Optional delay before returning the mocked response
    public let responseDelay: Float

    /// Optional predicate to decide whether this mock matches a given HTTP body.
    /// Return true if the body satisfies your condition.
    public let bodyMatches: (@Sendable (Data?) -> Bool)?

    public init(
        responseDelay: Float = 0,
        bodyMatches: (@Sendable (Data?) -> Bool)? = nil
    ) {
        self.responseDelay = responseDelay
        self.bodyMatches = bodyMatches
    }
}

