//
//  SignalProducer.swift
//  Edge
//
//  Created by Tyler Fleming Cloutier on 5/29/16.
//
//

import Foundation

public final class ColdSignal<Value, ErrorType: Error>: ColdSignalType, InternalSignalType, SpecialSignalGenerator {
    internal var observers = Bag<Observer<Value, ErrorType>>()
    
    private let startHandler: (Observer<Value, ErrorType>) -> Disposable?
    
    private var cancelDisposable: Disposable?
    
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
    
    public func start() {
        let observer = Observer<Value, ErrorType> { event in
            if case .Interrupted = event {
                
                self.interrupt()
                
            } else {
                self.observers.forEach { (observer) in
                    observer.action(event)
                }
                
                if event.isTerminating {
                    self.stop()
                }
            }
        }
        
        if !started {
            started = true
            let handlerDisposable = startHandler(observer)
            
            // The cancel disposable should send interrupted and then dispose of the 
            // disposable produced by the startHandler.
            cancelDisposable = ActionDisposable {
                observer.sendInterrupted()
                handlerDisposable?.dispose()
            }
        }
    }
    
    public func stop() {
        cancelDisposable?.dispose()
        started = false
    }
    
    /// Adds an observer to the ColdSignal which observes any future events from the
    /// ColdSignal. If the Signal has already terminated, the observer will immediately
    /// receive an `Interrupted` event.
    ///
    /// Returns a Disposable which can be used to disconnect the observer. Disposing
    /// of the Disposable will have no effect on the Signal itself.
    public func add(observer: Observer<Value, ErrorType>) -> Disposable? {
        let token = self.observers.insert(value: observer)
        return ActionDisposable {
            self.observers.removeValueForToken(token: token)
        }
    }
    
}

extension ColdSignal: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        let obs = Array(self.observers.map { String(describing: $0) })
        return "ColdSignal[\(obs.joined(separator: ", "))]"
    }
    
}

public protocol ColdSignalType: SignalType {
    
    /// Invokes the closure provided upon initialization, and passes in a newly
    /// created observer to which events can be sent.
    func start()
    
    /// Stops the ColdSignal by sending an interrupt to all of it's
    /// observers and then invoking the disposable returned by the closure
    /// that was provided upon initialization.
    func stop()
    
}

extension ColdSignalType {
    
    /// Creates a ColdSignal, adds exactly one observer, and then immediately
    /// invokes start on the ColdSignal.
    ///
    /// Returns a Disposable which can be used to dispose of the added observer.
    @discardableResult
    public func start(with observer: Observer<Value, ErrorType>) -> Disposable? {
        let disposable = add(observer: observer)
        start()
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
