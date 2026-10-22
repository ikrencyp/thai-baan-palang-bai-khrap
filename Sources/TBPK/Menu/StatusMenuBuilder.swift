import AppKit

@MainActor
enum StatusMenuBuilder {
    static func build(power: PowerManager, watch: UnattendedWatch, target: StatusMenuTarget) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(MenuHeader.item(MenuHeader.content(power: power, alerting: watch.isAlerting, onBattery: UnattendedSnapshot.isOnBattery)))
        menu.addItem(primaryAction(power: power, target: target))
        menu.addItem(durationItem(power: power, target: target))
        // A new version waits right under the main choices, where it is seen, not at the bottom.
        let update = UpdateMenu.item(coordinator: .shared, target: target)
        let updateReady = UpdateCoordinator.shared.pending != nil
        if updateReady { update.map(menu.addItem) }

        menu.addItem(.separator())
        // Without lid and lock detection only the battery rules can sound the alert, so the sound stands on its own.
        menu.addItem(UnattendedWatch.isAvailable
            ? AlertsMenu.item(power: power, watch: watch, target: target)
            : SoundMenu.item(target: target))
        menu.addItem(PowerRulesMenu.item(target: target))
        menu.addItem(SettingsMenu.item(target: target))

        menu.addItem(.separator())
        menu.addItem(MenuParts.action("How to use", symbol: "questionmark.circle",
                                      #selector(StatusMenuTarget.helpClicked), target))
        menu.addItem(MenuParts.action("What\u{2019}s new", symbol: "sparkles",
                                      #selector(StatusMenuTarget.whatsNewClicked), target))
        menu.addItem(MenuParts.action("About Thai Baan Palang Bai Khrap", symbol: "info.circle",
                                      #selector(StatusMenuTarget.aboutClicked), target))
        if !updateReady { update.map(menu.addItem) }
        let quit = MenuParts.action("Quit", symbol: nil, #selector(StatusMenuTarget.quitClicked), target)
        quit.keyEquivalent = "q"
        menu.addItem(quit)
        return menu
    }

    private static func primaryAction(power: PowerManager, target: StatusMenuTarget) -> NSMenuItem {
        let item: NSMenuItem
        if power.isSleepDisabled {
            item = MenuParts.action("Back to normal sleep", symbol: nil, #selector(StatusMenuTarget.disableClicked), target)
            item.image = LeafGlyph.image(fill: 0, scale: 1, alpha: 1, tint: nil)
        } else {
            item = MenuParts.action("Keep this Mac awake", symbol: nil, #selector(StatusMenuTarget.enableClicked), target)
            item.image = LeafGlyph.image(fill: 1, scale: 1, alpha: 1, tint: nil)
        }
        item.isEnabled = !power.isWorking
        return item
    }

    private static func durationItem(power: PowerManager, target: StatusMenuTarget) -> NSMenuItem {
        let submenu = NSMenu()
        for duration in SleepDuration.allCases {
            if duration == .untilDate {
                submenu.addItem(.separator())
                addOftenUsed(to: submenu, power: power, target: target)
            }
            let item = NSMenuItem(
                title: durationTitle(duration, power: power),
                action: #selector(StatusMenuTarget.durationClicked(_:)),
                keyEquivalent: ""
            )
            item.target = target
            item.representedObject = duration.rawValue
            if duration == SleepDuration.stored { item.state = .on }
            submenu.addItem(item)
        }
        return MenuParts.parent("Stay awake for", symbol: "clock",
                                subtitle: durationTitle(SleepDuration.stored, power: power), submenu: submenu)
    }

    // The few lengths and clock times chosen most in "At a date and time", one click each.
    private static func addOftenUsed(to menu: NSMenu, power: PowerManager, target: StatusMenuTarget) {
        let picks = EndDateFavorites.top()
        guard !picks.isEmpty else { return }
        menu.addItem(MenuParts.sectionHeader("Often used"))
        let now = Date()
        for pick in picks {
            let item = MenuParts.action(pick.label, symbol: nil, #selector(StatusMenuTarget.favoriteEndClicked(_:)), target)
            item.representedObject = pick.key
            item.isEnabled = !power.isWorking
            item.attributedTitle = titleWithEnd(pick, now: now)
            menu.addItem(item)
        }
        menu.addItem(MenuParts.action("Clear often used", symbol: "trash", #selector(StatusMenuTarget.clearFavoritesClicked), target))
        menu.addItem(.separator())
    }

    private static func titleWithEnd(_ pick: EndDatePick, now: Date) -> NSAttributedString {
        let text = NSMutableAttributedString(string: pick.label)
        text.append(NSAttributedString(string: "  \(EndDateText.describe(pick.moment(now: now), now: now))", attributes: [
            .foregroundColor: NSColor.secondaryLabelColor,
        ]))
        return text
    }

    private static func durationTitle(_ duration: SleepDuration, power: PowerManager) -> String {
        guard duration == .untilDate, SleepDuration.stored == .untilDate, let end = power.savedEndDate else {
            return duration.label
        }
        return "\(duration.label) (\(EndDateText.describe(end, now: Date())))"
    }
}
