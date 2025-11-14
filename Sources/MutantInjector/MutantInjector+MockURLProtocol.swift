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
    
    // Store captured body data
    private var capturedBodyData: Data?
    
    // Key to store body data in request
    private static let bodyDataKey = "MockURLProtocolBodyData"

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
        return manager.hasMockResponse(for: url) || manager.shouldLogRequest(for: url)
    }
    
    /**
     * Returns a canonical version of the specified request, capturing body data.
     */
    override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
        // If we already stored the body, just return the request
        if URLProtocol.property(forKey: bodyDataKey, in: request) != nil {
            return request
        }
        
        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        
        var bodyData: Data?
        
        if let httpBody = request.httpBody {
            bodyData = httpBody
        } else if let bodyStream = request.httpBodyStream {
            if bodyStream.streamStatus == .notOpen {
                bodyStream.open()
            }
            
            if bodyStream.streamStatus == .open && bodyStream.hasBytesAvailable {
                let bufferSize = 4096
                var data = Data()
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
                defer { buffer.deallocate() }
                
                while bodyStream.hasBytesAvailable {
                    let bytesRead = bodyStream.read(buffer, maxLength: bufferSize)
                    if bytesRead > 0 {
                        data.append(buffer, count: bytesRead)
                    } else {
                        break
                    }
                }
                
                if !data.isEmpty {
                    bodyData = data
                    NSLog("✅ [MutantInjector] Read \(data.count) bytes from stream in canonicalRequest")
                    
                    // Store as httpBody and remove the stream
                    mutableRequest.httpBody = data
                    mutableRequest.httpBodyStream = nil
                }
                
                bodyStream.close()
            }
        }
        
        // Store the body data as a property
        if let bodyData = bodyData {
            URLProtocol.setProperty(bodyData, forKey: bodyDataKey, in: mutableRequest)
        }
        
        return mutableRequest as URLRequest
    }
    
    /**
     * Starts loading the request.
     */
    override public func startLoading() {
        guard !isCancelled else { return }
        
        // Get body data
        capturedBodyData = getBodyData(from: request)
        
        let manager = MockResponseRegistry.sharedManager()
        
        manager.logRequest(request)
        
        guard let url = request.url?.absoluteString else {
            if !isCancelled {
                client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            }
            return
        }
        
        let method = requestMethod(from: request)
        
        // Check if we have a mock response
        guard let statusToResponseInfo =
                manager.getMockResponse(for: url, method: method)
                ?? manager.getMockResponse(for: url, method: .all)
        else {
            performActualRequest()
            return
        }
        
        // Find matching response based on body condition and status code
        guard let (statusCode, responseInfo) = findMatchingResponse(
            from: statusToResponseInfo,
            bodyData: capturedBodyData
        ) else {
            // No matching response found, perform actual request
            performActualRequest()
            return
        }
        
        // Apply response delay if specified
        let delay = responseInfo.additionalParams?.responseDelay ?? 0
        
        if delay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(Int(delay * 1000))) { [weak self] in
                guard let self = self, !self.isCancelled else { return }
                self.deliverMockResponse(responseInfo: responseInfo, statusCode: statusCode)
            }
        } else {
            deliverMockResponse(responseInfo: responseInfo, statusCode: statusCode)
        }
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
     * Delivers the mock response to the client.
     */
    private func deliverMockResponse(responseInfo: MockResponseInfo, statusCode: Int) {
        guard !isCancelled else { return }
        
        if let responseData = loadMockData(responseInfo: responseInfo) {
            guard !isCancelled else { return }
            
            guard let url = request.url,
                  let response = HTTPURLResponse(
                    url: url,
                    statusCode: statusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/json"]
                  ) else {
                client?.urlProtocol(self, didFailWithError: URLError(.badURL))
                return
            }
            
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: responseData)
            client?.urlProtocolDidFinishLoading(self)
        } else {
            guard !isCancelled else { return }
            
            let errorMessage = "Failed to load mock data for URL: \(request.url?.absoluteString ?? "unknown")"
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
    
    /**
     Mapping for URLRequest httpMethods to our custom RequestMethod
     */
    private func requestMethod(from request: URLRequest) -> RequestMethod {
        switch (request.httpMethod ?? "GET").uppercased() {
        case "GET":    return .get
        case "POST":   return .post
        case "PUT":    return .put
        case "PATCH":  return .patch
        case "DELETE": return .delete
        default:       return .all
        }
    }
    
    /**
     * Finds a matching response based on status code and body matching conditions.
     */
    private func findMatchingResponse(
        from statusToResponseInfo: [Int: [MockResponseInfo]],  // ← Now array of MockResponseInfo
        bodyData: Data?
    ) -> (Int, MockResponseInfo)? {
        NSLog("🔍 [MutantInjector] Finding match for URL: \(request.url?.absoluteString ?? "unknown")")
        // Flatten all response infos to check if ANY have body matching conditions
        let allResponseInfos = statusToResponseInfo.values.flatMap { $0 }
        let hasBodyMatchConditions = allResponseInfos.contains { responseInfo in
            responseInfo.additionalParams?.bodyMatches != nil
        }

        // First, try to find responses with body matching conditions
        for (statusCode, responseInfos) in statusToResponseInfo {
            for (index, responseInfo) in responseInfos.enumerated() {
                if let bodyMatches = responseInfo.additionalParams?.bodyMatches {
                    let matches = bodyMatches(bodyData)
                    if matches {
                        let debugLabel = responseInfo.identifier ?? "unnamed"
                        NSLog("✅ [MutantInjector] Found matching response at index \(index) (\(debugLabel))!")
                        return (statusCode, responseInfo)
                    }
                }
            }
        }
        
        // If we had body match conditions but none matched, return nil (no mock)
        if hasBodyMatchConditions {
            NSLog("⚠️ [MutantInjector] Body match conditions exist but none matched - performing actual request")
            return nil
        }
        
        NSLog("🔍 [MutantInjector] No body match conditions configured, using default mock")
        
        // If no body-matching responses were configured, fall back to default behavior
        // Prefer status 200, then first available
        if let responseInfos = statusToResponseInfo[200], let first = responseInfos.first {
            return (200, first)
        } else if let (statusCode, responseInfos) = statusToResponseInfo.first,
                  let first = responseInfos.first {
            return (statusCode, first)
        }
        NSLog("⚠️ [MutantInjector] No responses available")
        return nil
    }
    
    /**
     * Retrieves the stored body data from the request.
     */
    private func getBodyData(from request: URLRequest) -> Data? {
        // First check if we stored it as a property
        if let storedData = URLProtocol.property(forKey: Self.bodyDataKey, in: request) as? Data {
            return storedData
        }
        // Fall back to httpBody
        if let httpBody = request.httpBody {
            return httpBody
        }
        return nil
    }
}
