import XCTest
@testable import TBPK

final class ScreenPresenceTests: XCTestCase {
    func testPulsesOnlyWhenIdleUnlockedAndLit() {
        XCTAssertTrue(ScreenPresence.shouldPulse(idle: 60, locked: false, displayAsleep: false))
        XCTAssertFalse(ScreenPresence.shouldPulse(idle: 3, locked: false, displayAsleep: false))
        XCTAssertFalse(ScreenPresence.shouldPulse(idle: 60, locked: true, displayAsleep: false))
        XCTAssertFalse(ScreenPresence.shouldPulse(idle: 60, locked: false, displayAsleep: true))
    }

    func testPulseIsAKeyNoAppMapsByDefault() {
        XCTAssertEqual(ScreenPresence.keyCode, 80, "F19")
    }

    @MainActor
    func testNeedsRestartForAccessOnlyWhenCachedFalseAfterTrust() {
        let savedAccess = ScreenPresence.hasAccessCheck
        let savedRestart = ScreenPresence.needsRestartCheck
        defer {
            ScreenPresence.hasAccessCheck = savedAccess
            ScreenPresence.needsRestartCheck = savedRestart
        }

        ScreenPresence.hasAccessCheck = { false }
        ScreenPresence.needsRestartCheck = { false }
        XCTAssertFalse(ScreenPresence.needsRestartForAccess)

        ScreenPresence.needsRestartCheck = { true }
        XCTAssertTrue(ScreenPresence.needsRestartForAccess)

        ScreenPresence.hasAccessCheck = { true }
        XCTAssertFalse(ScreenPresence.needsRestartForAccess)
    }

    @MainActor
    func testScheduleRelaunchRejectsNonAppBundles() {
        XCTAssertFalse(ScreenPresence.scheduleRelaunch(bundleURL: URL(fileURLWithPath: "/usr/bin/xctest")))
    }
}
