import XCTest
@testable import TBPK

final class QuitPlanTests: XCTestCase {
    func testQuittingGivesBackTheSettingOnlyWhenTheAppSwitchedSleepOff() {
        XCTAssertEqual(QuitPlan.decide(sleepDisabled: true, ownsOverride: true), .restoreThenQuit)
    }

    func testAnOverrideTheAppDidNotSetIsLeftAsFound() {
        XCTAssertEqual(QuitPlan.decide(sleepDisabled: true, ownsOverride: false), .quitNow)
    }

    func testWithSleepAlreadyAllowedThereIsNothingToGiveBack() {
        XCTAssertEqual(QuitPlan.decide(sleepDisabled: false, ownsOverride: true), .quitNow)
        XCTAssertEqual(QuitPlan.decide(sleepDisabled: false, ownsOverride: false), .quitNow)
    }

    func testOwnershipIsStoredAndCleared() {
        let saved = SleepOwnership.isOwned
        defer { SleepOwnership.isOwned = saved }
        SleepOwnership.isOwned = true
        XCTAssertTrue(SleepOwnership.isOwned)
        SleepOwnership.isOwned = false
        XCTAssertFalse(SleepOwnership.isOwned)
    }
}
