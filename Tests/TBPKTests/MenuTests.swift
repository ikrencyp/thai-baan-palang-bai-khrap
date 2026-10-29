import AppKit
import XCTest
@testable import TBPK

@MainActor
final class MenuTests: XCTestCase {
    private let target = StubMenuTarget()

    private func submenu(_ parent: NSMenuItem, titled title: String) throws -> NSMenu {
        XCTAssertEqual(parent.title, title)
        return try XCTUnwrap(parent.submenu)
    }

    private func alertsMenu() throws -> NSMenu {
        let parent = AlertsMenu.item(power: PowerManager.shared, watch: UnattendedWatch(power: PowerManager.shared), target: target)
        return try submenu(parent, titled: "Alerts")
    }

    func testTheAlertsSubmenuLeadsWithWhatTheAppReadsRightNow() throws {
        let titles = try alertsMenu().items.map(\.title)
        XCTAssertTrue(try XCTUnwrap(titles.first).hasPrefix("Now: Lid "))
    }

    func testEveryHowOftenChoiceAndEveryPowerChoiceIsOffered() throws {
        let titles = try alertsMenu().items.map(\.title)
        for mode in LidWarningMode.allCases { XCTAssertTrue(titles.contains(mode.label), mode.label) }
        for condition in PowerCondition.allCases { XCTAssertTrue(titles.contains(condition.label), condition.label) }
    }

    func testExactlyOneChoiceIsTickedInEachAlertsRadioGroup() throws {
        let items = try alertsMenu().items
        let modes = Set(LidWarningMode.allCases.map(\.label))
        let powers = Set(PowerCondition.allCases.map(\.label))
        XCTAssertEqual(items.filter { modes.contains($0.title) && $0.state == .on }.count, 1)
        XCTAssertEqual(items.filter { powers.contains($0.title) && $0.state == .on }.count, 1)
    }

    func testTheAlertsMenuHoldsTheSoundCountAndVolumeToo() throws {
        let titles = try alertsMenu().items.map(\.title)
        for expected in ["Sound", "Play how many times", "Alert volume"] { XCTAssertTrue(titles.contains(expected), expected) }
    }

    func testTheSoundMenuHasChoicesCountAndVolumeAndNoSecondTestEntry() throws {
        let titles = try submenu(SoundMenu.item(target: target), titled: "Alert sound").items.map(\.title)
        for expected in ["Play how many times", "Alert volume", "Mac sounds"] {
            XCTAssertTrue(titles.contains(expected), expected)
        }
        XCTAssertFalse(titles.contains("Play test sound"))
    }

    func testTheSoundMenuHasMySoundsAndMacSoundsOnly() throws {
        let titles = try submenu(SoundMenu.item(target: target), titled: "Alert sound").items.map { $0.attributedTitle?.string ?? $0.title }
        XCTAssertTrue(titles.contains("MY SOUNDS"))
        XCTAssertFalse(titles.contains("SPECIAL SOUNDS"))
    }

    func testMySoundsEndWithTheFilePickerAndMacSoundsHoldTheSystemAlert() throws {
        let menu = try submenu(SoundMenu.item(target: target), titled: "Alert sound")
        XCTAssertTrue(menu.items.map(\.title).contains("Add sound files…"))
        let mac = try XCTUnwrap(menu.items.first { $0.title == "Mac sounds" }?.submenu)
        let line = try XCTUnwrap(mac.items.first { ($0.representedObject as? String) == AlertSound.systemAlertName })
        let row = try XCTUnwrap(line.view as? StayOpenRow)
        XCTAssertEqual(row.currentDetail, AlertBeepCount.stored(for: .systemAlert).label, "the count sits beside the name")
    }

    func testEveryOwnSoundCanBeRemovedOnItsOwn() throws {
        let sound = AlertSound(name: AlertSound.customPrefix + "x.wav")
        let saved = CustomSoundLibrary.folder
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("tbpk-menu-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data().write(to: folder.appendingPathComponent("x.wav"))
        CustomSoundLibrary.folder = folder
        defer { CustomSoundLibrary.folder = saved; try? FileManager.default.removeItem(at: folder) }
        let menu = try submenu(SoundMenu.item(target: target), titled: "Alert sound")
        let removal = try XCTUnwrap(menu.items.first { $0.title == "Remove one of my sounds" }?.submenu)
        XCTAssertEqual(removal.items.compactMap { $0.representedObject as? String }, [sound.name])
    }

    func testOftenUsedChoicesSitAboveTheDateAndTimeItemAndAreAtMostThree() throws {
        let saved = UserDefaults.standard.object(forKey: EndDateFavorites.storageKey)
        defer { UserDefaults.standard.set(saved, forKey: EndDateFavorites.storageKey) }
        UserDefaults.standard.removeObject(forKey: EndDateFavorites.storageKey)
        let quiet = StatusMenuBuilder.build(power: PowerManager.shared, watch: UnattendedWatch(power: PowerManager.shared), target: target)
        XCTAssertFalse(try XCTUnwrap(quiet.items.first { $0.title == "Stay awake for" }?.submenu).items.contains { $0.title == "OFTEN USED" || ($0.attributedTitle?.string == "OFTEN USED") })
        for minutes in [180, 90, 150, 45] { EndDateFavorites.record(.duration(minutes: minutes)) }
        let menu = StatusMenuBuilder.build(power: PowerManager.shared, watch: UnattendedWatch(power: PowerManager.shared), target: target)
        let items = try XCTUnwrap(menu.items.first { $0.title == "Stay awake for" }?.submenu).items
        let titles = items.map { $0.attributedTitle?.string ?? $0.title }
        let header = try XCTUnwrap(titles.firstIndex(of: "OFTEN USED"))
        let dateItem = try XCTUnwrap(titles.firstIndex { $0.hasPrefix("At a date and time") })
        XCTAssertLessThan(header, dateItem)
        XCTAssertEqual(items.filter { ($0.representedObject as? String)?.hasPrefix("d:") == true }.count, 3)
        XCTAssertTrue(titles.contains("Clear often used"))
        XCTAssertFalse(quiet.items.isEmpty)
    }

    func testThePercentLabelIsFoundFromTheSliderRowAndReadsTheLevel() throws {
        let menu = try submenu(SoundMenu.item(target: target), titled: "Alert sound")
        let volume = try XCTUnwrap(menu.items.first { $0.title == "Alert volume" })
        let row = try XCTUnwrap(volume.view)
        let label = try XCTUnwrap(row.viewWithTag(SoundMenu.percentTag) as? NSTextField)
        XCTAssertEqual(label.stringValue, SoundMenu.percentText(AlertVolumeLift.storedLevel))
        XCTAssertEqual(SoundMenu.percentText(0.2), "20%")
        XCTAssertEqual(SoundMenu.percentText(1), "100%")
    }

    func testPowerRulesOfferEveryLimitAndTheScreenSwitch() throws {
        let titles = try submenu(PowerRulesMenu.item(target: target), titled: "Power rules").items.map(\.title)
        XCTAssertTrue(titles.contains("Look present at the screen"))
        for limit in PowerLimit.allCases { XCTAssertTrue(titles.contains(limit.label), limit.label) }
        XCTAssertTrue(titles.contains("Turn the screen off when locked or closed"))
        XCTAssertTrue(titles.contains("Keep the screen on while awake"))
    }

    func testShowMeWhereTagsEachStepOfThePathAndNothingElse() throws {
        let menu = NSMenu()
        menu.addItem(PowerRulesMenu.item(target: target))
        menu.addItem(SettingsMenu.item(target: target))
        MenuHighlight.path = MenuHighlight.steps(of: "Power rules > Screen > Look present at the screen")
        defer { MenuHighlight.path = [] }
        MenuHighlight.apply(to: menu)
        let rules = try XCTUnwrap(menu.items.first { $0.title == "Power rules" })
        let leaf = try XCTUnwrap(rules.submenu?.items.first { $0.title == "Look present at the screen" })
        let header = try XCTUnwrap(rules.submenu?.items.first { !$0.isEnabled && $0.attributedTitle?.string == "SCREEN" })
        XCTAssertEqual(UpdateMenu.badgeText(of: rules), MenuHighlight.onTheWayLabel, "a step on the way says Open")
        XCTAssertEqual(UpdateMenu.badgeText(of: leaf), MenuHighlight.hereLabel, "the item to find says Here, never New")
        XCTAssertTrue(UpdateMenu.isTagged(leaf, as: MenuHighlight.hereLabel))
        XCTAssertFalse(UpdateMenu.isTagged(rules, as: MenuHighlight.hereLabel))
        XCTAssertFalse(UpdateMenu.isTagged(header, as: MenuHighlight.hereLabel))
        XCTAssertFalse(UpdateMenu.isTagged(try XCTUnwrap(menu.items.first { $0.title == "Settings" }), as: MenuHighlight.hereLabel))
    }

    func testShowMeWhereAddsACardWithTheWholeRouteOnTop() throws {
        let menu = NSMenu()
        menu.addItem(PowerRulesMenu.item(target: target))
        let steps = MenuHighlight.steps(of: "Power rules > Screen > Look present at the screen")
        MenuHighlight.path = steps
        defer { MenuHighlight.path = [] }
        MenuHighlight.apply(to: menu)
        XCTAssertNotNil(menu.items[0].view, "the guide card is the first row")
        XCTAssertTrue(menu.items[1].isSeparatorItem)
        XCTAssertEqual(MenuGuideRow.title(path: steps).string, "Look here\nPower rules  \u{203A}  Screen  \u{203A}  Look present at the screen")
        let rules = try XCTUnwrap(menu.items.first { $0.title == "Power rules" })
        let header = try XCTUnwrap(rules.submenu?.items.first { $0.attributedTitle?.string == "SCREEN" })
        let colour = header.attributedTitle?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertEqual(colour, MenuHighlight.wayColor, "the section on the way takes the way colour")
        MenuHighlight.path = []
        let plain = NSMenu()
        plain.addItem(PowerRulesMenu.item(target: target))
        MenuHighlight.apply(to: plain)
        XCTAssertEqual(plain.items.count, 1, "nothing is added when nothing is pointed at")
    }

    func testTheGuideCardWalksTheRouteOneStepAtATimeAndThenLightsAllOfIt() {
        let steps = MenuHighlight.steps(of: "Power rules > Screen > Look present at the screen")
        XCTAssertEqual((0...6).map { MenuGuideRow.activeStep(tick: $0, count: steps.count) }, [0, 1, 2, nil, 0, 1, 2])
        XCTAssertNil(MenuGuideRow.activeStep(tick: 5, count: 0), "an empty route has no step to light")
        XCTAssertEqual(MenuGuideRow.title(path: steps, active: 1).string,
                       "Step 2 of 3\nPower rules  \u{203A}  Screen  \u{203A}  Look present at the screen")
        let colours = (0..<3).map { step in
            MenuGuideRow.title(path: steps, active: 0).attribute(.foregroundColor, at: stepStart(step, in: steps), effectiveRange: nil) as? NSColor
        }
        XCTAssertEqual(colours, [MenuHighlight.wayColor, .tertiaryLabelColor, .tertiaryLabelColor], "the steps ahead wait in grey")
    }

    func testNoTagInTheMenuUsesTheWordNew() throws {
        let menu = NSMenu()
        menu.addItem(PowerRulesMenu.item(target: target))
        MenuHighlight.path = MenuHighlight.steps(of: "Power rules > Screen > Look present at the screen")
        defer { MenuHighlight.path = [] }
        MenuHighlight.apply(to: menu)
        let badges = (menu.items + (menu.items.compactMap(\.submenu?.items).flatMap { $0 })).compactMap { UpdateMenu.badgeText(of: $0) }
        XCTAssertEqual(badges, [MenuHighlight.onTheWayLabel, MenuHighlight.hereLabel])
        XCTAssertFalse(badges.contains("New"))
    }

    private func stepStart(_ step: Int, in steps: [String]) -> Int {
        let heading = "Step 1 of \(steps.count)\n".count
        return heading + steps.prefix(step).reduce(0) { $0 + $1.count + "  \u{203A}  ".count }
    }

    func testSettingsHoldTheSwitchesTheEnergyChoiceAndNoQuitChoice() throws {
        let titles = try submenu(SettingsMenu.item(target: target), titled: "Settings").items.map(\.title)
        XCTAssertEqual(titles, ["Show countdown", "Show animation", "Leaf colour", "Energy use", "Start at Login", "Updates"])
    }

    func testAWaitingUpdateIsTaggedNewAndNothingElseIs() throws {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: UpdateStore.availableKey)
        defer { defaults.set(saved, forKey: UpdateStore.availableKey) }
        defaults.removeObject(forKey: UpdateStore.availableKey)
        let plain = try XCTUnwrap(UpdateMenu.item(coordinator: .shared, target: target))
        XCTAssertFalse(UpdateMenu.isTagged(plain))
        XCTAssertEqual(plain.title, "Check for updates…")
        defaults.set("99.0.0", forKey: UpdateStore.availableKey)
        let waiting = try XCTUnwrap(UpdateMenu.item(coordinator: .shared, target: target))
        XCTAssertTrue(UpdateMenu.isTagged(waiting))
        XCTAssertTrue(waiting.title.contains("99.0.0"))
        XCTAssertNotNil(waiting.image, "the blue icon stays beside the tag")
    }

    func testTheUpdateSettingsAreTheThreeSwitchesOfMacOSAndTheLaterOnesWaitForTheEarlier() throws {
        let saved = UserDefaults.standard.object(forKey: UpdateStore.checkAutomaticallyKey)
        defer { UserDefaults.standard.set(saved, forKey: UpdateStore.checkAutomaticallyKey) }
        UserDefaults.standard.set(false, forKey: UpdateStore.checkAutomaticallyKey)
        let updates = try XCTUnwrap(try submenu(SettingsMenu.item(target: target), titled: "Settings").items.first { $0.title == "Updates" }?.submenu)
        let switches = updates.items.filter { $0.representedObject is String }
        XCTAssertEqual(switches.map(\.title), ["Check for updates automatically", "Download new updates when available", "Install updates automatically"])
        XCTAssertEqual(switches.map(\.isEnabled), [true, false, false])
        XCTAssertEqual(SettingsMenu.summary(checks: false, downloads: false, installs: false), "Off")
        XCTAssertEqual(SettingsMenu.summary(checks: true, downloads: true, installs: false), "Download, then ask")
    }

    func testTheTopLevelMenuHasEverySectionInOrder() {
        let menu = StatusMenuBuilder.build(
            power: PowerManager.shared, watch: UnattendedWatch(power: PowerManager.shared), target: target)
        let titles = menu.items.map(\.title).filter { !$0.isEmpty }
        XCTAssertEqual(titles.suffix(5), ["How to use", "What\u{2019}s new", "About Thai Baan Palang Bai Khrap", "Check for updates…", "Quit"])
        XCTAssertTrue(titles.contains("Stay awake for"))
        XCTAssertTrue(titles.contains(UnattendedWatch.isAvailable ? "Alerts" : "Alert sound"))
        XCTAssertTrue(titles.contains("Power rules"))
        XCTAssertTrue(titles.contains("Settings"))
        XCTAssertNotNil(menu.items.first?.view, "the header is a custom view")
    }

    func testTheHeaderSaysWhatState() {
        let power = PowerManager.shared
        let content = MenuHeader.content(power: power, alerting: false)
        XCTAssertEqual(content.title, power.isSleepDisabled ? "Staying awake" : "Normal sleep")
        XCTAssertEqual(MenuHeader.content(power: power, alerting: true).detail == "Left running on battery.", power.isSleepDisabled)
    }

    func testAWayThatEndsAtTheEndDateItemTipsTheMinutesRowOnce() {
        MenuHighlight.begin("Stay awake for > At a date and time…")
        XCTAssertTrue(MenuHighlight.endDateTip)
        MenuHighlight.begin("Settings > Leaf colour")
        XCTAssertFalse(MenuHighlight.endDateTip)
        MenuHighlight.path = []
    }
}
