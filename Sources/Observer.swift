//
//  Observer.swift
//  Edge
//
//  Created by Tyler Fleming Cloutier on 5/29/16.
//
//

import Foundation

/// An Observer is a simple wrapper around a function which can receive Events
/// (typically from a Signal).
public struct Observer<Value, ErrorType: Error> {
    
    public typealias Action = (Event<Value, ErrorType>) -> Void
    
    public let action: Action
    
    public init(_ action: @escaping Action) {
        self.action = action
    }
    
    /// Creates an Observer with an action which calls each of the provided 
    /// callbacks
    public init(
        failed: ((ErrorType) -> Void)? = nil,
        completed: (() -> Void)? = nil,
        interrupted: (() -> Void)? = nil,
        next: ((Value) -> Void)? = nil)
    {
        self.init { event in
            switch event {
            case let .Next(value):
                next?(value)
                
            case let .Failed(error):
                failed?(error)
                
            case .Completed:
                completed?()
                
            case .Interrupted:
                interrupted?()
            }
        }
    }
    
    
    public func sendEvent(_ event: Event<Value, ErrorType>) {
        action(event)
    }
    
    /// Puts a `Next` event into the given observer.
    public func sendNext(_ value: Value) {
        action(.Next(value))
    }
    
    /// Puts an `Failed` event into the given observer.
    public func sendFailed(_ error: ErrorType) {
        action(.Failed(error))
    }
    
    /// Puts a `Completed` event into the given observer.
    public func sendCompleted() {
        action(.Completed)
    }
    
    /// Puts a `Interrupted` event into the given observer.
    public func sendInterrupted() {
        action(.Interrupted)
    }
}
