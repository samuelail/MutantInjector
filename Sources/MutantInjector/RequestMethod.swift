//
//  RequestMethod.swift
//  MutantInjector
//
//  Created by samuel Ailemen on 11/5/25.
//

import Foundation

/// Represents the HTTP request methods that can be intercepted or matched.
public enum RequestMethod: Sendable {
    
    /// Matches *all* HTTP request methods (GET, POST, PUT, PATCH, DELETE, etc.).
    /// Use this when you want to intercept every outgoing request, regardless of method.
    case all
    
    /// Represents an HTTP `GET` request, typically used for fetching data.
    /// Example: retrieving a list of resources or a specific item.
    case get
    
    /// Represents an HTTP `POST` request, used for creating or submitting data.
    /// Example: sending form data or creating a new resource on the server.
    case post
    
    /// Represents an HTTP `PUT` request, used for replacing an existing resource.
    /// Example: updating an entire object’s representation on the server.
    case put
    
    /// Represents an HTTP `PATCH` request, used for partially updating an existing resource.
    /// Example: updating a single field of a resource instead of replacing the whole thing.
    case patch
    
    /// Represents an HTTP `DELETE` request, used for removing a resource.
    /// Example: deleting a record or file on the server.
    case delete
}

