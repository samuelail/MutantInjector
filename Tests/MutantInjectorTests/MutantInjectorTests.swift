////
//// MutantInjectorTests.swift
//// MutantInjector
////
//// Created as an example for using MutantInjector in tests
//
//import XCTest
//@testable import MutantInjector
//
//class MutantInjectorTests: XCTestCase {
//    
//    override func setUp() {
//        super.setUp()
//        // Set up the global interceptor at the beginning of each test
//        MutantInjector.setupGlobalInterceptor()
//    }
//    
//    override func tearDown() {
//        // Clear any mock responses that were registered during the test
//        MutantInjector.clearAllMockResponses()
//        super.tearDown()
//    }
//    
//    func testSuccessfulResponse() throws {
//        // Define expectations
//        let expectation = XCTestExpectation(description: "Network request completed")
//        
//        // Register a mock response
//        let testURL = "https://api.example.com/users"
//        MutantInjector.addMockResponse(
//            for: testURL,
//            statusCode: 200,
//            jsonFilename: "users_success"
//        )
//        
//        // Create a URL session and make a request
//        let session = URLSession.shared
//        let url = URL(string: testURL)!
//        
//        let task = session.dataTask(with: url) { data, response, error in
//            // Verify the response
//            XCTAssertNil(error, "Error should be nil")
//            
//            guard let httpResponse = response as? HTTPURLResponse else {
//                XCTFail("Response should be an HTTPURLResponse")
//                return
//            }
//            
//            XCTAssertEqual(httpResponse.statusCode, 200, "Status code should be 200")
//            
//            guard let data = data else {
//                XCTFail("Data should not be nil")
//                return
//            }
//            
//            do {
//                // Parse the JSON response
//                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
//                let users = json?["users"] as? [[String: Any]]
//                
//                XCTAssertNotNil(users, "Should have users array")
//                XCTAssertEqual(users?.count, 1, "Should have 1 user")
//                
//                if let user = users?.first {
//                    XCTAssertEqual(user["id"] as? Int, 1, "User ID should be 1")
//                    XCTAssertEqual(user["name"] as? String, "John Doe", "User name should be John Doe")
//                }
//            } catch {
//                XCTFail("Failed to parse JSON: \(error)")
//            }
//            
//            expectation.fulfill()
//        }
//        
//        // Start the request
//        task.resume()
//        
//        // Wait for the expectation to be fulfilled
//        wait(for: [expectation], timeout: 1.0)
//    }
//    
//    func testErrorResponse() throws {
//        // Define expectations
//        let expectation = XCTestExpectation(description: "Network request failed with 404")
//        
//        // Register a mock error response
//        let testURL = "https://api.example.com/nonexistent"
//        MutantInjector.addMockResponse(
//            for: testURL,
//            statusCode: 404,
//            jsonFilename: "not_found_error"
//        )
//        
//        // Create a URL session and make a request
//        let session = URLSession.shared
//        let url = URL(string: testURL)!
//        
//        let task = session.dataTask(with: url) { data, response, error in
//            // Verify the response
//            XCTAssertNil(error, "Error should be nil even for 404 responses")
//            
//            guard let httpResponse = response as? HTTPURLResponse else {
//                XCTFail("Response should be an HTTPURLResponse")
//                return
//            }
//            
//            XCTAssertEqual(httpResponse.statusCode, 404, "Status code should be 404")
//            
//            expectation.fulfill()
//        }
//        
//        // Start the request
//        task.resume()
//        
//        // Wait for the expectation to be fulfilled
//        wait(for: [expectation], timeout: 1.0)
//    }
//}
