@testable import StreamKit

import XCTest

class TestBasic: XCTestCase {

    func testSignalPipe() {

        let (signal, observer) = Signal<Int>.pipe()
        var nextIndex = 0
        let nextVals = [0, 3, 5, 2, -3]
        var didComplete = false

        signal.onNext { next in
            XCTAssert(next == nextVals[nextIndex], "Value \(next) is incorrect.")
            nextIndex += 1
        }

        signal.onCompleted {
            XCTAssert(nextIndex == nextVals.count, "Completed incorrectly.")
            didComplete = true
        }

        signal.onFailed { error in
            XCTFail(error.localizedDescription)
        }

        for val in nextVals {
            observer.sendNext(val)
        }
        observer.sendCompleted()

        XCTAssert(didComplete, "Signal never completed.")

    }

}
