import XCTest
@testable import TBPK

final class PowerLimitTests: XCTestCase {
    func testNeverStopsAnything() {
        XCTAssertNil(PowerLimit.none.stopReason(onBattery: true, percent: 1))
    }

    func testThePercentLimitsStopOnlyBelowTheirFloorAndOnlyOnBattery() {
        XCTAssertNil(PowerLimit.below20.stopReason(onBattery: true, percent: 20))
        XCTAssertNotNil(PowerLimit.below20.stopReason(onBattery: true, percent: 19))
        XCTAssertNil(PowerLimit.below20.stopReason(onBattery: false, percent: 5))
        XCTAssertNil(PowerLimit.below10.stopReason(onBattery: true, percent: 10))
        XCTAssertNotNil(PowerLimit.below10.stopReason(onBattery: true, percent: 9))
    }

    func testAnUnreadablePercentNeverStopsAPercentLimit() {
        XCTAssertNil(PowerLimit.below20.stopReason(onBattery: true, percent: nil))
    }

    func testChargerOnlyStopsTheMomentTheChargerIsOut() {
        XCTAssertNotNil(PowerLimit.chargerOnly.stopReason(onBattery: true, percent: 100))
        XCTAssertNil(PowerLimit.chargerOnly.stopReason(onBattery: false, percent: 100))
    }

    func testTheReasonNamesThePercent() {
        XCTAssertEqual(PowerLimit.below20.stopReason(onBattery: true, percent: 17), "Battery fell to 17%, so normal sleep is back.")
    }

    func testTheDisplayIsHeldOnlyWhileAwakeAndNotDarkened() {
        XCTAssertTrue(DisplayPolicy.holdsDisplay(awake: true, darkenWhenClosed: true, locked: false, lidClosed: false))
        XCTAssertFalse(DisplayPolicy.holdsDisplay(awake: true, darkenWhenClosed: true, locked: true, lidClosed: false))
        XCTAssertFalse(DisplayPolicy.holdsDisplay(awake: true, darkenWhenClosed: true, locked: false, lidClosed: true))
        XCTAssertTrue(DisplayPolicy.holdsDisplay(awake: true, darkenWhenClosed: false, locked: true, lidClosed: true))
        XCTAssertFalse(DisplayPolicy.holdsDisplay(awake: false, darkenWhenClosed: false, locked: false, lidClosed: false))
        XCTAssertFalse(DisplayPolicy.holdsDisplay(awake: true, keepScreenOn: false, darkenWhenClosed: false, locked: false, lidClosed: false),
                       "with the switch off the app asks macOS for nothing about the display")
    }
}
