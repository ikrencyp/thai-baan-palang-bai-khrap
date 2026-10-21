import XCTest
@testable import TBPK

final class AlertSoundTests: XCTestCase {
    func testSystemAlertIsFirstAndAlwaysPresent() {
        let available = AlertSound.available
        XCTAssertEqual(available.first, .systemAlert)
        XCTAssertTrue(available.first?.isSystemAlert == true)
        XCTAssertFalse(AlertSound(name: "Basso").isSystemAlert)
    }

    func testMissingOrUnknownStoredNameFallsBackToTheSystemAlert() {
        let defaults = UserDefaults.standard
        let saved = defaults.string(forKey: AlertSound.storageKey)
        defaults.removeObject(forKey: AlertSound.storageKey)
        XCTAssertEqual(AlertSound.stored, .systemAlert)
        defaults.set("NotARealSoundName", forKey: AlertSound.storageKey)
        XCTAssertEqual(AlertSound.stored, .systemAlert)
        if let saved { defaults.set(saved, forKey: AlertSound.storageKey) } else {
            defaults.removeObject(forKey: AlertSound.storageKey)
        }
    }

    func testAStoredNameThatIsInstalledIsKept() throws {
        let installed = try XCTUnwrap(AlertSound.available.dropFirst().first)
        let defaults = UserDefaults.standard
        let saved = defaults.string(forKey: AlertSound.storageKey)
        defaults.set(installed.name, forKey: AlertSound.storageKey)
        XCTAssertEqual(AlertSound.stored, installed)
        if let saved { defaults.set(saved, forKey: AlertSound.storageKey) } else {
            defaults.removeObject(forKey: AlertSound.storageKey)
        }
    }
}
