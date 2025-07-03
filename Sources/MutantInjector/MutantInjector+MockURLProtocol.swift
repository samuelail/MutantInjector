//
// MutantInjector+MockURLProtocol.swift
// MutantInjector
//
// Created by Samuel Ailemen on 3/3/25.
//

import Foundation

public class MockURLProtocol: URLProtocol {
    private var dataTask: URLSessionDataTask?
    private var isCancelled = false
    
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
        return manager.hasMockResponse(for: url) || manager.shouldLogRequest(for: url)
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
        
        // Check if we have a mock response
        guard let statusToResponseInfo = manager.getMockResponse(for: url) else {
            performActualRequest()
            return
        }
        
        // We have a mock response, so return it
        let statusCode: Int
        if statusToResponseInfo.keys.contains(200) {
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
            
            let response = HTTPURLResponse(url: request.url!,
                                           statusCode: statusCode,
                                           httpVersion: "HTTP/1.1",
                                           headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: responseData)
            client?.urlProtocolDidFinishLoading(self)
        } else {
            guard !isCancelled else { return }
            
            let errorMessage = "Failed to load mock data for URL: \(url)"
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
        let mutableRequest = NSMutableURLRequest(url: request.url!,
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
            guard let self = self, !self.isCancelled else {
                return
            }
            
            if let error = error {
                self.client?.urlProtocol(self, didFailWithError: error)
            } else {
                if let response = response {
                    self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                }
                if let data = data {
                    self.client?.urlProtocol(self, didLoad: data)
                }
                self.client?.urlProtocolDidFinishLoading(self)
            }
            
            // Clean up
            self.dataTask = nil
        }
        dataTask?.resume()
    }
    
    /**
     * Stops loading the request.
     */
    override public func stopLoading() {
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
        let testBundle = Bundle(for: type(of: self))
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
}
