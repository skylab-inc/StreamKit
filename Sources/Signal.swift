//
//  Signal.swift
//  Edge
//
//  Created by Tyler Fleming Cloutier on 5/29/16.
//
//

import Foundation

public final class Signal<Value, ErrorType: Error>: SignalType, InternalSignalType, SpecialSignalGenerator {
    
    internal var observers = Bag<Observer<Value, ErrorType>>()
    
    public var signal: Signal<Value, ErrorType> {
        return self
    }
    
    /// Initializes a Signal that will immediately invoke the given generator,
    /// then forward events sent to the given observer.
    ///
    /// The disposable returned from the closure will be automatically disposed
    /// if a terminating event is sent to the observer. The Signal itself will
    /// remain alive until the observer is released. This is because the observer
    /// captures a self reference.
    public init(_ generator:  @escaping (Observer<Value, ErrorType>) -> Disposable?) {
        
        let generatorDisposable = SerialDisposable()

        let inputObserver = Observer<Value, ErrorType> { event in
            self.observers.forEach { (observer) in
                observer.action(event)
            }
            
            if event.isTerminating {
                generatorDisposable.dispose()
            }
        }
        
        generatorDisposable.innerDisposable = generator(inputObserver)
    }
    
    /// Creates a Signal that will be controlled by sending events to the returned
    /// observer.
    ///
    /// The Signal will remain alive until a terminating event is sent to the
    /// observer.
    public static func pipe() -> (Signal, Observer<Value, ErrorType>) {
        var observer: Observer<Value, ErrorType>!
        let signal = self.init { innerObserver in
            observer = innerObserver
            return nil
        }
        return (signal, observer)
    }
}

extension Signal: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        let obs = Array(self.observers.map { String(describing: $0) })
        return "Signal[\(obs.joined(separator: ", "))]"
    }
    
}

public protocol SpecialSignalGenerator {
    
    /// The type of values being sent on the signal.
    associatedtype Value
    
    /// The type of error that can occur on the signal. If errors aren't possible
    /// then `NoError` can be used.
    associatedtype ErrorType: Error
    
    init(_ generator: @escaping (Observer<Value, ErrorType>) -> Disposable?)
    
}

public extension SpecialSignalGenerator {
    
    /// Creates a Signal that will immediately send one value
    /// then complete.
    public init(value: Value) {
        self.init { observer in
            observer.sendNext(value)
            observer.sendCompleted()
            return nil
        }
    }
    
    /// Creates a Signal that will immediately fail with the
    /// given error.
    public init(error: ErrorType) {
        self.init { observer in
            observer.sendFailed(error)
            return nil
        }
    }
    
    /// Creates a Signal that will immediately send the values
    /// from the given sequence, then complete.
    public init<S: Sequence>(values: S) where S.Iterator.Element == Value {
        self.init { observer in
            var disposed = false
            for value in values {
                observer.sendNext(value)
                
                if disposed {
                    break
                }
            }
            observer.sendCompleted()
            
            return ActionDisposable {
                disposed = true
            }
        }
    }
    
    /// Creates a Signal that will immediately send the values
    /// from the given sequence, then complete.
    public init(values: Value...) {
        self.init(values: values)
    }
    
    /// A Signal that will immediately complete without sending
    /// any values.
    public static var empty: Self {
        return self.init { observer in
            observer.sendCompleted()
            return nil
        }
    }
    
    /// A Signal that never sends any events to its observers.
    public static var never: Self {
        return self.init { _ in return nil }
    }
    
}

public protocol SignalType {
    
    /// The type of values being sent on the signal.
    associatedtype Value
    
    /// The type of error that can occur on the signal. If errors aren't possible
    /// then `NoError` can be used.
    associatedtype ErrorType: Error
    
    /// The exposed raw signal that underlies the ColdSignalType
    var signal: Signal<Value, ErrorType> { get }

}

/// An internal protocol for adding methods that require access to the observers
/// of the signal.
internal protocol InternalSignalType: SignalType {
    
    var observers: Bag<Observer<Value, ErrorType>> { get }
    
}

internal extension InternalSignalType {
    
    /// Interrupts all observers and terminates the stream.
    func interrupt() {
        for observer in self.observers {
            observer.sendInterrupted()
        }
    }
    
}

public extension SignalType {
    
    /// Adds an observer to the Signal which observes any future events from the Signal.
    /// If the Signal has already terminated, the observer will immediately receive an
    /// `Interrupted` event.
    ///
    /// Returns a Disposable which can be used to disconnect the observer. Disposing
    /// of the Disposable will have no effect on the Signal itself.
    @discardableResult
    public func add(observer: Observer<Value, ErrorType>) -> Disposable? {
        let token = signal.observers.insert(value: observer)
        return ActionDisposable {
            self.signal.observers.removeValueForToken(token: token)
        }
        
    }

    /// Convenience override for add(observer:) to allow trailing-closure style
    /// invocations.
    @discardableResult
    public func on(action: @escaping Observer<Value, ErrorType>.Action) -> Disposable? {
        return self.add(observer: Observer(action))
    }
    
    /// Observes the Signal by invoking the given callback when `next` events are
    /// received.
    ///
    /// Returns a Disposable which can be used to stop the invocation of the
    /// callbacks. Disposing of the Disposable will have no effect on the Signal
    /// itself.
    @discardableResult
    public func onNext(next: @escaping (Value) -> Void) -> Disposable? {
        return self.add(observer: Observer(next: next))
    }
    
    /// Observes the Signal by invoking the given callback when a `completed` event is
    /// received.
    ///
    /// Returns a Disposable which can be used to stop the invocation of the
    /// callback. Disposing of the Disposable will have no effect on the Signal
    /// itself.
    @discardableResult
    public func onCompleted(completed: @escaping () -> Void) -> Disposable? {
        return self.add(observer: Observer(completed: completed))
    }
    
    /// Observes the Signal by invoking the given callback when a `failed` event is
    /// received.
    ///
    /// Returns a Disposable which can be used to stop the invocation of the
    /// callback. Disposing of the Disposable will have no effect on the Signal
    /// itself.
    @discardableResult
    public func onFailed(error: @escaping (ErrorType) -> Void) -> Disposable? {
        return self.add(observer: Observer(failed: error))
    }
    
    /// Observes the Signal by invoking the given callback when an `interrupted` event is
    /// received. If the Signal has already terminated, the callback will be invoked
    /// immediately.
    ///
    /// Returns a Disposable which can be used to stop the invocation of the
    /// callback. Disposing of the Disposable will have no effect on the Signal
    /// itself.
    @discardableResult
    public func onInterrupted(interrupted: @escaping () -> Void) -> Disposable? {
        return self.add(observer: Observer(interrupted: interrupted))
    }
    
}

public extension SignalType {
    
    public var identity: Signal<Value, ErrorType> {
        return self.map { $0 }
    }
    
    /// Maps each value in the signal to a new value.
    public func map<U>(_ transform: @escaping (Value) -> U) -> Signal<U, ErrorType> {
        return Signal { observer in
            return self.on { event -> Void in
                observer.sendEvent(event.map(transform))
            }
        }
    }
    
    /// Maps errors in the signal to a new error.
    public func mapError<F>(_ transform: @escaping (ErrorType) -> F) -> Signal<Value, F> {
        return Signal { observer in
            return self.on { event -> Void in
                observer.sendEvent(event.mapError(transform))
            }
        }
    }
    
    /// Preserves only the values of the signal that pass the given predicate.
    public func filter(_ predicate: @escaping (Value) -> Bool) -> Signal<Value, ErrorType> {
        return Signal { observer in
            return self.on { (event: Event<Value, ErrorType>) -> Void in
                guard let value = event.value else {
                    observer.sendEvent(event)
                    return
                }
                
                if predicate(value) {
                    observer.sendNext(value)
                }
            }
        }
    }
    
    /// Splits the signal into two signals. The first signal in the tuple matches the
    /// predicate, the second signal does not match the predicate
    public func partition(_ predicate: @escaping (Value) -> Bool) -> (Signal<Value, ErrorType>, Signal<Value, ErrorType>) {
        let left = Signal<Value, ErrorType> { observer in
            return self.on { (event: Event<Value, ErrorType>) -> Void in
                guard let value = event.value else {
                    observer.sendEvent(event)
                    return
                }
                
                if predicate(value) {
                    observer.sendNext(value)
                }
            }
        }
        let right = Signal<Value, ErrorType> { observer in
            return self.on { (event: Event<Value, ErrorType>) -> Void in
                guard let value = event.value else {
                    observer.sendEvent(event)
                    return
                }
                
                if !predicate(value) {
                    observer.sendNext(value)
                }
            }
        }
        return (left, right)
    }
    
    /// Aggregate values into a single combined value. Mirrors the Swift Collection
    public func reduce<T>(initial: T, _ combine: @escaping (T, Value) -> T) -> Signal<T, ErrorType> {
        return Signal { observer in
            var accumulator = initial
            return self.on { event in
                observer.action(event.map { value in
                    accumulator = combine(accumulator, value)
                    return accumulator
                })
            }
        }
    }
    
    public func flatMap<U>(_ transform: @escaping (Value) -> U?) -> Signal<U, ErrorType> {
        return Signal { observer in
            return self.on { event -> Void in
                if let e = event.flatMap(transform) {
                    observer.sendEvent(e)
                }
            }
        }
    }
    
}
