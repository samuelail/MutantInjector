//
// MutantInjector+MockURLProtocol.swift
// MutantInjector
//
// Created by Samuel Ailemen on 3/3/25.
//

import Foundation

/**
 * MockURLProtocol
 *
 * A custom URLProtocol implementation that intercepts network requests and serves mock JSON responses.
 * This class uses the MockResponseRegistry to avoid static variables.
 */
public class MockURLProtocol: URLProtocol {
    /**
     * Determines whether this protocol can handle the given request.
     */
    override public class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url?.absoluteString else { return false }
        return MockResponseRegistry.sharedManager().hasMockResponse(for: url)
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
        guard let url = request.url?.absoluteString else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        
        // Get the mock response from the manager
        guard let statusToResponseInfo = MockResponseRegistry.sharedManager().getMockResponse(for: url) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        
        // Determine which status code to use
        let statusCode: Int
        if statusToResponseInfo.keys.contains(200) {
            statusCode = 200
        } else {
            statusCode = statusToResponseInfo.keys.first ?? 404
        }
        
        guard let responseInfo = statusToResponseInfo[statusCode] else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        
        if let responseData = loadMockData(responseInfo: responseInfo) {
            let response = HTTPURLResponse(url: request.url!,
                                        statusCode: statusCode,
                                        httpVersion: "HTTP/1.1",
                                        headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: responseData)
            client?.urlProtocolDidFinishLoading(self)
        } else {
            let errorMessage = "Failed to load mock data for URL: \(url)"
            let userInfo = [NSLocalizedDescriptionKey: errorMessage]
            let error = NSError(domain: "MockURLProtocol", code: 1001, userInfo: userInfo)
            client?.urlProtocol(self, didFailWithError: error)
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    
    /**
     * Stops loading the request.
     */
    override public func stopLoading() {}
    
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
