# MutantInjector

MutantInjector is a powerful, lightweight Swift library for network request interception and mocking in iOS and macOS applications. It provides an elegant solution for testing and development by allowing you to mock network responses without hitting real endpoints.

![Banner Image](https://github.com/samuelail/MutantInjector/blob/main/Images/mutant%20injector.png?raw=true)

## Features

- **Zero-configuration setup** - One line to initialize the interceptor for all network requests
- **Transparent swizzling** - Intercepts all network requests without modifying application code
- **Status code simulation** - Return different responses based on HTTP status codes
- **Bundle integration** - Easily include mock responses in your project bundle
- **Modular design** - Use only what you need, minimal footprint
- **Test-friendly** - Designed to simplify and accelerate your unit and UI testing
- **Development support** - Mock API responses during development to work without real endpoints
- **Debug support** - Improved error reporting for fast debugging

## Installation

### Swift Package Manager

Add the following dependency to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/samuelail/MutantInjector.git", from: "1.0.4")
]
```

## Quick Start

```swift
import MutantInjector

// In your test setup or development environment
func setUp() {
    super.setUp()
    MutantInjector.setupGlobalInterceptor()
    
    // Register a mock response
    MutantInjector.addMockResponse(
        for: "https://api.example.com/users",
        statusCode: 200,
        method: .get, // optional, defaults to .all
        jsonFilename: "users_success"
    )
}

func tearDown() {
    MutantInjector.tearDownGlobalInterceptor()
    super.tearDown()
}
```

## Usage Examples
### Basic Mocking

```swift
// Register a mock response using a filename
MutantInjector.addMockResponse(
    for: "https://api.example.com/users",
    statusCode: 200,
    method: .get, // optional, defaults to .all
    jsonFilename: "users_success"
)

// The JSON file "users_success.json" should be in your test bundle
// { "users": [{"id": 1, "name": "John Doe"}] }
```

### Mocking with Different Status Codes

```swift
// Mock a success response
MutantInjector.addMockResponse(
    for: "https://api.example.com/users",
    statusCode: 200,
    method: .get, // optional, defaults to .all
    jsonFilename: "users_success"
)

// Mock an error response
MutantInjector.addMockResponse(
    for: "https://api.example.com/users",
    statusCode: 404,
    method: .get, // optional, defaults to .all
    jsonFilename: "not_found_error"
)

// Both responses are registered for the same URL but different status codes
```

### Using a File URL

```swift
// Create a URL to your mock JSON file
let fileURL = Bundle(for: type(of: self)).url(forResource: "users_success", withExtension: "json")!

// Register a mock response using a file URL
MutantInjector.addMockResponse(
    for: "https://api.example.com/users",
    statusCode: 200,
    method: .get, // optional, defaults to .all
    fileURL: fileURL
)
```

### Delaying a response
You can simulate a longer response time for requests by delaying the time it takes MutantInjector to respond to a request.

```swift
MutantInjector.addMockResponse(
    for: "https://api.example.com/users",
    statusCode: 404,
    method: .get, // optional, defaults to .all
    jsonFilename: "response",
    additionalParams: AdditionalRequestParameters(
    responseDelay: 2.0 // Delay response for 2 seconds
    )
)
```

### GraphQL / Matching Request Body
Although MutantInjector does not include any dedicated GraphQL methods, you can use the body-matching feature to intercept GraphQL requests or target a specific request when multiple requests are sent to the same URL endpoint.

```swift
MutantInjector.addMockResponse(
    for: "https://api.example.com/users",
    statusCode: 404,
    method: .get, // optional, defaults to .all
    jsonFilename: "response",
    additionalParams: AdditionalRequestParameters(
        bodyMatches: BodyMatchHelpers.jsonContainsObject { dict in
            if let op = dict["operationName"] as? String, op == "GetUser" { //Matches a dictionary's key value
                return true
            }
            return false
        }
    )
)
``` 

```swift
MutantInjector.addMockResponse(
    for: "https://api.example.com/users",
    statusCode: 404,
    method: .get, // optional, defaults to .all
    jsonFilename: "response",
    additionalParams: AdditionalRequestParameters(
    responseDelay: 2.0 // Delay response for 2 seconds
    )
)
)
```

### Logging a request

In addition to intercepting requests and mocking responses, MutantInjection also allows you to log the API requests that your app is making.

```swift
/**
 * The RequestLogMode options for logging are:
 * - `.none`: No request logging will be performed (default mode).
 * - `.compact`: Logs only the request method, URL, and body (if present).
 * - `.verbose`: Logs full request details including headers and body.
 */
 
// Log all requests in verbose mode
MutantInjector.setRequestLogMode(.verbose)

// Log only specific URLs in compact mode
MutantInjector.setRequestLogMode(.compact, for: [
    "https://api.example.com/users",
    "https://api.example.com/posts"
])

// Log requests with a custom callback to handle the log data
MutantInjector.setRequestLogMode(.verbose) { logInfo in
    print("🌐 \(logInfo.method) \(logInfo.url)")
    if let headers = logInfo.headers {
        print("📋 Headers: \(headers)")
    }
    if let body = logInfo.body {
        print("📦 Body: \(body)")
    }
}

// Log specific URLs with callback
MutantInjector.setRequestLogMode(.compact, 
                                for: ["https://api.example.com/login"]) { logInfo in
    print("Login request: \(logInfo.method) \(logInfo.url)")
}
```

### RequestLogInfo Structure:

```swift
public struct RequestLogInfo {
    public let method: String       // HTTP method (GET, POST, etc.)
    public let url: String         // Full URL
    public let headers: [String: String]?  // Headers (verbose mode only)
    public let body: Data?       // Request body data (if present)
}
```

## Complete Test Example

```swift
import XCTest
@testable import YourAppModule
import MutantInjector

class NetworkTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        MutantInjector.setupGlobalInterceptor()
    }
    
    override func tearDown() {
        MutantInjector.tearDownGlobalInterceptor()
        super.tearDown()
    }
    
    func testUserFetch() throws {
        // Setup expectations
        let expectation = XCTestExpectation(description: "Fetch users")
        
        // Register mock response
        MutantInjector.addMockResponse(
            for: "https://api.example.com/users",
            statusCode: 200,
            method: .get, // optional, defaults to .all
            jsonFilename: "users_success"
        )
        
        // Execute the code that makes the network request
        let userService = UserService()
        userService.fetchUsers { result in
            switch result {
            case .success(let users):
                XCTAssertEqual(users.count, 1)
                XCTAssertEqual(users.first?.name, "John Doe")
            case .failure(let error):
                XCTFail("Expected success but got error: \(error)")
            }
            expectation.fulfill()
        }
        
        // Wait for the expectation to be fulfilled
        wait(for: [expectation], timeout: 1.0)
    }
}
```

## Using in Development Environments
MutantInjector isn't limited to testing scenarios - it can be invaluable during development as well:

### Working Without Backend
When the backend is still under development or experiencing downtime, MutantInjector allows frontend developers to continue working:

```swift
// In your AppDelegate or application startup code
#if DEBUG
import MutantInjector

func setupMockResponses() {
    MutantInjector.setupGlobalInterceptor()
    
    // Register your development mocks
    MutantInjector.addMockResponse(
        for: "https://api.yourapp.com/v1/users",
        statusCode: 200,
        method: .get, // optional, defaults to .all
        jsonFilename: "dev_users"
    )
    
    MutantInjector.addMockResponse(
        for: "https://api.yourapp.com/v1/products",
        statusCode: 200,
        method: .get, // optional, defaults to .all
        jsonFilename: "dev_products"
    )
}
#endif

// Then call setupMockResponses() during app initialization
```

### Feature Development
When developing new features that depend on APIs not yet implemented:

```swift
// Feature flag system
if FeatureFlags.isNewFeatureEnabled {
    // Setup mocks for new endpoints
    MutantInjector.addMockResponse(
        for: "https://api.yourapp.com/v2/new-feature",
        statusCode: 200,
        method: .get, // optional, defaults to .all
        jsonFilename: "new_feature_response"
    )
}
```

### Demo Mode
Create a fully functional demo version of your app without requiring backend access:

```swift
// A helper class for demo mode
class DemoModeHelper {
    static func enableDemoMode() {
        MutantInjector.setupGlobalInterceptor()
        registerAllMockResponses()
    }
    
    private static func registerAllMockResponses() {
        // Register all the mock responses needed for demo mode
        MutantInjector.addMockResponse(
            for: "https://api.yourapp.com/v1/login",
            statusCode: 200,
            method: .get, // optional, defaults to .all
            jsonFilename: "demo_login"
        )
        
        MutantInjector.addMockResponse(
            for: "https://api.yourapp.com/v1/dashboard",
            statusCode: 200,
            method: .get, // optional, defaults to .all
            jsonFilename: "demo_dashboard"
        )
    }
}

// Usage in app startup
if isDemoMode {
    DemoModeHelper.enableDemoMode()
}
```

### UI Development and Previews
MutantInjector can be used with SwiftUI previews to display UI components with realistic data:

```swift
#if DEBUG
import SwiftUI
import MutantInjector

struct UserProfileView_Previews: PreviewProvider {
    static var previews: some View {
        // Setup mock response for the preview
        setupMockForPreview()
        
        // Return the view that will use the mocked network response
        return UserProfileView(userId: "preview-user-id")
    }
    
    static func setupMockForPreview() {
        MutantInjector.setupGlobalInterceptor()
        MutantInjector.addMockResponse(
            for: "https://api.yourapp.com/v1/users/preview-user-id",
            statusCode: 200,
            method: .get, // optional, defaults to .all
            jsonFilename: "preview_user_profile"
        )
    }
}
#endif
```

### Development Configuration
Create a centralized configuration for development environments:

```swift
// AppConfiguration.swift
#if DEBUG
import MutantInjector

struct AppConfiguration {
    static func configureForDevelopment() {
        // Setup API mocking only in development builds
        MutantInjector.setupGlobalInterceptor()
        
        // Register mock responses from a centralized catalog
        MockResponseCatalog.registerAll()
    }
}

// A catalog of all available mock responses
struct MockResponseCatalog {
    static func registerAll() {
        registerAuthResponses()
        registerUserResponses()
        registerContentResponses()
    }
    
    static func registerAuthResponses() {
        MutantInjector.addMockResponse(
            for: "https://api.yourapp.com/v1/login",
            statusCode: 200,
            method: .get, // optional, defaults to .all
            jsonFilename: "dev_login_success"
        )
        
        MutantInjector.addMockResponse(
            for: "https://api.yourapp.com/v1/login",
            statusCode: 401,
            method: .get, // optional, defaults to .all
            jsonFilename: "dev_login_failed"
        )
    }
    
    // Additional registration methods for other API categories
    // ...
}
#endif
```

## How It Works

MutantInjector uses method swizzling to inject a custom URLProtocol implementation into all URLSessionConfiguration instances. This allows it to intercept network requests and provide mock responses without requiring any changes to your application code.

1. When `setupGlobalInterceptor()` is called, MutantInjector:
   - Registers `MockURLProtocol` with the URL loading system
   - Uses the Objective-C runtime to track swizzling state without static variables
   - Swizzles the `default` and `ephemeral` class methods of `URLSessionConfiguration`
2. When a network request is made:
   - `MockURLProtocol` checks if there's a registered mock response for the URL using a thread-safe registry
   - If found, it returns the mock data from the specified JSON file
   - If not, it passes the request through to the next protocol in the chain
3. For thread safety and to avoid static variables:
   - The implementation uses a dispatch queue-based concurrency model
   - All shared state is managed via the Objective-C runtime's associated objects API
   - The system is designed to be thread-safe without using static variables

## API Reference
## MutantInjector
```swift
// Set up the global interceptor
public static func setupGlobalInterceptor()

// Tear down the global interceptor
public static func tearDownGlobalInterceptor()

// Add a mock response using a JSON filename
public static func addMockResponse(
    for url: String, 
    statusCode: Int, 
    method: RequestMethod,
    jsonFilename: String,
    additionalParams: AdditionalRequestParameters?,
    identifier: String?
)

// Add a mock response using a direct URL to a JSON file
public static func addMockResponse(
    for url: String, 
    statusCode: Int, 
    method: RequestMethod,
    fileURL: URL,
    additionalParams: AdditionalRequestParameters?,
    identifier: String?
)

// Clear all registered mock responses
public static func clearAllMockResponses()
```
## Best Practices
- Call `setupGlobalInterceptor()` at the start of your test and `tearDownGlobalInterceptor()` at the end to avoid affecting other tests
- Place your mock JSON files in your test bundle for easier management
- Use descriptive names for your JSON files to make tests more readable
- For complex testing scenarios, create helper methods that register multiple mock responses at once
- Clear mock responses between tests using `clearAllMockResponses()` to avoid cross-test contamination
- When using in a Swift Package, take note that JSON resources need special handling - consider using an application target for tests that require resource files
- For high-concurrency environments, this implementation is designed to be thread-safe without static variables

## Requirements
- iOS 13.0+ / macOS 10.15+
- Swift 5.5+
- Xcode 13.0+

## Contributing
Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Implementation Notes

MutantInjector has been carefully designed to avoid using static variables, making it safer in concurrent environments:

- **Thread-Safe Registry Pattern**: Uses the Objective-C runtime's associated objects API to store state without static variables
- **Dispatch Queue Concurrency**: Ensures thread-safe access to shared resources through strategic use of concurrent queues with barriers
- **Singleton Access Without Statics**: Provides global access to singletons via class methods rather than static properties
- **Modular Architecture**: Separates concerns into distinct components (MockResponseManager, SwizzleRegistry, etc.)

Developers extending or modifying MutantInjector should maintain these design principles to ensure thread safety and avoid concurrency issues.

## License
This project is licensed under the MIT License

## Acknowledgments

- Inspired by the need for reliable network mocking in Swift applications
