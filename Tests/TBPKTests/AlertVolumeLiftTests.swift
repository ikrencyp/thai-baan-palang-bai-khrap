import XCTest
@testable import TBPK

@MainActor
final class AlertVolumeLiftTests: XCTestCase {
    func testTheDefaultAlertLevelIsFullVolume() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: AlertVolumeLift.storageKey)
        defaults.removeObject(forKey: AlertVolumeLift.storageKey)
        XCTAssertEqual(AlertVolumeLift.storedLevel, 1, accuracy: 0.0001)
        if let saved { defaults.set(saved, forKey: AlertVolumeLift.storageKey) } else {
            defaults.removeObject(forKey: AlertVolumeLift.storageKey)
        }
    }

    func testAChannelBelowTheTargetIsRaisedToIt() {
        XCTAssertEqual(AlertVolumeLift.level(for: 0.2, target: 1), 1)
        XCTAssertEqual(AlertVolumeLift.level(for: 0.699, target: 0.7), 0.7)
        XCTAssertEqual(AlertVolumeLift.level(for: 0.2, target: 0.5), 0.5)
    }

    func testTheAlertNeverTurnsAnythingDown() {
        XCTAssertNil(AlertVolumeLift.level(for: 1, target: 1))
        XCTAssertNil(AlertVolumeLift.level(for: 0.95, target: 0.5))
        XCTAssertNil(AlertVolumeLift.level(for: 0.8, target: 0.8))
    }

    func testAnUnreadableChannelIsLeftAlone() {
        XCTAssertNil(AlertVolumeLift.level(for: nil, target: 1))
    }

    func testTheStoredLevelIsClampedToTheUnitRange() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: AlertVolumeLift.storageKey)
        defaults.set(1.7, forKey: AlertVolumeLift.storageKey)
        XCTAssertEqual(AlertVolumeLift.storedLevel, 1, accuracy: 0.0001)
        defaults.set(-0.4, forKey: AlertVolumeLift.storageKey)
        XCTAssertEqual(AlertVolumeLift.storedLevel, 0, accuracy: 0.0001)
        defaults.set(0.6, forKey: AlertVolumeLift.storageKey)
        XCTAssertEqual(AlertVolumeLift.storedLevel, 0.6, accuracy: 0.0001)
        if let saved { defaults.set(saved, forKey: AlertVolumeLift.storageKey) } else {
            defaults.removeObject(forKey: AlertVolumeLift.storageKey)
        }
    }
}
