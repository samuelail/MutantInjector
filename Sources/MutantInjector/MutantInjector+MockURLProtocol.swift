//
// MutantInjector+MockURLProtocol.swift
// MutantInjector
//
// Created by Samuel Ailemen on 3/3/25.
//

import Foundation

public class MockURLProtocol: URLProtocol, @unchecked Sendable {
    private var dataTask: URLSessionDataTask?
    private lazy var testBundle = Bundle(for: type(of: self))
    private let cancelledQueue = DispatchQueue(label: "mockurlprotocol.cancelled")
    private var _isCancelled = false

    private var isCancelled: Bool {
        get {
            return cancelledQueue.sync { _isCancelled }
        }
        set {
            cancelledQueue.sync { _isCancelled = newValue }
        }
    }
    
    // Key to mark requests that should bypass the protocol
    private static let bypassKey = "MockURLProtocolBypass"
    
    /**
     * Determines whether this protocol can handle the given request.
     */
    override public class func canInit(with request: URLRequest) -> Bool {
        if URLProtocol.property(forKey: bypassKey, in: request) != nil {
            return false
        }
        
        guard let url = request.url?.absoluteString else { return false }
        let manager = MockResponseRegistry.sharedManager()
        
        // Check for regular mock
        if manager.hasMockResponse(for: url) {
            return true
        }
        
        // Check for GraphQL mock
        if let operationName = extractGraphQLOperationName(from: request) {
            if manager.hasGraphQLMockResponse(for: url, operationName: operationName) {
                return true
            }
        }
        
        return manager.shouldLogRequest(for: url)
    }
    
    /**
     * Returns a canonical version of the specified request.
     */
    override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    /**
     * Starts loading the request.
     */
    override public func startLoading() {
        guard !isCancelled else { return }
        
        let manager = MockResponseRegistry.sharedManager()
        manager.logRequest(request)
        
        guard let url = request.url?.absoluteString else {
            if !isCancelled {
                client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            }
            return
        }
        
        // First check for GraphQL mock
        if let operationName = Self.extractGraphQLOperationName(from: request),
           let statusToResponseInfo = manager.getGraphQLMockResponse(for: url, operationName: operationName) {
            returnMockResponse(statusToResponseInfo: statusToResponseInfo)
            return
        }
        
        // Then check for regular URL mock
        if let statusToResponseInfo = manager.getMockResponse(for: url) {
            returnMockResponse(statusToResponseInfo: statusToResponseInfo)
            return
        }
        
        // No mock found, perform actual request
        performActualRequest()
    }

    // Extract the mock response logic into a helper method
    private func returnMockResponse(statusToResponseInfo: [Int: MockResponseInfo]) {
        let statusCode: Int
        if statusToResponseInfo[200] != nil {
            statusCode = 200
        } else {
            statusCode = statusToResponseInfo.keys.first ?? 404
        }
        
        guard let responseInfo = statusToResponseInfo[statusCode] else {
            if !isCancelled {
                client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            }
            return
        }
        
        if let responseData = loadMockData(responseInfo: responseInfo) {
            guard !isCancelled else { return }
            
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url,
                                               statusCode: statusCode,
                                               httpVersion: "HTTP/1.1",
                                               headerFields: ["Content-Type": "application/json"]) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badURL))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: responseData)
            client?.urlProtocolDidFinishLoading(self)
        } else {
            guard !isCancelled else { return }
            
            let errorMessage = "Failed to load mock data"
            let userInfo = [NSLocalizedDescriptionKey: errorMessage]
            let error = NSError(domain: "MockURLProtocol", code: 1001, userInfo: userInfo)
            client?.urlProtocol(self, didFailWithError: error)
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    
    /**
     * Performs the actual network request when we're only logging, not mocking.
     */
    private func performActualRequest() {
        guard !isCancelled else { return }
        
        // Create a mutable copy of the request and mark it to bypass our protocol
        guard let url = request.url else { return }
        let mutableRequest = NSMutableURLRequest(url: url,
                                                 cachePolicy: request.cachePolicy,
                                                 timeoutInterval: request.timeoutInterval)
        mutableRequest.httpMethod = request.httpMethod ?? "GET"
        mutableRequest.allHTTPHeaderFields = request.allHTTPHeaderFields
        mutableRequest.httpBody = request.httpBody
        
        // Mark this request to bypass MockURLProtocol
        URLProtocol.setProperty(true, forKey: Self.bypassKey, in: mutableRequest)
        
        // Create a new URLSession with default configuration that includes our protocol
        // but the specific request will bypass due to the property we set
        let session = URLSession.shared
        
        dataTask = session.dataTask(with: mutableRequest as URLRequest) { [weak self] data, response, error in
            guard let strongSelf = self else { return }
            guard !strongSelf.isCancelled else {
                return
            }
            
            if let error = error {
                strongSelf.client?.urlProtocol(strongSelf, didFailWithError: error)
            } else {
                if let response = response {
                    strongSelf.client?.urlProtocol(strongSelf, didReceive: response, cacheStoragePolicy: .notAllowed)
                }
                if let data = data {
                    strongSelf.client?.urlProtocol(strongSelf, didLoad: data)
                }
                strongSelf.client?.urlProtocolDidFinishLoading(strongSelf)
            }
            
            // Clean up
            strongSelf.dataTask = nil
        }
        dataTask?.resume()
    }
    
    /**
     * Stops loading the request.
     */
    override public func stopLoading() {
        isCancelled = true
        dataTask?.cancel()
        dataTask = nil
    }
    
    /**
     * Loads mock data based on the provided response info.
     */
    private func loadMockData(responseInfo: MockResponseInfo) -> Data? {
        // If a direct file URL is provided, use it
        if let fileURL = responseInfo.fileURL {
            do {
                return try Data(contentsOf: fileURL)
            } catch {
                NSLog("MutantInjector: Failed to load mock data from URL \(fileURL). Error: \(error)")
                return nil
            }
        }
        
        // Otherwise, try to find the file in bundles using the filename
        guard let filename = responseInfo.filename else { return nil }
        
        // Try to load from test bundle first
        if let url = testBundle.url(forResource: filename, withExtension: "json") {
            do {
                return try Data(contentsOf: url)
            } catch {
                NSLog("MutantInjector: Failed to load \(filename).json from test bundle. Error: \(error)")
                return nil
            }
        }
        
        // Fall back to main bundle if not found in test bundle
        if let url = Bundle.main.url(forResource: filename, withExtension: "json") {
            do {
                return try Data(contentsOf: url)
            } catch {
                NSLog("MutantInjector: Failed to load \(filename).json from main bundle. Error: \(error)")
                return nil
            }
        }
        
        NSLog("MutantInjector: Could not find \(filename).json in any bundle")
        return nil
    }
    
    private class func extractGraphQLOperationName(from request: URLRequest) -> String? {
        guard let body = request.httpBody,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let operationName = json["operationName"] as? String else {
            return nil
        }
        return operationName
    }
}
