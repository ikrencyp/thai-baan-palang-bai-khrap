import AppKit

@MainActor
enum PowerRulesMenu {
    static func item(target: StatusMenuTarget) -> NSMenuItem {
        let submenu = NSMenu()
        submenu.addItem(MenuParts.sectionHeader("Go back to normal sleep when"))
        for limit in PowerLimit.allCases {
            submenu.addItem(MenuParts.radio(limit.label, limit.rawValue, limit == PowerLimit.stored,
                                            #selector(StatusMenuTarget.powerLimitClicked(_:)), target))
        }
        submenu.addItem(.separator())
        submenu.addItem(MenuParts.sectionHeader("Save power"))
        let saver = MenuParts.action("Low Power Mode while on battery", symbol: nil,
                                     #selector(StatusMenuTarget.batterySaverClicked), target)
        saver.state = BatterySaver.isEnabled ? .on : .off
        submenu.addItem(saver)
        submenu.addItem(.separator())
        submenu.addItem(EnergyMenu.item(target: target))
        return MenuParts.parent("Power rules", symbol: "battery.75", subtitle: subtitle(), submenu: submenu)
    }

    static func subtitle() -> String {
        let limit = PowerLimit.stored
        let base = limit == .none ? "No battery limit" : limit.label
        return BatterySaver.isEnabled ? base + ", low power on battery" : base
    }
}
