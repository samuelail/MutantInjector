//
//  URLSessionConfiguration+Swizzle.swift
//  MutantInjector
//
//  Created by samuel Ailemen on 3/3/25.
//

import Foundation

/**
 * Extension to URLSessionConfiguration to support method swizzling.
 */
extension URLSessionConfiguration {
    /**
     * Keys for associated objects - using method instead of static variables
     */
    private func getOriginalDefaultKey() -> UnsafeRawPointer {
        return UnsafeRawPointer(bitPattern: "com.mutantinjector.originalDefaultKey".hashValue)!
    }
    
    private func getOriginalEphemeralKey() -> UnsafeRawPointer {
        return UnsafeRawPointer(bitPattern: "com.mutantinjector.originalEphemeralKey".hashValue)!
    }
    
    /**
     * Swizzled implementation of the default class method.
     */
    @objc dynamic class func swizzledDefault() -> URLSessionConfiguration {
        // Get configuration using original implementation
        let configuration = swizzledDefault()
        
        // Add our protocol to the beginning of the protocol classes array
        configuration.protocolClasses = [MockURLProtocol.self] + (configuration.protocolClasses ?? [])
        return configuration
    }
    
    /**
     * Swizzled implementation of the ephemeral class method.
     */
    @objc dynamic class func swizzledEphemeral() -> URLSessionConfiguration {
        // Get configuration using original implementation
        let configuration = swizzledEphemeral()
        
        // Add our protocol to the beginning of the protocol classes array
        configuration.protocolClasses = [MockURLProtocol.self] + (configuration.protocolClasses ?? [])
        return configuration
    }
}
