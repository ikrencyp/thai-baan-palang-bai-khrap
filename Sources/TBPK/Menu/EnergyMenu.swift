import AppKit

@MainActor
enum EnergyMenu {
    static func item(target: StatusMenuTarget) -> NSMenuItem {
        item(target: target, charger: .stored(.charger), battery: .stored(.battery), separate: EnergyProfile.isSeparate(),
             plan: EnergyMonitor.shared.plan, conditions: EnergyMonitor.conditions())
    }

    static func item(target: StatusMenuTarget, charger: EnergyProfile, battery: EnergyProfile, separate: Bool,
                     plan: EnergyPlan, conditions: EnergyPlan.Conditions) -> NSMenuItem {
        let active = separate && conditions.onBattery ? battery : charger
        let submenu = NSMenu()
        if separate {
            submenu.addItem(slotMenu("On the charger", symbol: "bolt.fill", slot: .charger, stored: charger,
                                     isNow: !conditions.onBattery, target: target))
            submenu.addItem(slotMenu("On battery", symbol: "battery.75", slot: .battery, stored: battery,
                                     isNow: conditions.onBattery, target: target))
        } else {
            choices(.charger, stored: charger, in: submenu, target: target)
            if #unavailable(macOS 14.4) { submenu.addItem(MenuParts.info(charger.detail)) }
        }
        submenu.addItem(.separator())
        let toggle = MenuParts.action("Set charger and battery separately", symbol: nil,
                                      #selector(StatusMenuTarget.energySeparateClicked(_:)), target)
        toggle.state = separate ? .on : .off
        submenu.addItem(toggle)
        submenu.addItem(MenuParts.info(status(active, plan, conditions)))
        let subtitle = separate ? "Charger \(charger.title), battery \(battery.title)"
                                : "\(charger.title), \(plan.summary.lowercased())"
        return MenuParts.parent("Energy use", symbol: "bolt", subtitle: subtitle, submenu: submenu)
    }

    private static func slotMenu(_ title: String, symbol: String, slot: EnergyProfile.Slot, stored: EnergyProfile,
                                 isNow: Bool, target: StatusMenuTarget) -> NSMenuItem {
        let submenu = NSMenu()
        choices(slot, stored: stored, in: submenu, target: target)
        return MenuParts.parent(title, symbol: symbol, subtitle: isNow ? "\(stored.title), in use now" : stored.title,
                                submenu: submenu)
    }

    private static func choices(_ slot: EnergyProfile.Slot, stored: EnergyProfile, in menu: NSMenu, target: StatusMenuTarget) {
        for profile in EnergyProfile.allCases {
            let item = MenuParts.radio(profile.title, EnergyProfile.Pick(slot: slot, profile: profile), profile == stored,
                                       #selector(StatusMenuTarget.energyProfileClicked(_:)), target)
            MenuParts.setSubtitle(profile.detail, on: item)
            menu.addItem(item)
        }
    }

    // What is happening now and, for Automatic, why: the person can see the setting do its job.
    static func status(_ profile: EnergyProfile, _ plan: EnergyPlan, _ conditions: EnergyPlan.Conditions) -> String {
        let now = "Right now: \(plan.summary.lowercased())"
        guard profile == .automatic, plan.isVisible else { return now }
        return "\(now) (\(conditions.reason))"
    }
}

extension EnergyPlan.Conditions {
    var reason: String {
        if reduceMotion { return "Reduce Motion is on" }
        if lowPowerMode { return "Low Power Mode is on" }
        return onBattery ? "on battery" : "on the charger"
    }
}
