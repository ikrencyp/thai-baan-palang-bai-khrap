import AppKit

// Look present has its own menu, one step from the top, with every choice open in one list: the switch, how the moves
// are spaced, and the breaks. The line under its name says why it is or is not doing anything right now.
@MainActor
enum LookPresentMenu {
    // What would make it start, offered as a row in the menu, so a switch that is on but waiting is one click from working.
    enum Fix: Equatable {
        case keepAwake
        case keepScreenOn
    }

    struct Status: Equatable {
        let subtitle: String
        let fix: Fix?
    }

    nonisolated static func status(on: Bool, hasAccess: Bool, needsRestart: Bool, awake: Bool, screenHeld: Bool,
                                   motion: PresenceMotion) -> Status {
        guard on else { return Status(subtitle: "Off", fix: nil) }
        if needsRestart { return Status(subtitle: "Restart to apply Accessibility", fix: nil) }
        if !hasAccess { return Status(subtitle: "Needs Accessibility", fix: nil) }
        if !awake { return Status(subtitle: "Waiting for Keep awake", fix: .keepAwake) }
        if !screenHeld { return Status(subtitle: "Needs the screen kept on", fix: .keepScreenOn) }
        return Status(subtitle: motion.shortLabel, fix: nil)
    }

    static func item(power: PowerManager, target: StatusMenuTarget) -> NSMenuItem {
        let on = StatusPreferences.lookPresent
        let needsRestart = on && ScreenPresence.needsRestartForAccess
        let needsAccess = on && !ScreenPresence.hasAccess
        let motion = PresenceMotion.stored
        let rhythm = PresenceRhythm.stored
        let status = status(on: on, hasAccess: ScreenPresence.hasAccess, needsRestart: needsRestart,
                            awake: power.isSleepDisabled, screenHeld: StatusPreferences.keepScreenOn, motion: motion)
        let submenu = NSMenu()
        submenu.addItem(MenuParts.toggle("Look present at the screen", on: on,
                                         #selector(StatusMenuTarget.lookPresentClicked), target))
        submenu.addItem(.separator())
        submenu.addItem(MenuParts.sectionHeader("Movement"))
        for choice in PresenceMotion.allCases {
            submenu.addItem(MenuParts.radio(choice.label, choice.rawValue, choice == motion,
                                            #selector(StatusMenuTarget.presenceMotionClicked(_:)), target))
        }
        submenu.addItem(.separator())
        submenu.addItem(MenuParts.sectionHeader("Breaks"))
        for choice in PresenceRhythm.allCases {
            submenu.addItem(MenuParts.radio(choice.label, choice.rawValue, choice == rhythm,
                                            #selector(StatusMenuTarget.presenceRhythmClicked(_:)), target))
        }
        if needsRestart {
            submenu.addItem(.separator())
            submenu.addItem(MenuParts.action("Restart to apply Accessibility…", symbol: "arrow.clockwise",
                                             #selector(StatusMenuTarget.fixLookPresentAccessClicked), target))
        } else if needsAccess {
            submenu.addItem(.separator())
            submenu.addItem(MenuParts.action("Fix Accessibility permission…", symbol: "hand.raised",
                                             #selector(StatusMenuTarget.fixLookPresentAccessClicked), target))
        } else if let fix = status.fix {
            submenu.addItem(.separator())
            submenu.addItem(fixRow(fix, power: power, target: target))
        }
        return MenuParts.parent("Look present", symbol: "display", subtitle: status.subtitle, submenu: submenu)
    }

    private static func fixRow(_ fix: Fix, power: PowerManager, target: StatusMenuTarget) -> NSMenuItem {
        switch fix {
        case .keepAwake:
            let row = MenuParts.action("Turn on Keep this Mac awake", symbol: "power",
                                       #selector(StatusMenuTarget.enableClicked), target)
            row.isEnabled = !power.isWorking
            return row
        case .keepScreenOn:
            return MenuParts.action("Turn on Keep the screen on while awake", symbol: "display",
                                    #selector(StatusMenuTarget.keepScreenClicked), target)
        }
    }
}
