import XCTest
@testable import TBPK

final class EndDateUnitTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testEveryUnitCountsFromNow() throws {
        for (unit, seconds) in [(EndDateUnit.minutes, 60.0), (.hours, 3_600), (.days, 86_400), (.weeks, 604_800)] {
            let moment = try XCTUnwrap(unit.moment(after: 3, from: now))
            XCTAssertEqual(moment.timeIntervalSince(now), 3 * seconds, accuracy: 60, "\(unit)")
        }
    }

    func testZeroNegativeAndAbsurdAmountsAreRefused() {
        XCTAssertNil(EndDateUnit.hours.moment(after: 0, from: now))
        XCTAssertNil(EndDateUnit.hours.moment(after: -5, from: now))
        XCTAssertNil(EndDateUnit.weeks.moment(after: EndDateUnit.largestAmount + 1, from: now))
        XCTAssertNotNil(EndDateUnit.weeks.moment(after: EndDateUnit.largestAmount, from: now))
    }

    func testAMomentMonthsAheadStillDescribesItsDate() throws {
        let far = try XCTUnwrap(EndDateUnit.weeks.moment(after: 30, from: now))
        XCTAssertFalse(EndDateText.describe(far, now: now).isEmpty)
        XCTAssertNotNil(EndDateText.timeLeft(until: far, now: now))
    }
}
