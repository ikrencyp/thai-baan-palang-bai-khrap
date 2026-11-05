import XCTest
@testable import TBPK

final class ScreenPresenceTests: XCTestCase {
    func testPulsesOnlyWhenIdleUnlockedAndLit() {
        XCTAssertTrue(ScreenPresence.shouldPulse(idle: 60, locked: false, displayAsleep: false))
        XCTAssertFalse(ScreenPresence.shouldPulse(idle: 3, locked: false, displayAsleep: false))
        XCTAssertFalse(ScreenPresence.shouldPulse(idle: 60, locked: true, displayAsleep: false))
        XCTAssertFalse(ScreenPresence.shouldPulse(idle: 60, locked: false, displayAsleep: true))
    }

    func testNeverNudgesWhilePointerRestsInMenuBarOrOnAnEdge() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        XCTAssertTrue(ScreenPresence.isClearSpot(CGPoint(x: 700, y: 400), in: [screen]))
        XCTAssertFalse(ScreenPresence.isClearSpot(CGPoint(x: 1200, y: 10), in: [screen]), "menu bar")
        XCTAssertFalse(ScreenPresence.isClearSpot(CGPoint(x: 2, y: 2), in: [screen]), "hot corner")
        XCTAssertFalse(ScreenPresence.isClearSpot(CGPoint(x: 700, y: 895), in: [screen]), "Dock edge")
        XCTAssertFalse(ScreenPresence.isClearSpot(CGPoint(x: 1438, y: 400), in: [screen]), "side edge")
        XCTAssertFalse(ScreenPresence.isClearSpot(CGPoint(x: 5000, y: 400), in: [screen]), "unknown position")
    }
}
