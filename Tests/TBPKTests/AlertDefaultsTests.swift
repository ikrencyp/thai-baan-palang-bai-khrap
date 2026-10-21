import XCTest
@testable import TBPK

final class AlertDefaultsTests: XCTestCase {
    func testTheAlertIsOnByDefaultAndOnlyCountsWhenRunningOnBattery() {
        let defaults = UserDefaults.standard
        let saved = [LidWarningMode.storageKey, PowerCondition.storageKey].map { ($0, defaults.object(forKey: $0)) }
        defer { saved.forEach { defaults.set($0.1, forKey: $0.0) } }
        defaults.removeObject(forKey: LidWarningMode.storageKey)
        defaults.removeObject(forKey: PowerCondition.storageKey)
        XCTAssertEqual(LidWarningMode.stored, .firstTimeOnly)
        XCTAssertEqual(PowerCondition.stored, .batteryOnly)
        let locked = UnattendedSnapshot(lidClosed: false, screenLocked: true, onBattery: false, buzzing: true)
        XCTAssertFalse(locked.isUnattended(under: PowerCondition.stored))
        XCTAssertTrue(UnattendedSnapshot(lidClosed: false, screenLocked: true, onBattery: true, buzzing: true)
            .isUnattended(under: PowerCondition.stored))
        XCTAssertTrue(UnattendedSnapshot(lidClosed: true, screenLocked: false, onBattery: true, buzzing: true)
            .isUnattended(under: PowerCondition.stored))
    }

}
