import XCTest
@testable import TBPK

final class UnattendedSnapshotTests: XCTestCase {
    private func snapshot(
        lid: Bool,
        locked: Bool,
        battery: Bool,
        buzzing: Bool,
        external: Bool = false
    ) -> UnattendedSnapshot {
        UnattendedSnapshot(
            lidClosed: lid,
            screenLocked: locked,
            onBattery: battery,
            buzzing: buzzing,
            hasExternalDisplay: external
        )
    }

    func testUnattendedNeedsTheDrainStateAndSomebodyAbsenceAndBuzzing() {
        XCTAssertTrue(snapshot(lid: true, locked: false, battery: true, buzzing: true).isUnattended())
        XCTAssertTrue(snapshot(lid: false, locked: true, battery: true, buzzing: true).isUnattended())
        XCTAssertFalse(snapshot(lid: true, locked: true, battery: true, buzzing: false).isUnattended())
        XCTAssertFalse(snapshot(lid: true, locked: true, battery: false, buzzing: true).isUnattended())
        XCTAssertFalse(snapshot(lid: false, locked: false, battery: true, buzzing: true).isUnattended())
    }

    func testALidCloseWithAnExternalDisplayIsClamshellNotAlone() {
        let clamshell = snapshot(lid: true, locked: false, battery: true, buzzing: true, external: true)
        XCTAssertFalse(clamshell.isUnattended())
    }

    func testALidCloseWithNoExternalDisplayIsTheBagCase() {
        let inBag = snapshot(lid: true, locked: false, battery: true, buzzing: true, external: false)
        XCTAssertTrue(inBag.isUnattended())
        XCTAssertEqual(inBag.alertKind, .lidClosed)
    }

    func testClamshellStillWarnsWhenTheScreenLocks() {
        let lockedClamshell = snapshot(lid: true, locked: true, battery: true, buzzing: true, external: true)
        XCTAssertTrue(lockedClamshell.isUnattended())
        XCTAssertEqual(lockedClamshell.alertKind, .screenLocked)
    }

    func testMenuTextNamesTheEventTheTimeAndTheCause() throws {
        let components = DateComponents(year: 2026, month: 10, day: 1, hour: 14, minute: 32)
        let date = try XCTUnwrap(Calendar.current.date(from: components))
        XCTAssertEqual(
            UnattendedEvent(kind: .lidClosed, startedAt: date).menuText,
            "Lid closed 14:32 on battery")
        XCTAssertEqual(
            UnattendedEvent(kind: .screenLocked, startedAt: date).menuText,
            "Screen locked 14:32 on battery")
    }

    func testPluggedInCountsOnlyWhenTheConditionAsksForIt() {
        let plugged = snapshot(lid: true, locked: false, battery: false, buzzing: true)
        XCTAssertFalse(plugged.isUnattended(under: .batteryOnly))
        XCTAssertTrue(plugged.isUnattended(under: .anyPower))
    }

    func testBuzzingOffIsNeverUnattendedWhateverThePower() {
        let idle = snapshot(lid: true, locked: true, battery: true, buzzing: false)
        XCTAssertFalse(idle.isUnattended(under: .anyPower))
    }

    func testTriggersListEveryReasonNobodyIsThere() {
        XCTAssertEqual(snapshot(lid: true, locked: true, battery: true, buzzing: true).triggers, [.lidClosed, .screenLocked])
        XCTAssertEqual(snapshot(lid: true, locked: false, battery: true, buzzing: true, external: true).triggers, [])
    }

    func testSummaryReadsTheWholeStateInOneLine() {
        XCTAssertEqual(snapshot(lid: false, locked: false, battery: true, buzzing: true).summary,
                       "Lid open, unlocked, on battery")
        XCTAssertEqual(snapshot(lid: true, locked: true, battery: false, buzzing: true).summary,
                       "Lid closed, screen locked, plugged in")
        XCTAssertEqual(snapshot(lid: true, locked: false, battery: true, buzzing: true, external: true).summary,
                       "Lid closed, external display, unlocked, on battery")
    }

    func testMenuTextNamesAPluggedInEvent() throws {
        let components = DateComponents(year: 2026, month: 10, day: 1, hour: 14, minute: 32)
        let date = try XCTUnwrap(Calendar.current.date(from: components))
        XCTAssertEqual(UnattendedEvent(kind: .lidClosed, startedAt: date, onBattery: false).menuText,
                       "Lid closed 14:32 plugged in")
    }

    func testPowerConditionDefaultsToBatteryOnly() {
        let defaults = UserDefaults.standard
        let saved = defaults.string(forKey: PowerCondition.storageKey)
        defaults.removeObject(forKey: PowerCondition.storageKey)
        XCTAssertEqual(PowerCondition.stored, .batteryOnly)
        defaults.set("nonsense", forKey: PowerCondition.storageKey)
        XCTAssertEqual(PowerCondition.stored, .batteryOnly)
        if let saved { defaults.set(saved, forKey: PowerCondition.storageKey) } else {
            defaults.removeObject(forKey: PowerCondition.storageKey)
        }
    }

    func testWarningDefaultsToOnceAndAnUnparsableValueFallsBackToIt() {
        let defaults = UserDefaults.standard
        let saved = defaults.string(forKey: LidWarningMode.storageKey)
        defaults.removeObject(forKey: LidWarningMode.storageKey)
        XCTAssertEqual(LidWarningMode.stored, .firstTimeOnly)
        defaults.set("notAMode", forKey: LidWarningMode.storageKey)
        XCTAssertEqual(LidWarningMode.stored, .firstTimeOnly)
        if let saved { defaults.set(saved, forKey: LidWarningMode.storageKey) } else {
            defaults.removeObject(forKey: LidWarningMode.storageKey)
        }
    }

    func testOnlyTheEveryChoicesCarryARepeatInterval() {
        XCTAssertNil(LidWarningMode.off.repeatInterval)
        XCTAssertNil(LidWarningMode.firstTimeOnly.repeatInterval)
        XCTAssertEqual(LidWarningMode.everyFiveMinutes.repeatInterval, 300)
        XCTAssertEqual(LidWarningMode.everyFifteenMinutes.repeatInterval, 900)
        XCTAssertEqual(LidWarningMode.everyThirtyMinutes.repeatInterval, 1800)
    }
}
