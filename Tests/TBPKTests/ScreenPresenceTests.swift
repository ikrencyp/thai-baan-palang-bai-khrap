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

    func testThePointerStepsRightWhereItRestsInTheOpen() {
        let displays = [CGRect(x: 0, y: 0, width: 1000, height: 800)]
        XCTAssertEqual(ScreenPresence.nudgeTarget(from: CGPoint(x: 500, y: 400), in: displays), CGPoint(x: 504, y: 400))
    }

    func testThePointerStaysPutInTheMenuBarOnEdgesAndInCorners() {
        let displays = [CGRect(x: 0, y: 0, width: 1000, height: 800)]
        let spots: [(CGPoint, Bool)] = [
            (CGPoint(x: 500, y: 59), false), (CGPoint(x: 500, y: 60), true),
            (CGPoint(x: 500, y: 760), true), (CGPoint(x: 500, y: 761), false),
            (CGPoint(x: 40, y: 400), true), (CGPoint(x: 39, y: 400), false),
            (CGPoint(x: 960, y: 400), true), (CGPoint(x: 961, y: 400), false),
            (CGPoint(x: 0, y: 0), false), (CGPoint(x: 999, y: 799), false),
            (CGPoint(x: 5000, y: 400), false),
        ]
        for (point, moves) in spots {
            XCTAssertEqual(ScreenPresence.nudgeTarget(from: point, in: displays) != nil, moves, "\(point)")
        }
    }

    func testTheStepIsBigEnoughForMacOSToCountIt() {
        XCTAssertGreaterThanOrEqual(ScreenPresence.nudgeDistance, 3, "measured: 1px did not reset the idle time, 3px did")
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
