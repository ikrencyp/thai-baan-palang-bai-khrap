import AppKit
import XCTest
@testable import TBPK

@MainActor
final class SystemChangeObserverTests: XCTestCase {
    private func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    }

    private func postLock(to center: NotificationCenter, name: String = "com.apple.screenIsLocked") {
        center.post(name: Notification.Name(name), object: nil)
    }

    func testAScreenLockNotificationWakesTheWatchAtOnce() {
        var calls = 0
        let lockCenter = NotificationCenter()
        let observer = SystemChangeObserver(lockCenter: lockCenter, workspaceCenter: NotificationCenter()) {
            calls += 1
        }
        observer.start()
        postLock(to: lockCenter)
        settle()
        observer.stop()
        XCTAssertGreaterThanOrEqual(calls, 1)
    }

    func testStartingTwiceDoesNotDoubleTheWakeups() {
        var calls = 0
        let lockCenter = NotificationCenter()
        let observer = SystemChangeObserver(lockCenter: lockCenter, workspaceCenter: NotificationCenter()) {
            calls += 1
        }
        observer.start()
        observer.start()
        postLock(to: lockCenter)
        settle()
        observer.stop()
        XCTAssertEqual(calls, 1)
    }

    func testAStoppedObserverStaysSilent() {
        var calls = 0
        let lockCenter = NotificationCenter()
        let observer = SystemChangeObserver(lockCenter: lockCenter, workspaceCenter: NotificationCenter()) {
            calls += 1
        }
        observer.start()
        observer.stop()
        postLock(to: lockCenter)
        settle()
        XCTAssertEqual(calls, 0)
    }

    func testScreenUnlockAndDisplayNotificationsWakeTheWatch() {
        var calls = 0
        let lockCenter = NotificationCenter()
        let workspaceCenter = NotificationCenter()
        let observer = SystemChangeObserver(lockCenter: lockCenter, workspaceCenter: workspaceCenter) {
            calls += 1
        }
        observer.start()
        postLock(to: lockCenter, name: "com.apple.screenIsUnlocked")
        workspaceCenter.post(name: NSWorkspace.screensDidSleepNotification, object: nil)
        workspaceCenter.post(name: NSWorkspace.screensDidWakeNotification, object: nil)
        settle()
        observer.stop()
        XCTAssertEqual(calls, 3)
    }
}
