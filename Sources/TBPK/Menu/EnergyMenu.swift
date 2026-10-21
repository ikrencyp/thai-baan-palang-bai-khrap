import AppKit

@MainActor
enum EnergyMenu {
    static func item(target: StatusMenuTarget) -> NSMenuItem {
        item(target: target, stored: .stored(), plan: EnergyMonitor.shared.plan, conditions: EnergyMonitor.conditions())
    }

    static func item(target: StatusMenuTarget, stored: EnergyProfile, plan: EnergyPlan, conditions: EnergyPlan.Conditions) -> NSMenuItem {
        let submenu = NSMenu()
        for profile in EnergyProfile.allCases {
            let item = MenuParts.radio(profile.title, profile.rawValue, profile == stored,
                                       #selector(StatusMenuTarget.energyProfileClicked(_:)), target)
            MenuParts.setSubtitle(profile.detail, on: item)
            submenu.addItem(item)
        }
        submenu.addItem(.separator())
        if #unavailable(macOS 14.4) { submenu.addItem(MenuParts.info(stored.detail)) }
        submenu.addItem(MenuParts.info(status(stored, plan, conditions)))
        return MenuParts.parent("Energy use", symbol: "bolt", subtitle: "\(stored.title), \(plan.summary.lowercased())", submenu: submenu)
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
