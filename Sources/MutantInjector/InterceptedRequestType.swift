//
//  InterceptedReqyestType.swift
//  MutantInjector
//
//  Created by samuel Ailemen on 10/29/25.
//


public enum InterceptedRequestType: Sendable {
    case urlRequest(url: String)
    case graphQL(url: String, operationName: String)
}
