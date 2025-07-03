//
//  SwizzleRegistry.swift
//  MutantInjector
//
//  Created by samuel Ailemen on 3/3/25.
//

import Foundation

@objc public class SwizzleRegistry: NSObject {
    // Create keys
    private let isSwizzledKey = UnsafeRawPointer(bitPattern: "com.mutantinjector.isSwizzledKey".hashValue)!
    private let swizzleQueueKey = UnsafeRawPointer(bitPattern: "com.mutantinjector.swizzleQueueKey".hashValue)!
    
    // Private constructor prevents direct instantiation
    private override init() {
        super.init()
    }
    
    // Get or create swizzle state
    @objc public class func isSwizzled() -> Bool {
        let registry = SwizzleRegistry()
        let nsObjectClass: AnyClass = NSObject.self
        
        if let value = objc_getAssociatedObject(nsObjectClass, registry.isSwizzledKey) as? Bool {
            return value
        }
        
        // Default to false if not set
        return false
    }
    
    // Set swizzle state
    @objc public class func setSwizzled(_ value: Bool) {
        let registry = SwizzleRegistry()
        let nsObjectClass: AnyClass = NSObject.self
        
        objc_setAssociatedObject(
            nsObjectClass,
            registry.isSwizzledKey,
            value,
            .OBJC_ASSOCIATION_RETAIN
        )
    }
    
    // Get the swizzle queue
    @objc public class func swizzleQueue() -> DispatchQueue {
        let registry = SwizzleRegistry()
        let nsObjectClass: AnyClass = NSObject.self
        
        if let queue = objc_getAssociatedObject(nsObjectClass, registry.swizzleQueueKey) as? DispatchQueue {
            return queue
        }
        
        // Create a new queue if one doesn't exist
        let queue = DispatchQueue(label: "com.mutantinjector.swizzle")
        
        objc_setAssociatedObject(
            nsObjectClass,
            registry.swizzleQueueKey,
            queue,
            .OBJC_ASSOCIATION_RETAIN
        )
        
        return queue
    }
}
