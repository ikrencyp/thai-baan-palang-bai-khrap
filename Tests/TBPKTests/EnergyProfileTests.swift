import AppKit
import XCTest
@testable import TBPK

final class EnergyProfileTests: XCTestCase {
    func testAutomaticIsTheDefaultAndEveryChoiceIsRemembered() {
        let defaults = scratchDefaults("tbpk-energy")
        XCTAssertEqual(EnergyProfile.stored(in: defaults), .automatic)
        for profile in EnergyProfile.allCases {
            profile.store(in: defaults)
            XCTAssertEqual(EnergyProfile.stored(in: defaults), profile)
        }
    }

    func testAnUnknownStoredValueFallsBackToAutomatic() {
        let defaults = scratchDefaults("tbpk-energy")
        defaults.set("turbo", forKey: EnergyProfile.storageKey)
        XCTAssertEqual(EnergyProfile.stored(in: defaults), .automatic)
    }
}
