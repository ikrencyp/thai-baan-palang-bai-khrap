import XCTest
@testable import TBPK

final class UnattendedDecisionTests: XCTestCase {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)
    private let hold = UnattendedDecision.holdTime
    private let every = LidWarningMode.everyFiveMinutes
    private var everyInterval: TimeInterval { every.repeatInterval ?? 0 }

    private func at(_ seconds: TimeInterval) -> Date { epoch.addingTimeInterval(seconds) }

    private func snapshot(
        lid: Bool = false,
        locked: Bool = false,
        battery: Bool = true,
        buzzing: Bool = true,
        external: Bool = false
    ) -> UnattendedSnapshot {
        UnattendedSnapshot(
            lidClosed: lid, screenLocked: locked, onBattery: battery, buzzing: buzzing, hasExternalDisplay: external)
    }

    func testTheHoldIsOneAndAHalfSeconds() {
        XCTAssertEqual(UnattendedDecision.holdTime, 1.5, accuracy: 0.0001)
    }

    func testBeepWaitsForTheHoldAndThenFires() {
        var decision = UnattendedDecision()
        let lid = snapshot(lid: true)
        XCTAssertNil(decision.observe(lid, mode: every, now: at(0)))
        XCTAssertNil(decision.observe(lid, mode: every, now: at(hold - 0.1)))
        let event = decision.observe(lid, mode: every, now: at(hold))
        XCTAssertEqual(event?.kind, .lidClosed)
        XCTAssertNil(decision.observe(lid, mode: every, now: at(4)))
    }

    func testEventCarriesTheMomentTheLidWentDownNotTheBeep() {
        var decision = UnattendedDecision()
        let lid = snapshot(lid: true)
        _ = decision.observe(lid, mode: every, now: at(0))
        XCTAssertEqual(decision.observe(lid, mode: every, now: at(5))?.startedAt, at(0))
    }

    func testColourMarksTheStateFromTheFirstTickEvenBeforeTheBeepIsDue() {
        var decision = UnattendedDecision()
        XCTAssertNil(decision.observe(snapshot(lid: true), mode: every, now: at(0)))
        XCTAssertTrue(decision.isAlerting)
    }

    func testRepeatIntervalWaitsForTheChosenGapThenKeepsGoing() {
        var decision = UnattendedDecision()
        let lid = snapshot(lid: true)
        _ = decision.observe(lid, mode: every, now: at(0))
        XCTAssertNotNil(decision.observe(lid, mode: every, now: at(5)))
        let justBefore = decision.observe(lid, mode: every, now: at(5 + everyInterval - 1))
        XCTAssertNil(justBefore)
        XCTAssertNotNil(decision.observe(lid, mode: every, now: at(5 + everyInterval)))
        XCTAssertNotNil(decision.observe(lid, mode: every, now: at(5 + 2 * everyInterval)))
    }

    func testReopeningTheLidWithinTheHoldNeverBeeps() {
        var decision = UnattendedDecision()
        XCTAssertNil(decision.observe(snapshot(lid: true), mode: every, now: at(0)))
        XCTAssertNil(decision.observe(snapshot(lid: false), mode: every, now: at(hold)))
        XCTAssertFalse(decision.isAlerting)
    }

    func testANewEpisodeRestartsTheHold() {
        var decision = UnattendedDecision()
        _ = decision.observe(snapshot(lid: true), mode: every, now: at(0))
        XCTAssertNotNil(decision.observe(snapshot(lid: true), mode: every, now: at(hold)))
        _ = decision.observe(snapshot(lid: false), mode: every, now: at(20))
        _ = decision.observe(snapshot(lid: true), mode: every, now: at(30))
        XCTAssertNil(decision.observe(snapshot(lid: true), mode: every, now: at(30 + hold - 1)))
        XCTAssertNotNil(decision.observe(snapshot(lid: true), mode: every, now: at(30 + hold)))
    }

    func testPluggingInCancelsAPendingBeep() {
        var decision = UnattendedDecision()
        XCTAssertNil(decision.observe(snapshot(lid: true), mode: every, now: at(0)))
        XCTAssertNil(decision.observe(snapshot(lid: true, battery: false), mode: every, now: at(9)))
        XCTAssertFalse(decision.isAlerting)
    }

    func testNothingHappensWhileSleepIsNormal() {
        var decision = UnattendedDecision()
        _ = decision.observe(snapshot(lid: true), mode: every, now: at(0))
        XCTAssertNil(decision.observe(snapshot(lid: true, buzzing: false), mode: every, now: at(9)))
        XCTAssertFalse(decision.isAlerting)
    }

    func testOffModeNeitherBeepsNorTints() {
        var decision = UnattendedDecision()
        let lid = snapshot(lid: true)
        XCTAssertNil(decision.observe(lid, mode: .off, now: at(0)))
        XCTAssertNil(decision.observe(lid, mode: .off, now: at(30)))
        XCTAssertFalse(decision.isAlerting)
    }

    func testFirstTimeOnlyBeepsOncePerEpisodeButNotOnTheRepeatGap() {
        var decision = UnattendedDecision()
        let lid = snapshot(lid: true)
        _ = decision.observe(lid, mode: .firstTimeOnly, now: at(0))
        XCTAssertNotNil(decision.observe(lid, mode: .firstTimeOnly, now: at(5)))
        XCTAssertNil(decision.observe(lid, mode: .firstTimeOnly, now: at(5 + 10 * everyInterval)))
    }

    func testFirstTimeOnlyBeepsAgainOnTheNextEpisodeOfTheSameSession() {
        var decision = UnattendedDecision()
        _ = decision.observe(snapshot(lid: true), mode: .firstTimeOnly, now: at(0))
        XCTAssertNotNil(decision.observe(snapshot(lid: true), mode: .firstTimeOnly, now: at(hold)))
        _ = decision.observe(snapshot(lid: false), mode: .firstTimeOnly, now: at(20))
        _ = decision.observe(snapshot(lid: true), mode: .firstTimeOnly, now: at(30))
        XCTAssertNil(decision.observe(snapshot(lid: true), mode: .firstTimeOnly, now: at(30 + hold - 1)))
        XCTAssertNotNil(decision.observe(snapshot(lid: true), mode: .firstTimeOnly, now: at(30 + hold)))
    }

    func testFirstTimeOnlyStillTintsWhileItIsQuiet() {
        var decision = UnattendedDecision()
        _ = decision.observe(snapshot(lid: true), mode: .firstTimeOnly, now: at(0))
        XCTAssertNotNil(decision.observe(snapshot(lid: true), mode: .firstTimeOnly, now: at(5)))
        _ = decision.observe(snapshot(lid: false), mode: .firstTimeOnly, now: at(20))
        XCTAssertFalse(decision.isAlerting)
        _ = decision.observe(snapshot(lid: true), mode: .firstTimeOnly, now: at(30))
        XCTAssertTrue(decision.isAlerting)
    }

    func testLockAloneIsReportedAsTheScreenLock() {
        var decision = UnattendedDecision()
        let locked = snapshot(locked: true)
        _ = decision.observe(locked, mode: every, now: at(0))
        XCTAssertEqual(decision.observe(locked, mode: every, now: at(5))?.kind, .screenLocked)
    }

    func testLidOutranksTheLockWhenBothAreTrue() {
        var decision = UnattendedDecision()
        let both = snapshot(lid: true, locked: true)
        _ = decision.observe(both, mode: every, now: at(0))
        XCTAssertEqual(decision.observe(both, mode: every, now: at(5))?.kind, .lidClosed)
    }

    func testClosingTheLidOnAnAlreadyLockedScreenWarnsAgain() {
        for mode in [LidWarningMode.firstTimeOnly, every] {
            var decision = UnattendedDecision()
            _ = decision.observe(snapshot(locked: true), mode: mode, now: at(0))
            XCTAssertEqual(decision.observe(snapshot(locked: true), mode: mode, now: at(hold))?.kind, .screenLocked)
            XCTAssertNil(decision.observe(snapshot(lid: true, locked: true), mode: mode, now: at(10)))
            XCTAssertNil(decision.observe(snapshot(lid: true, locked: true), mode: mode, now: at(10 + hold - 1)))
            XCTAssertEqual(decision.observe(snapshot(lid: true, locked: true), mode: mode, now: at(10 + hold))?.kind, .lidClosed)
        }
    }

    func testOpeningTheLidOnAStillLockedScreenIsNotANewRisk() {
        var decision = UnattendedDecision()
        _ = decision.observe(snapshot(lid: true, locked: true), mode: .firstTimeOnly, now: at(0))
        XCTAssertNotNil(decision.observe(snapshot(lid: true, locked: true), mode: .firstTimeOnly, now: at(hold)))
        XCTAssertNil(decision.observe(snapshot(locked: true), mode: .firstTimeOnly, now: at(20)))
        XCTAssertNil(decision.observe(snapshot(locked: true), mode: .firstTimeOnly, now: at(60)))
        XCTAssertTrue(decision.isAlerting)
    }

    func testPullingTheChargerWhileClosedWarnsAgainUnderAnyPower() {
        var decision = UnattendedDecision()
        let plugged = snapshot(lid: true, battery: false)
        _ = decision.observe(plugged, mode: .firstTimeOnly, condition: .anyPower, now: at(0))
        let first = decision.observe(plugged, mode: .firstTimeOnly, condition: .anyPower, now: at(hold))
        XCTAssertEqual(first?.onBattery, false)
        let drained = snapshot(lid: true, battery: true)
        XCTAssertNil(decision.observe(drained, mode: .firstTimeOnly, condition: .anyPower, now: at(10)))
        let second = decision.observe(drained, mode: .firstTimeOnly, condition: .anyPower, now: at(10 + hold))
        XCTAssertEqual(second?.onBattery, true)
    }

    func testPluggingInStaysQuietUnderAnyPowerWhenAlreadyWarned() {
        var decision = UnattendedDecision()
        _ = decision.observe(snapshot(lid: true), mode: .firstTimeOnly, condition: .anyPower, now: at(0))
        XCTAssertNotNil(decision.observe(snapshot(lid: true), mode: .firstTimeOnly, condition: .anyPower, now: at(hold)))
        let plugged = snapshot(lid: true, battery: false)
        XCTAssertNil(decision.observe(plugged, mode: .firstTimeOnly, condition: .anyPower, now: at(10)))
        XCTAssertNil(decision.observe(plugged, mode: .firstTimeOnly, condition: .anyPower, now: at(60)))
    }

    func testBatteryOnlyNeverWarnsOnTheCharger() {
        var decision = UnattendedDecision()
        let plugged = snapshot(lid: true, battery: false)
        XCTAssertNil(decision.observe(plugged, mode: every, condition: .batteryOnly, now: at(0)))
        XCTAssertNil(decision.observe(plugged, mode: every, condition: .batteryOnly, now: at(30)))
        XCTAssertFalse(decision.isAlerting)
    }

    func testAnyPowerWarnsOnTheChargerAndSaysSo() {
        var decision = UnattendedDecision()
        let plugged = snapshot(locked: true, battery: false)
        _ = decision.observe(plugged, mode: every, condition: .anyPower, now: at(0))
        let event = decision.observe(plugged, mode: every, condition: .anyPower, now: at(hold))
        XCTAssertEqual(event?.kind, .screenLocked)
        XCTAssertEqual(event?.onBattery, false)
    }

    func testUnplugAfterTheLidWentDownStillWarnsUnderBatteryOnly() {
        var decision = UnattendedDecision()
        _ = decision.observe(snapshot(lid: true, battery: false), mode: every, now: at(0))
        _ = decision.observe(snapshot(lid: true, battery: true), mode: every, now: at(5))
        XCTAssertNotNil(decision.observe(snapshot(lid: true, battery: true), mode: every, now: at(5 + hold)))
    }

    func testClamshellOnAMonitorStaysQuiet() {
        var decision = UnattendedDecision()
        let clamshell = snapshot(lid: true, external: true)
        XCTAssertNil(decision.observe(clamshell, mode: every, now: at(0)))
        XCTAssertNil(decision.observe(clamshell, mode: every, now: at(30)))
        XCTAssertFalse(decision.isAlerting)
    }

    func testChangingTheRepeatModeMidEpisodeKeepsTheWarnedState() {
        var decision = UnattendedDecision()
        let lid = snapshot(lid: true)
        _ = decision.observe(lid, mode: .firstTimeOnly, now: at(0))
        XCTAssertNotNil(decision.observe(lid, mode: .firstTimeOnly, now: at(hold)))
        XCTAssertNotNil(decision.observe(lid, mode: .everyFiveMinutes, now: at(hold + everyInterval)))
    }

    func testNothingIsPendingBeforeAnEpisodeStarts() {
        let decision = UnattendedDecision()
        XCTAssertNil(decision.nextWake(mode: every, now: at(0)))
    }

    func testTheWatchSleepsUntilTheHoldRunsOut() {
        var decision = UnattendedDecision()
        _ = decision.observe(snapshot(lid: true), mode: every, now: at(0))
        XCTAssertEqual(try XCTUnwrap(decision.nextWake(mode: every, now: at(0))), hold, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(decision.nextWake(mode: every, now: at(1))), hold - 1, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(decision.nextWake(mode: every, now: at(5))), 0, accuracy: 0.0001, "overdue means now")
    }

    func testAfterTheBeepTheWatchSleepsUntilTheNextRepeat() {
        var decision = UnattendedDecision()
        let lid = snapshot(lid: true)
        _ = decision.observe(lid, mode: every, now: at(0))
        XCTAssertNotNil(decision.observe(lid, mode: every, now: at(2)))
        XCTAssertEqual(try XCTUnwrap(decision.nextWake(mode: every, now: at(2))), everyInterval, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(decision.nextWake(mode: every, now: at(2 + 100))), everyInterval - 100, accuracy: 0.0001)
    }

    func testAfterTheOnlyBeepNothingIsLeftToDecideByItself() {
        var decision = UnattendedDecision()
        let lid = snapshot(lid: true)
        _ = decision.observe(lid, mode: .firstTimeOnly, now: at(0))
        XCTAssertNotNil(decision.observe(lid, mode: .firstTimeOnly, now: at(2)))
        XCTAssertNil(decision.nextWake(mode: .firstTimeOnly, now: at(3)), "only a change in the Mac can matter now")
    }

    func testEndingTheSessionClearsThePendingWake() {
        var decision = UnattendedDecision()
        _ = decision.observe(snapshot(lid: true), mode: every, now: at(0))
        decision.endSession()
        XCTAssertNil(decision.nextWake(mode: every, now: at(1)))
    }
}
