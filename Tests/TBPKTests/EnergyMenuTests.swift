import AppKit
import XCTest
@testable import TBPK

@MainActor
final class EnergyMenuTests: XCTestCase {
    private func menu(_ stored: EnergyProfile, _ plan: EnergyPlan, _ conditions: EnergyPlan.Conditions = .init(),
                      battery: EnergyProfile? = nil, separate: Bool = false) throws -> NSMenu {
        let parent = EnergyMenu.item(target: StubMenuTarget(), charger: stored, battery: battery ?? stored, separate: separate,
                                     plan: plan, conditions: conditions)
        XCTAssertEqual(parent.title, "Energy use")
        return try XCTUnwrap(parent.submenu)
    }

    func testEveryChoiceIsOfferedAndOnlyTheStoredOneIsTicked() throws {
        for stored in EnergyProfile.allCases {
            let items = try menu(stored, .standard).items.filter { $0.representedObject is EnergyProfile.Pick }
            XCTAssertEqual(items.map(\.title), EnergyProfile.allCases.map(\.title))
            XCTAssertEqual(items.filter { $0.state == .on }.map(\.title), [stored.title])
        }
    }

    func testTheMenuSaysWhatIsHappeningNowAndWhy() throws {
        let lines = try menu(.automatic, .standard, .init(onBattery: true)).items.map(\.title)
        XCTAssertTrue(lines.contains("Right now: calm heartbeat (on battery)"), lines.description)
        let reduced = try menu(.automatic, .saver, .init(reduceMotion: true)).items.map(\.title)
        XCTAssertTrue(reduced.contains("Right now: still leaf (Reduce Motion is on)"), reduced.description)
        let charger = try menu(.automatic, .standard).items.map(\.title)
        XCTAssertTrue(charger.contains("Right now: calm heartbeat (on the charger)"), charger.description)
    }

    func testAFixedChoiceDoesNotBlameMacOS() throws {
        let lines = try menu(.full, .full, .init(onBattery: true)).items.map(\.title)
        XCTAssertTrue(lines.contains("Right now: continuous heartbeat"), lines.description)
    }

    func testSeparateOffShowsOneListAndTheSwitch() throws {
        let items = try menu(.full, .full).items
        let toggle = try XCTUnwrap(items.first { $0.title == "Set charger and battery separately" })
        XCTAssertEqual(toggle.state, .off)
    }

    func testSeparateOnShowsOneListPerPowerSourceEachTickingItsOwnChoice() throws {
        let items = try menu(.full, .standard, .init(onBattery: true), battery: .saver, separate: true).items
        XCTAssertEqual(items.first { $0.title == "Set charger and battery separately" }?.state, .on)
        func ticked(_ title: String) throws -> [String] {
            let sub = try XCTUnwrap(items.first { $0.title == title }?.submenu)
            XCTAssertEqual(sub.items.compactMap { ($0.representedObject as? EnergyProfile.Pick)?.slot }.count, 3)
            return sub.items.filter { $0.state == .on }.map(\.title)
        }
        XCTAssertEqual(try ticked("On the charger"), [EnergyProfile.full.title])
        XCTAssertEqual(try ticked("On battery"), [EnergyProfile.saver.title])
    }

    func testTheMenuLineFollowsTheChoiceOfTheSourceInUse() throws {
        let lines = try menu(.full, .saver, .init(onBattery: true), battery: .saver, separate: true).items.map(\.title)
        XCTAssertTrue(lines.contains("Right now: still leaf"), lines.description)
    }

    func testTheChoiceLivesInPowerRules() throws {
        let rules = try XCTUnwrap(PowerRulesMenu.item(target: StubMenuTarget()).submenu)
        XCTAssertTrue(rules.items.contains { $0.title == "Energy use" })
        let settings = try XCTUnwrap(SettingsMenu.item(target: StubMenuTarget()).submenu)
        XCTAssertFalse(settings.items.contains { $0.title == "Energy use" })
    }

    func testTheRowsStayOpenAndTheListReshapesInPlaceWhenSeparateFlips() async throws {
        let defaults = UserDefaults.standard
        let keys = [EnergyProfile.Slot.charger.storageKey, EnergyProfile.Slot.battery.storageKey, EnergyProfile.separateKey]
        let saved = keys.map { defaults.object(forKey: $0) }
        defer { zip(keys, saved).forEach { defaults.set($1, forKey: $0) } }
        keys.forEach(defaults.removeObject(forKey:))
        final class Target: StubMenuTarget {
            override func energyProfileClicked(_ item: NSMenuItem) {
                (item.representedObject as? EnergyProfile.Pick).map { $0.profile.store($0.slot) }
            }
            override func energySeparateClicked(_ item: NSMenuItem) { EnergyProfile.setSeparate(item.state != .on) }
        }
        let parent = EnergyMenu.item(target: Target())
        let menu = try XCTUnwrap(parent.submenu)
        func row(_ title: String) throws -> (NSMenuItem, StayOpenRow) {
            let item = try XCTUnwrap(menu.items.first { $0.title == title })
            return (item, try XCTUnwrap(item.view as? StayOpenRow))
        }
        let full = try row(EnergyProfile.full.title)
        full.1.performPick()
        XCTAssertEqual(EnergyProfile.stored(), .full)
        XCTAssertEqual(full.0.state, .on, "the tick moves at once, the menu is not rebuilt")
        XCTAssertEqual(try row(EnergyProfile.automatic.title).0.state, .off)
        XCTAssertTrue(menu.items.contains { $0.title.hasPrefix("Right now:") })

        try row("Set charger and battery separately").1.performPick()
        await MainActor.run {}
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(menu.items.filter { $0.submenu != nil }.map(\.title), ["On the charger", "On battery"])
        XCTAssertEqual(try row("Set charger and battery separately").0.state, .on)
        XCTAssertTrue(parent.title == "Energy use" && menu.items.contains { $0.title.hasPrefix("Right now:") })
    }
}
