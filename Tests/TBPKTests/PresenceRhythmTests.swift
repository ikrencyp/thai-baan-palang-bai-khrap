import XCTest
@testable import TBPK

final class PresenceRhythmTests: XCTestCase {
    func testDefaultsToContinuous() {
        let defaults = scratchDefaults("PresenceRhythm")
        XCTAssertEqual(PresenceRhythm.stored(in: defaults), .continuous)
    }

    func testStoresAndLoadsAllCases() {
        let defaults = scratchDefaults("PresenceRhythm")
        for choice in PresenceRhythm.allCases {
            choice.store(in: defaults)
            XCTAssertEqual(PresenceRhythm.stored(in: defaults), choice)
        }
    }

    func testContinuousAlwaysPulses() {
        let now = Date()
        let result = ScreenPresence.nextPhase(current: nil, rhythm: .continuous, now: now)
        XCTAssertNil(result.phase)
        XCTAssertTrue(result.shouldPulse)
    }

    func testInitialPhaseIsActive() {
        let now = Date()
        let result = ScreenPresence.nextPhase(current: nil, rhythm: .deepFocus, now: now, activeDuration: 3600)
        XCTAssertEqual(result.phase, .active(until: now.addingTimeInterval(3600)))
        XCTAssertTrue(result.shouldPulse)
    }

    func testActivePhaseTransitionsToRestingWhenExpired() {
        let now = Date()
        let current = ScreenPresence.Phase.active(until: now)
        let result = ScreenPresence.nextPhase(current: current, rhythm: .deepFocus, now: now, restingDuration: 600)
        XCTAssertEqual(result.phase, .resting(until: now.addingTimeInterval(600)))
        XCTAssertFalse(result.shouldPulse)
    }

    func testRestingPhaseTransitionsToActiveWhenExpired() {
        let now = Date()
        let current = ScreenPresence.Phase.resting(until: now)
        let result = ScreenPresence.nextPhase(current: current, rhythm: .deepFocus, now: now, activeDuration: 3600)
        XCTAssertEqual(result.phase, .active(until: now.addingTimeInterval(3600)))
        XCTAssertTrue(result.shouldPulse)
    }

    func testZeroRestTransitionsDirectlyToNextActive() {
        let now = Date()
        let current = ScreenPresence.Phase.active(until: now)
        let result = ScreenPresence.nextPhase(current: current, rhythm: .deepFocus, now: now, activeDuration: 3600, restingDuration: 0)
        XCTAssertEqual(result.phase, .active(until: now.addingTimeInterval(3600)))
        XCTAssertTrue(result.shouldPulse)
    }
}

