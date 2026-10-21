import AppKit
import XCTest
@testable import TBPK

@MainActor
final class SystemChangeObserverTests: XCTestCase {
    private func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    }

    private func postLock() {
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("com.apple.screenIsLocked"), object: nil, userInfo: nil, deliverImmediately: true)
    }

    func testAScreenLockNotificationWakesTheWatchAtOnce() {
        var calls = 0
        let observer = SystemChangeObserver { calls += 1 }
        observer.start()
        postLock()
        settle()
        observer.stop()
        XCTAssertGreaterThanOrEqual(calls, 1)
    }

    func testStartingTwiceDoesNotDoubleTheWakeups() {
        var calls = 0
        let observer = SystemChangeObserver { calls += 1 }
        observer.start()
        observer.start()
        postLock()
        settle()
        observer.stop()
        XCTAssertEqual(calls, 1)
    }

    func testAStoppedObserverStaysSilent() {
        var calls = 0
        let observer = SystemChangeObserver { calls += 1 }
        observer.start()
        observer.stop()
        postLock()
        settle()
        XCTAssertEqual(calls, 0)
    }
}
