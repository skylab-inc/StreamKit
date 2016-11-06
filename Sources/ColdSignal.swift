//
//  SignalProducer.swift
//  Edge
//
//  Created by Tyler Fleming Cloutier on 5/29/16.
//
//

import Foundation

public final class ColdSignal<T, E: Error>: ColdSignalType, InternalSignalType, SpecialSignalGenerator {
    
    public typealias Value = T
    public typealias ErrorType = E
    
    internal var observers = Bag<Observer<Value, ErrorType>>()
    
    public var coldSignal: ColdSignal {
        return self
    }
    
    internal let startHandler: (Observer<Value, ErrorType>) -> Disposable?
    
    private var cancelDisposable: Disposable?
    
    private var handlerDisposable: Disposable?
    
    private var started = false
    
    /// Initializes a ColdSignal that will invoke the given closure at the
    /// invocation of `start()`.
    ///
    /// The events that the closure puts into the given observer will become
    /// the events sent to this ColdSignal.
    ///
    /// In order to stop or dispose of the signal, invoke `stop()`. Calling this method
    /// will dispose of the disposable returned by the given closure.
    /// 
    /// Invoking `start()` will have no effect until the signal is stopped. After
    /// `stop()` is called this process may be repeated.
    public init(_ generator: @escaping (Observer<Value, ErrorType>) -> Disposable?) {
        self.startHandler = generator
    }
    
    /// Creates a Signal from the producer, then attaches the given observer to
    /// the Signal as an observer.
    ///
    /// Returns a Disposable which can be used to interrupt the work associated
    /// with the signal and immediately send an `Interrupted` event.
    
    @discardableResult
    public func start() {
        if !started {
            started = true
            
            let observer = Observer<Value, ErrorType> { event in
                // Pass event downstream
                self.observers.forEach { (observer) in
                    observer.action(event)
                }
                
                // If event is terminating dispose of the handlerDisposable.
                if event.isTerminating {
                    self.handlerDisposable?.dispose()
                }
            }
            
            handlerDisposable = startHandler(observer)
            
            // The cancel disposable should send interrupted and then dispose of the 
            // disposable produced by the startHandler.
            cancelDisposable = ActionDisposable { [weak self] in
                observer.sendInterrupted()
                self?.handlerDisposable?.dispose()
            }
        }
    }
    
    public func stop() {
        cancelDisposable?.dispose()
        started = false
    }
    
}

extension ColdSignal: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        let obs = Array(self.observers.map { String(describing: $0) })
        return "ColdSignal[\(obs.joined(separator: ", "))]"
    }
    
}

public protocol ColdSignalType: SignalType {
    
    /// The exposed raw signal that underlies the ColdSignalType
    var coldSignal: ColdSignal<Value, ErrorType> { get }
    
    /// Invokes the closure provided upon initialization, and passes in a newly
    /// created observer to which events can be sent.
    func start()
    
    /// Stops the ColdSignal by sending an interrupt to all of it's
    /// observers and then invoking the disposable returned by the closure
    /// that was provided upon initialization.
    func stop()
    
}

public extension ColdSignalType {
    
    public var signal: Signal<Value, ErrorType> {
        return Signal { observer in
            self.coldSignal.add(observer: observer)
        }
    }
    
    /// Invokes the closure provided upon initialization, and passes in a newly
    /// created observer to which events can be sent.
    func start() {
        coldSignal.start()
    }
    
    /// Stops the ColdSignal by sending an interrupt to all of it's
    /// observers and then invoking the disposable returned by the closure
    /// that was provided upon initialization.
    func stop() {
        coldSignal.stop()
    }

}

public extension ColdSignalType {
    
    /// Adds an observer to the ColdSignal which observes any future events from the
    /// ColdSignal. If the Signal has already terminated, the observer will immediately
    /// receive an `Interrupted` event.
    ///
    /// Returns a Disposable which can be used to disconnect the observer. Disposing
    /// of the Disposable will have no effect on the Signal itself.
    @discardableResult
    public func add(observer: Observer<Value, ErrorType>) -> Disposable? {
        let token = coldSignal.observers.insert(value: observer)
        return ActionDisposable {
            self.coldSignal.observers.removeValueForToken(token: token)
        }
    }
    
    /// Creates a ColdSignal, adds exactly one observer, and then immediately
    /// invokes start on the ColdSignal.
    ///
    /// Returns a Disposable which can be used to dispose of the added observer.
    @discardableResult
    public func start(with observer: Observer<Value, ErrorType>) -> Disposable? {
        let disposable = coldSignal.add(observer: observer)
        self.coldSignal.start()
        return disposable
    }

    /// Creates a ColdSignal, adds exactly one observer, and then immediately
    /// invokes start on the ColdSignal.
    ///
    /// Returns a Disposable which can be used to dispose of the added observer.
    @discardableResult
    public func start(_ observerAction: @escaping Observer<Value, ErrorType>.Action) -> Disposable? {
        return start(with: Observer(observerAction))
    }
    
    /// Creates a ColdSignal, adds exactly one observer for next, and then immediately
    /// invokes start on the ColdSignal.
    ///
    /// Returns a Disposable which can be used to dispose of the added observer.
    @discardableResult
    public func startWithNext(next: @escaping (Value) -> Void) -> Disposable? {
        return start(with: Observer(next: next))
    }
    
    /// Creates a ColdSignal, adds exactly one observer for completed events, and then
    /// immediately invokes start on the ColdSignal.
    ///
    /// Returns a Disposable which can be used to dispose of the added observer.
    @discardableResult
    public func startWithCompleted(completed: @escaping () -> Void) -> Disposable? {
        return start(with: Observer(completed: completed))
    }
    
    /// Creates a ColdSignal, adds exactly one observer for errors, and then
    /// immediately invokes start on the ColdSignal.
    ///
    /// Returns a Disposable which can be used to dispose of the added observer.
    @discardableResult
    public func startWithFailed(failed: @escaping (ErrorType) -> Void) -> Disposable? {
        return start(with: Observer(failed: failed))
    }
    
    /// Creates a ColdSignal, adds exactly one observer for interrupts, and then
    /// immediately invokes start on the ColdSignal.
    ///
    /// Returns a Disposable which can be used to dispose of the added observer.
    @discardableResult
    public func startWithInterrupted(interrupted: @escaping () -> Void) -> Disposable? {
        return start(with: Observer(interrupted: interrupted))
    }

}

public extension ColdSignalType {
    
    /// Creates a new `ColdSignal` which will apply a unary operator directly to events
    /// produced by the `startHandler`.
    ///
    /// The new `ColdSignal` is in no way related to the source `ColdSignal` except
    /// that they share a reference to the same `startHandler`.
    public func lift<U, F>(_ transform: @escaping (Signal<Value, ErrorType>) -> Signal<U, F>) -> ColdSignal<U, F> {
        return ColdSignal { observer in
            let (pipeSignal, pipeObserver) = Signal<Value, ErrorType>.pipe()
            transform(pipeSignal).add(observer: observer)
            return self.coldSignal.startHandler(pipeObserver)
        }
    }
    
    /// Maps each value in the signal to a new value.
    public func map<U>(_ transform: @escaping (Value) -> U) -> ColdSignal<U, ErrorType> {
        return lift { $0.map(transform) }
    }
    
    /// Maps errors in the signal to a new error.
    public func mapError<F>(_ transform: @escaping (ErrorType) -> F) -> ColdSignal<Value, F> {
        return lift { $0.mapError(transform) }
    }
    
    /// Preserves only the values of the signal that pass the given predicate.
    public func filter(_ predicate: @escaping (Value) -> Bool) -> ColdSignal<Value, ErrorType> {
        return lift { $0.filter(predicate) }
    }
    
    /// Aggregate values into a single combined value. Mirrors the Swift Collection
    public func reduce<T>(initial: T, _ combine: @escaping (T, Value) -> T) -> ColdSignal<T, ErrorType> {
        return lift { $0.reduce(initial: initial, combine) }
    }
    
    public func flatMap<U>(_ transform: @escaping (Value) -> U?) -> ColdSignal<U, ErrorType> {
        return lift { $0.flatMap(transform) }
    }
    
}

