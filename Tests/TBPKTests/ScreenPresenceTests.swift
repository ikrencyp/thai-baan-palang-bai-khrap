import XCTest
@testable import TBPK

final class ScreenPresenceTests: XCTestCase {
    func testPulsesOnlyWhenIdleUnlockedAndLit() {
        XCTAssertTrue(ScreenPresence.shouldPulse(idle: 60, locked: false, displayAsleep: false))
        XCTAssertFalse(ScreenPresence.shouldPulse(idle: 3, locked: false, displayAsleep: false))
        XCTAssertFalse(ScreenPresence.shouldPulse(idle: 60, locked: true, displayAsleep: false))
        XCTAssertFalse(ScreenPresence.shouldPulse(idle: 60, locked: false, displayAsleep: true))
    }
}
