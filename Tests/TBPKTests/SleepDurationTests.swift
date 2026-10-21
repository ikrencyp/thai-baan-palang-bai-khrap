import XCTest
@testable import TBPK

final class SleepDurationTests: XCTestCase {
    func testTheTimedChoicesCarryALengthAndUntilDateDoesNot() {
        XCTAssertEqual(SleepDuration.thirtyMinutes.seconds, 1800)
        XCTAssertEqual(SleepDuration.twelveHours.seconds, 12 * 3600)
        XCTAssertNil(SleepDuration.indefinite.seconds)
        XCTAssertNil(SleepDuration.untilDate.seconds)
    }

    func testOnlyUntilITurnItOffNeverRevivesACountdown() {
        XCTAssertTrue(SleepDuration.thirtyMinutes.restoresAsCountdown)
        XCTAssertFalse(SleepDuration.indefinite.restoresAsCountdown)
        XCTAssertTrue(SleepDuration.untilDate.restoresAsCountdown)
    }

    func testAnUnknownStoredValueFallsBackToIndefinite() {
        let defaults = UserDefaults.standard
        let saved = defaults.string(forKey: SleepDuration.storageKey)
        defaults.set("notADuration", forKey: SleepDuration.storageKey)
        XCTAssertEqual(SleepDuration.stored, .indefinite)
        if let saved { defaults.set(saved, forKey: SleepDuration.storageKey) } else {
            defaults.removeObject(forKey: SleepDuration.storageKey)
        }
    }
}
