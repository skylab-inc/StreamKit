//
//  Promise.swift
//  StreamKit
//
//  Created by Tyler Fleming Cloutier on 11/20/17.
//

import Foundation
import PromiseKit

extension SignalType {

    static func from(promise: Promise<Value>) -> Signal<Value> {
        return Signal { observer in
            promise.then { value -> () in
                observer.sendNext(value)
                observer.sendCompleted()
            }.catch { error in
                observer.sendFailed(error)
            }
            return nil
        }
    }

}
