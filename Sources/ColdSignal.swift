//
//  SignalProducer.swift
//  Edge
//
//  Created by Tyler Fleming Cloutier on 5/29/16.
//
//

import Foundation

public final class ColdSignal<Value, Error: ErrorProtocol>: ColdSignalType, InternalSignalType {
    internal var observers = Bag<Observer<Value, Error>>()
    
    private let startHandler: (Observer<Value, Error>) -> Disposable?
    
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
    public init(_ generator: (Observer<Value, Error>) -> Disposable?) {
        self.startHandler = generator
    }
    
    /// Creates a Signal from the producer, then attaches the given observer to
    /// the Signal as an observer.
    ///
    /// Returns a Disposable which can be used to interrupt the work associated
    /// with the signal and immediately send an `Interrupted` event.
    
    public func start() {
        let observer = Observer<Value, Error> { event in
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
    public func add(observer: Observer<Value, Error>) -> Disposable? {
        let token = self.observers.insert(value: observer)
        return ActionDisposable {
            self.observers.removeValueForToken(token: token)
        }
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
    public func start(with observer: Observer<Value, Error>) -> Disposable? {
        let disposable = add(observer: observer)
        start()
        return disposable
    }

    /// Creates a ColdSignal, adds exactly one observer, and then immediately
    /// invokes start on the ColdSignal.
    ///
    /// Returns a Disposable which can be used to dispose of the added observer.
    public func start(_ observerAction: Observer<Value, Error>.Action) -> Disposable? {
        return start(with: Observer(observerAction))
    }
    
    /// Creates a ColdSignal, adds exactly one observer for next, and then immediately
    /// invokes start on the ColdSignal.
    ///
    /// Returns a Disposable which can be used to dispose of the added observer.
    public func startWithNext(next: (Value) -> Void) -> Disposable? {
        return start(with: Observer(next: next))
    }
    
    /// Creates a ColdSignal, adds exactly one observer for completed events, and then
    /// immediately invokes start on the ColdSignal.
    ///
    /// Returns a Disposable which can be used to dispose of the added observer.
    public func startWithCompleted(completed: () -> Void) -> Disposable? {
        return start(with: Observer(completed: completed))
    }
    
    /// Creates a ColdSignal, adds exactly one observer for errors, and then
    /// immediately invokes start on the ColdSignal.
    ///
    /// Returns a Disposable which can be used to dispose of the added observer.
    public func startWithFailed(failed: (Error) -> Void) -> Disposable? {
        return start(with: Observer(failed: failed))
    }
    
    /// Creates a ColdSignal, adds exactly one observer for interrupts, and then
    /// immediately invokes start on the ColdSignal.
    ///
    /// Returns a Disposable which can be used to dispose of the added observer.
    public func startWithInterrupted(interrupted: () -> Void) -> Disposable? {
        return start(with: Observer(interrupted: interrupted))
    }

}