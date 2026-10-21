import XCTest
@testable import TBPK

final class ClockTextTests: XCTestCase {
    func testUnderAnHourDropsTheHourField() {
        XCTAssertEqual(ClockText.short(1800), "30:00")
        XCTAssertEqual(ClockText.short(59), "0:59")
    }

    func testAnHourOrMoreKeepsTheHourField() {
        XCTAssertEqual(ClockText.short(3600), "1:00:00")
        XCTAssertEqual(ClockText.short(45296), "12:34:56")
    }

    func testZeroAndNegativeClampToZero() {
        XCTAssertEqual(ClockText.short(0), "0:00")
        XCTAssertEqual(ClockText.short(-5), "0:00")
    }

    func testCountsUpToTheNextWholeSecondSoZeroMeansExpired() {
        XCTAssertEqual(ClockText.short(3599.6), "1:00:00")
        XCTAssertEqual(ClockText.short(1799.4), "30:00")
        XCTAssertEqual(ClockText.short(0.4), "0:01")
    }

    func testCoarseTextShowsWholeMinutesRoundedUp() {
        XCTAssertEqual(ClockText.coarse(0), "0m")
        XCTAssertEqual(ClockText.coarse(30), "<1m")
        XCTAssertEqual(ClockText.coarse(60), "1m")
        XCTAssertEqual(ClockText.coarse(61), "2m")
        XCTAssertEqual(ClockText.coarse(740), "13m")
        XCTAssertEqual(ClockText.coarse(3540), "59m")
        XCTAssertEqual(ClockText.coarse(3600), "1h 00m")
        XCTAssertEqual(ClockText.coarse(3900), "1h 05m")
        XCTAssertEqual(ClockText.coarse(-5), "0m")
    }

    func testTheCoarseTextChangesExactlyWhenAMinuteBoundaryIsCrossed() {
        XCTAssertEqual(ClockText.untilCoarseChange(740), 20, accuracy: 1e-9)
        XCTAssertEqual(ClockText.untilCoarseChange(720), 60, accuracy: 1e-9)
        XCTAssertEqual(ClockText.untilCoarseChange(30), 30, accuracy: 1e-9)
        XCTAssertEqual(ClockText.untilCoarseChange(0), 0.5, accuracy: 1e-9)
        for remaining in [61.0, 125.5, 740, 3601] {
            let wait = ClockText.untilCoarseChange(remaining)
            XCTAssertNotEqual(ClockText.coarse(remaining), ClockText.coarse(remaining - wait - 0.001), "\(remaining)")
            XCTAssertEqual(ClockText.coarse(remaining), ClockText.coarse(remaining - wait + 0.001), "\(remaining)")
        }
    }
}
