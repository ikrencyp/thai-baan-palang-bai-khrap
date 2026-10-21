import AppKit
import XCTest
@testable import TBPK

final class MenuBarIconResolutionTests: XCTestCase {
    func testIdleShowsOutlineLeafWithoutPulse() {
        XCTAssertEqual(
            MenuBarIcon.resolve(isSleepDisabled: false, isWorking: false, hasTimer: false, hasFailure: false),
            .normalSleep
        )
        XCTAssertFalse(MenuBarIcon.normalSleep.isAwake)
        XCTAssertFalse(MenuBarIcon.normalSleep.isPulsing)
    }

    func testAwakeWithoutTimerShowsFilledLeafAndPulses() {
        XCTAssertEqual(
            MenuBarIcon.resolve(isSleepDisabled: true, isWorking: false, hasTimer: false, hasFailure: false),
            .disabledIndefinite
        )
        XCTAssertTrue(MenuBarIcon.disabledIndefinite.isAwake)
        XCTAssertTrue(MenuBarIcon.disabledIndefinite.isPulsing)
    }

    func testAwakeWithTimerShowsFilledLeaf() {
        XCTAssertEqual(
            MenuBarIcon.resolve(isSleepDisabled: true, isWorking: false, hasTimer: true, hasFailure: false),
            .disabledTimed
        )
        XCTAssertTrue(MenuBarIcon.disabledTimed.isAwake)
        XCTAssertTrue(MenuBarIcon.disabledTimed.isPulsing)
    }

    func testBusyOutranksAwake() {
        XCTAssertEqual(
            MenuBarIcon.resolve(isSleepDisabled: true, isWorking: true, hasTimer: true, hasFailure: false),
            .busy
        )
        XCTAssertFalse(MenuBarIcon.busy.isAwake)
    }

    func testFailureOutranksEverything() {
        XCTAssertEqual(
            MenuBarIcon.resolve(isSleepDisabled: true, isWorking: true, hasTimer: true, hasFailure: true),
            .failed
        )
        XCTAssertFalse(MenuBarIcon.failed.isAwake)
    }

    func testTheFailureSymbolExistsOnThisSystem() {
        XCTAssertNotNil(LeafGlyph.failureImage())
    }
}
