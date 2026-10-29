import XCTest
@testable import TBPK

final class EndDateUnitTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testEveryUnitCountsFromNow() throws {
        for (unit, seconds) in [(EndDateUnit.minutes, 60.0), (.hours, 3_600), (.days, 86_400), (.weeks, 604_800)] {
            let moment = try XCTUnwrap(EndDateUnit.moment(afterMinutes: 3 * unit.minutes, from: now))
            XCTAssertEqual(moment.timeIntervalSince(now), 3 * seconds, accuracy: 60, "\(unit)")
        }
    }

    func testZeroAndNegativeLengthsAreRefused() {
        XCTAssertNil(EndDateUnit.moment(afterMinutes: 0, from: now))
        XCTAssertNil(EndDateUnit.moment(afterMinutes: -5, from: now))
    }

    func testAMomentMonthsAheadStillDescribesItsDate() throws {
        let far = try XCTUnwrap(EndDateUnit.moment(afterMinutes: 30 * EndDateUnit.weeks.minutes, from: now))
        XCTAssertFalse(EndDateText.describe(far, now: now).isEmpty)
        XCTAssertNotNil(EndDateText.timeLeft(until: far, now: now))
    }
}
