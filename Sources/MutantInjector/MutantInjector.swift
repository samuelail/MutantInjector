//
// MutantInjector.swift
// MutantInjector
//
// Created by Samuel Ailemen on 3/3/25.
//

import Foundation

/**
 * MutantInjector
 *
 * A utility class that enables network request interception and mocking for testing purposes.
 * Now uses registry classes to avoid static variables.
 */
public class MutantInjector {
    /**
     * Sets up the global network interceptor.
     */
    public class func setupGlobalInterceptor() {
        URLProtocol.registerClass(MockURLProtocol.self)
        
        SwizzleRegistry.swizzleQueue().sync {
            if !SwizzleRegistry.isSwizzled() {
                swizzleURLSessionConfiguration()
                SwizzleRegistry.setSwizzled(true)
            }
        }
    }
    
    /**
     * Tears down the global network interceptor.
     */
    public class func tearDownGlobalInterceptor() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        
        SwizzleRegistry.swizzleQueue().sync {
            if SwizzleRegistry.isSwizzled() {
                unswizzleURLSessionConfiguration()
                SwizzleRegistry.setSwizzled(false)
            }
        }
        
        MockResponseRegistry.sharedManager().clearAllMockResponses()
    }
    
    /**
     * Clears all registered mock responses.
     */
    public class func clearAllMockResponses() {
        MockResponseRegistry.sharedManager().clearAllMockResponses()
    }
    
    /**
     * Adds a mock response for a specific URL using a JSON file from a bundle.
     */
    public class func addMockResponse(for url: String, statusCode: Int, jsonFilename: String) {
        MockResponseRegistry.sharedManager().addMockResponse(
            for: url,
            statusCode: statusCode,
            jsonFilename: jsonFilename
        )
    }
    
    /**
     * Adds a mock response for a specific URL using a direct URL to a JSON file.
     */
    public class func addMockResponse(for url: String, statusCode: Int, fileURL: URL) {
        MockResponseRegistry.sharedManager().addMockResponse(
            for: url,
            statusCode: statusCode,
            fileURL: fileURL
        )
    }
    
    /**
     * Swizzles URLSessionConfiguration methods to inject MockURLProtocol.
     */
    private class func swizzleURLSessionConfiguration() {
        // Swizzle the default configuration
        let defaultSelector = #selector(getter: URLSessionConfiguration.default)
        let swizzledDefaultSelector = #selector(URLSessionConfiguration.swizzledDefault)
        
        guard let originalDefaultMethod = class_getClassMethod(URLSessionConfiguration.self, defaultSelector),
              let swizzledDefaultMethod = class_getClassMethod(URLSessionConfiguration.self, swizzledDefaultSelector) else {
            return
        }
        
        method_exchangeImplementations(originalDefaultMethod, swizzledDefaultMethod)
        
        // Swizzle the ephemeral configuration
        let ephemeralSelector = #selector(getter: URLSessionConfiguration.ephemeral)
        let swizzledEphemeralSelector = #selector(URLSessionConfiguration.swizzledEphemeral)
        
        guard let originalEphemeralMethod = class_getClassMethod(URLSessionConfiguration.self, ephemeralSelector),
              let swizzledEphemeralMethod = class_getClassMethod(URLSessionConfiguration.self, swizzledEphemeralSelector) else {
            return
        }
        
        method_exchangeImplementations(originalEphemeralMethod, swizzledEphemeralMethod)
    }
    
    /**
     * Unswizzles URLSessionConfiguration methods to restore original behavior.
     */
    private class func unswizzleURLSessionConfiguration() {
        // Unswizzle the default configuration
        let defaultSelector = #selector(getter: URLSessionConfiguration.default)
        let swizzledDefaultSelector = #selector(URLSessionConfiguration.swizzledDefault)
        
        guard let originalDefaultMethod = class_getClassMethod(URLSessionConfiguration.self, defaultSelector),
              let swizzledDefaultMethod = class_getClassMethod(URLSessionConfiguration.self, swizzledDefaultSelector) else {
            return
        }
        
        method_exchangeImplementations(originalDefaultMethod, swizzledDefaultMethod)
        
        // Unswizzle the ephemeral configuration
        let ephemeralSelector = #selector(getter: URLSessionConfiguration.ephemeral)
        let swizzledEphemeralSelector = #selector(URLSessionConfiguration.swizzledEphemeral)
        
        guard let originalEphemeralMethod = class_getClassMethod(URLSessionConfiguration.self, ephemeralSelector),
              let swizzledEphemeralMethod = class_getClassMethod(URLSessionConfiguration.self, swizzledEphemeralSelector) else {
            return
        }
        
        method_exchangeImplementations(originalEphemeralMethod, swizzledEphemeralMethod)
    }
}
