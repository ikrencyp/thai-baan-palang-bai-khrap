import AppKit

// One menu for the whole alert: when it fires (lid and lock, how often, which power source) and what it sounds like.
@MainActor
enum AlertsMenu {
    static func item(power: PowerManager, watch: UnattendedWatch, target: StatusMenuTarget) -> NSMenuItem {
        let submenu = NSMenu()
        let reading = UnattendedSnapshot.read(buzzing: power.isSleepDisabled)
        submenu.addItem(MenuParts.info("Now: \(reading.summary)"))
        if let event = watch.lastEvent { submenu.addItem(MenuParts.info(event.menuText)) }

        submenu.addItem(.separator())
        submenu.addItem(MenuParts.sectionHeader("How often (first alert within \(UnattendedDecision.holdTime) seconds)"))
        for mode in LidWarningMode.allCases {
            submenu.addItem(MenuParts.radio(mode.label, mode.rawValue, mode == LidWarningMode.stored,
                                            #selector(StatusMenuTarget.batteryWarningClicked(_:)), target))
        }

        submenu.addItem(.separator())
        submenu.addItem(MenuParts.sectionHeader("Warn when the Mac is closed or locked"))
        for condition in PowerCondition.allCases {
            submenu.addItem(MenuParts.radio(condition.label, condition.rawValue, condition == PowerCondition.stored,
                                            #selector(StatusMenuTarget.warningPowerClicked(_:)), target))
        }

        submenu.addItem(.separator())
        submenu.addItem(MenuParts.sectionHeader("What it sounds like"))
        let group = SoundMenuRefresher()
        SoundMenu.rows(target: target, group: group).forEach(submenu.addItem)

        let parent = MenuParts.parent("Alerts", symbol: "bell.badge", subtitle: subtitle(), submenu: submenu)
        group.add { MenuParts.setSubtitle(subtitle(), on: parent) }
        return parent
    }

    // When it fires, then the sound that goes with it. Off says only that: a sound with no alert is not news.
    static func subtitle() -> String {
        let mode = LidWarningMode.stored
        guard mode != .off else { return "Off" }
        return "\(mode.label), \(PowerCondition.stored.label.lowercased()) · \(AlertSound.stored.displayName)"
    }
}
