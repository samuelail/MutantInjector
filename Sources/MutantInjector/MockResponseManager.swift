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
 */
@objc public class MockResponseRegistry: NSObject {
    // Singleton accessor
    @objc public class func sharedManager() -> MockResponseManager {
        return MockResponseManager.shared
    }
}

/**
 * MockResponseManager
 *
 * A thread-safe manager for mock responses using a dispatch queue to synchronize access.
 */
@objc public class MockResponseManager: NSObject, @unchecked Sendable  {
    /// Dictionary that maps URL strings to status codes and corresponding mock response information
    private var mockResponses: [String: [Int: MockResponseInfo]] = [:]
    
    /// URLs to log (empty array means log all requests)
    private var urlsToLog: Set<String> = []
    
    /// The current request logging mode (defaults to .none)
    private var requestLogMode: RequestLogMode = .none
    
    /// Callback for handling request logs
    private var requestLogCallback: ((RequestLogInfo) -> Void)?
    
    /// Dedicated queue for thread-safe logging operations
    private let logQueue = DispatchQueue(label: "com.mutantinjector.logging")
    
    /// Queue to synchronize access to mockResponses
    private let queue: DispatchQueue
    
    @objc public static let shared = MockResponseManager()
    
    /// Initialize with a new dispatch queue
    override init() {
        self.queue = DispatchQueue(label: "com.mutantinjector.responsemanager", attributes: .concurrent)
        super.init()
    }
    
    /**
     * setRequestLogMode(_:callback:)
     *
     * Configures the level of detail for request logging and sets the callback.
     *
     * - Parameter mode: The desired logging level (.none, .compact, or .verbose)
     * - Parameter urls: URLs to log. If empty, logs all intercepted requests
     * - Parameter callback: The callback to handle log information (optional)
     */
    public func setRequestLogMode(_ mode: RequestLogMode, for urls: [String] = [], callback: (@Sendable (RequestLogInfo) -> Void)? = nil) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.requestLogMode = mode
            self.urlsToLog = Set(urls)
            self.requestLogCallback = callback
        }
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
     * Checks if a URL should be logged based on the current logging configuration.
     */
    public func shouldLogRequest(for url: String) -> Bool {
        queue.sync {
            // If logging is disabled, don't log
            guard self.requestLogMode != .none else { return false }
            
            // If no specific URLs are configured, log all requests
            if self.urlsToLog.isEmpty {
                return true
            }
            // Check if this URL should be logged
            return self.urlsToLog.contains(url)
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
    
    public func addMockResponse(forGraphQL operationName: String, url: String, statusCode: Int, jsonFilename: String) {
        let key = graphQLKey(url: url, operationName: operationName)
        let responseInfo = MockResponseInfo(filename: jsonFilename)
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            if self.mockResponses[key] == nil {
                self.mockResponses[key] = [statusCode: responseInfo]
            } else {
                self.mockResponses[key]?[statusCode] = responseInfo
            }
        }
    }
    
    public func hasGraphQLMockResponse(for url: String, operationName: String) -> Bool {
        let key = graphQLKey(url: url, operationName: operationName)
        return queue.sync {
            return self.mockResponses.keys.contains(key)
        }
    }
    
    public func getGraphQLMockResponse(for url: String, operationName: String) -> [Int: MockResponseInfo]? {
        let key = graphQLKey(url: url, operationName: operationName)
        return queue.sync {
            return self.mockResponses[key]
        }
    }
    
    /**
     * logRequest(_:)
     *
     * Public method that handles request logging based on the current log mode.
     *
     * - Parameter request: The URLRequest to be logged
     */
    public func logRequest(_ request: URLRequest) {
        guard let url = request.url?.absoluteString else { return }
        
        // Check if this request should be logged
        guard shouldLogRequest(for: url) else { return }
        
        logQueue.async { [weak self] in
            guard let self = self else { return }
            
            switch self.requestLogMode {
            case .none:
                return
            case .compact:
                self.logCompact(request)
            case .verbose:
                self.logVerbose(request)
            }
        }
    }
    
    /**
     * logCompact(_:)
     *
     * Creates request log info in compact format (method, URL, and body only).
     *
     * - Parameter request: The URLRequest to be logged
     */
    private func logCompact(_ request: URLRequest) {
        let callback = queue.sync { [weak self] in
            return self?.requestLogCallback
        }
        
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "unknown URL"
        let body = request.httpBody
        
        let logInfo = RequestLogInfo(
            method: method,
            url: url,
            headers: nil,
            body: body
        )
        
        callback?(logInfo)
    }
    
    /**
     * logVerbose(_:)
     *
     * Creates request log info in verbose format (method, URL, headers, and body).
     *
     * - Parameter request: The URLRequest to be logged
     */
    private func logVerbose(_ request: URLRequest) {
        let callback = queue.sync { [weak self] in
            return self?.requestLogCallback
        }
        
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "unknown URL"
        let headers = request.allHTTPHeaderFields
        let body = request.httpBody
        
        let logInfo = RequestLogInfo(
            method: method,
            url: url,
            headers: headers,
            body: body
        )
        
        callback?(logInfo)
    }
    
    private func graphQLKey(url: String, operationName: String) -> String {
        return "graphql://\(url)#\(operationName)"
    }

}
