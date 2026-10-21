import AppKit
import XCTest
@testable import TBPK

@MainActor
final class EnergyMenuTests: XCTestCase {
    private func menu(_ stored: EnergyProfile, _ plan: EnergyPlan, _ conditions: EnergyPlan.Conditions = .init()) throws -> NSMenu {
        let parent = EnergyMenu.item(target: StubMenuTarget(), stored: stored, plan: plan, conditions: conditions)
        XCTAssertEqual(parent.title, "Energy use")
        return try XCTUnwrap(parent.submenu)
    }

    func testEveryChoiceIsOfferedAndOnlyTheStoredOneIsTicked() throws {
        for stored in EnergyProfile.allCases {
            let items = try menu(stored, .standard).items.filter { $0.representedObject is String }
            XCTAssertEqual(items.map(\.title), EnergyProfile.allCases.map(\.title))
            XCTAssertEqual(items.filter { $0.state == .on }.map(\.title), [stored.title])
        }
    }

    func testTheMenuSaysWhatIsHappeningNowAndWhy() throws {
        let lines = try menu(.automatic, .saver, .init(onBattery: true)).items.map(\.title)
        XCTAssertTrue(lines.contains("Right now: still leaf (on battery)"), lines.description)
        let lowPower = try menu(.automatic, .saver, .init(onBattery: true, lowPowerMode: true)).items.map(\.title)
        XCTAssertTrue(lowPower.contains("Right now: still leaf (Low Power Mode is on)"), lowPower.description)
        let charger = try menu(.automatic, .standard).items.map(\.title)
        XCTAssertTrue(charger.contains("Right now: calm heartbeat (on the charger)"), charger.description)
    }

    func testAFixedChoiceDoesNotBlameMacOS() throws {
        let lines = try menu(.full, .full, .init(onBattery: true)).items.map(\.title)
        XCTAssertTrue(lines.contains("Right now: continuous heartbeat"), lines.description)
    }

    func testTheChoiceLivesInSettings() throws {
        let settings = try XCTUnwrap(SettingsMenu.item(target: StubMenuTarget()).submenu)
        XCTAssertTrue(settings.items.contains { $0.title == "Energy use" })
    }
}
