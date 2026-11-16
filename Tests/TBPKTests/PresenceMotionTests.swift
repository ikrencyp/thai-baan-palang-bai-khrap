import XCTest
@testable import TBPK

final class PresenceMotionTests: XCTestCase {
    func testDefaultsToSteady() {
        XCTAssertEqual(PresenceMotion.stored(in: scratchDefaults("PresenceMotion")), .steady)
    }

    func testStoresAndLoadsAllCases() {
        let defaults = scratchDefaults("PresenceMotion")
        for choice in PresenceMotion.allCases {
            choice.store(in: defaults)
            XCTAssertEqual(PresenceMotion.stored(in: defaults), choice)
        }
    }

    func testAnUnknownStoredValueFallsBackToSteady() {
        let defaults = scratchDefaults("PresenceMotion")
        defaults.set("jitter", forKey: PresenceMotion.storageKey)
        XCTAssertEqual(PresenceMotion.stored(in: defaults), .steady)
    }

    func testSteadyAlwaysWaitsHalfAMinute() {
        for _ in 0 ..< 20 { XCTAssertEqual(PresenceMotion.steady.nextGap(), 30) }
    }

    func testRandomWaitsBetweenTwentyAndSixtySecondsAndNotAlwaysTheSame() {
        let gaps = (0 ..< 50).map { _ in PresenceMotion.random.nextGap() }
        XCTAssertTrue(gaps.allSatisfy { (20 ... 60).contains($0) })
        XCTAssertGreaterThan(Set(gaps).count, 1)
    }
}
