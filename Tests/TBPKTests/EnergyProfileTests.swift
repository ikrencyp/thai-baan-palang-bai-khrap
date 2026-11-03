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
        defaults.set("turbo", forKey: EnergyProfile.Slot.charger.storageKey)
        XCTAssertEqual(EnergyProfile.stored(in: defaults), .automatic)
    }

    func testOneChoiceCountsForBothWhileSeparateIsOff() {
        let store = scratchDefaults("tbpk-energy")
        EnergyProfile.full.store(in: store)
        XCTAssertEqual(EnergyProfile.active(onBattery: false, in: store), .full)
        XCTAssertEqual(EnergyProfile.active(onBattery: true, in: store), .full)
    }

    func testSeparateKeepsEachSourceItsOwnChoiceAndRemembersThemWhenSwitchedOff() {
        let store = scratchDefaults("tbpk-energy")
        EnergyProfile.full.store(.charger, in: store)
        EnergyProfile.setSeparate(true, in: store)
        XCTAssertEqual(EnergyProfile.stored(.battery, in: store), .full)
        EnergyProfile.saver.store(.battery, in: store)
        XCTAssertEqual(EnergyProfile.active(onBattery: false, in: store), .full)
        XCTAssertEqual(EnergyProfile.active(onBattery: true, in: store), .saver)
        EnergyProfile.setSeparate(false, in: store)
        XCTAssertEqual(EnergyProfile.active(onBattery: true, in: store), .full)
        EnergyProfile.setSeparate(true, in: store)
        XCTAssertEqual(EnergyProfile.active(onBattery: true, in: store), .saver)
    }
}
