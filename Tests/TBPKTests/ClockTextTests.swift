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
}
