//
//  MockResponseManager.swift
//  MutantInjector
//
//  Created by samuel Ailemen on 3/3/25.
//

import Foundation

/**
 * MockResponseInfo
 *
 * Encapsulates information about a mock response.
 */
public struct MockResponseInfo: Sendable {
    let fileURL: URL?
    let filename: String?
    
    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.filename = nil
    }
    
    public init(filename: String) {
        self.filename = filename
        self.fileURL = nil
    }
}

/**
 * MockResponseRegistry
 *
 * Global access point to the MockResponseManager without using static variables.
 * Uses Objective-C runtime to store a singleton instance.
 */
@objc public class MockResponseRegistry: NSObject {
    // Create keys for associated object WITHOUT using static variables
    private let managerKey = UnsafeRawPointer(bitPattern: "com.mutantinjector.managerKey".hashValue)!
    
    // Private constructor prevents direct instantiation
    private override init() {
        super.init()
    }
    
    // Singleton accessor using a function with no static variables
    @objc public class func sharedManager() -> MockResponseManager {
        let registry = MockResponseRegistry()
        let nsObjectClass: AnyClass = NSObject.self
        
        // Check if we already have a manager
        if let existingManager = objc_getAssociatedObject(nsObjectClass, registry.managerKey) as? MockResponseManager {
            return existingManager
        }
        
        // Create a new manager
        let newManager = MockResponseManager()
        
        // Store it using associated object pattern
        objc_setAssociatedObject(
            nsObjectClass,
            registry.managerKey,
            newManager,
            .OBJC_ASSOCIATION_RETAIN
        )
        
        return newManager
    }
}

/**
 * MockResponseManager
 *
 * A thread-safe manager for mock responses using a dispatch queue to synchronize access.
 * This avoids static variables to prevent concurrency issues.
 */
@objc public class MockResponseManager: NSObject {
    /// Dictionary that maps URL strings to status codes and corresponding mock response information
    private var mockResponses: [String: [Int: MockResponseInfo]] = [:]
    
    /// Queue to synchronize access to mockResponses
    private let queue: DispatchQueue
    
    /// Initialize with a new dispatch queue
    override init() {
        self.queue = DispatchQueue(label: "com.mutantinjector.responsemanager", attributes: .concurrent)
        super.init()
    }
    
    /**
     * Clears all mock responses from the registry.
     */
    public func clearAllMockResponses() {
        queue.async(flags: .barrier) { [weak self] in
            self?.mockResponses = [:]
        }
    }
    
    /**
     * Checks if there's a mock response for the given URL.
     */
    public func hasMockResponse(for url: String) -> Bool {
        queue.sync {
            return self.mockResponses.keys.contains(url)
        }
    }
    
    /**
     * Gets the mock response info for a specific URL and status code.
     */
    public func getMockResponse(for url: String) -> [Int: MockResponseInfo]? {
        queue.sync {
            return self.mockResponses[url]
        }
    }
    
    /**
     * Adds a mock response for a specific URL using a JSON filename.
     */
    public func addMockResponse(for url: String, statusCode: Int, jsonFilename: String) {
        let responseInfo = MockResponseInfo(filename: jsonFilename)
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if self.mockResponses[url] == nil {
                self.mockResponses[url] = [statusCode: responseInfo]
            } else {
                self.mockResponses[url]?[statusCode] = responseInfo
            }
        }
    }
    
    /**
     * Adds a mock response for a specific URL using a direct fileURL.
     */
    public func addMockResponse(for url: String, statusCode: Int, fileURL: URL) {
        let responseInfo = MockResponseInfo(fileURL: fileURL)
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if self.mockResponses[url] == nil {
                self.mockResponses[url] = [statusCode: responseInfo]
            } else {
                self.mockResponses[url]?[statusCode] = responseInfo
            }
        }
    }
}
