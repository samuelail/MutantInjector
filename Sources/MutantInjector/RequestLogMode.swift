//
//  RequestLogMode.swift
//  MutantInjector
//
//  Created by samuel Ailemen on 4/24/25.
//


/**
 * RequestLogMode
 *
 * Defines the different levels of request logging available for mock network requests.
 *
 * - `.none`: No request logging will be performed (default mode).
 * - `.compact`: Logs only the request method, URL, and body (if present).
 * - `.verbose`: Logs full request details including headers and body.
 */
public enum RequestLogMode: Sendable {
    /// No request logging will be performed
    case none
    
    /// Logs only the request method, URL, and body (if present)
    case compact
    
    /// Logs full request details including headers and body
    case verbose
}
