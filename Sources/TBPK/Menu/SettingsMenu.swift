import AppKit

@MainActor
enum SettingsMenu {
    // Look present has its own menu (LookPresentMenu); the two screen switches sit here, one step below Settings.
    static func item(target: StatusMenuTarget) -> NSMenuItem {
        let submenu = NSMenu()
        submenu.addItem(MenuParts.toggle("Show countdown", on: StatusPreferences.showCountdown,
                                         #selector(StatusMenuTarget.countdownClicked(_:)), target))
        submenu.addItem(MenuParts.toggle("Leaf motion", on: StatusPreferences.showAnimation,
                                         #selector(StatusMenuTarget.animationClicked(_:)), target))
        submenu.addItem(LeafColorMenu.item(target: target))
        submenu.addItem(MenuParts.toggle("Keep the screen on while awake", on: StatusPreferences.keepScreenOn,
                                         #selector(StatusMenuTarget.keepScreenClicked), target))
        submenu.addItem(MenuParts.toggle("Turn the screen off when locked or closed", on: StatusPreferences.darkenWhenClosed,
                                         #selector(StatusMenuTarget.darkenClicked), target))
        submenu.addItem(MenuParts.toggle("Start at Login", on: LoginItem.isEnabled,
                                         #selector(StatusMenuTarget.loginClicked), target))
        if UpdateStore.isOfferedHere() { submenu.addItem(updates(target: target)) }
        return MenuParts.parent("Settings", symbol: "gearshape", subtitle: nil, submenu: submenu)
    }

    // The same three switches as macOS Software Update: each one only counts while the one above it is on.
    private static func updates(target: StatusMenuTarget) -> NSMenuItem {
        let submenu = NSMenu()
        let checks = UpdateStore.checksAutomatically()
        let downloads = UpdateStore.downloadsAutomatically()
        let installs = UpdateStore.installsAutomatically()
        submenu.addItem(option("Check for updates automatically", key: UpdateStore.checkAutomaticallyKey, on: checks, enabled: true, target))
        submenu.addItem(option("Download new updates when available", key: UpdateStore.downloadAutomaticallyKey, on: downloads,
                               enabled: checks, target))
        submenu.addItem(option("Install updates automatically", key: UpdateStore.installAutomaticallyKey, on: installs,
                               enabled: downloads, target))
        submenu.addItem(.separator())
        submenu.addItem(MenuParts.info(hint(checks: checks, downloads: downloads, installs: installs)))
        return MenuParts.parent("Updates", symbol: "arrow.triangle.2.circlepath", subtitle: summary(checks: checks, downloads: downloads, installs: installs),
                                submenu: submenu)
    }

    private static func option(_ title: String, key: String, on: Bool, enabled: Bool, _ target: StatusMenuTarget) -> NSMenuItem {
        let item = MenuParts.action(title, symbol: nil, #selector(StatusMenuTarget.updateOptionClicked(_:)), target)
        item.representedObject = key
        item.state = on ? .on : .off
        item.isEnabled = enabled
        return item
    }

    static func summary(checks: Bool, downloads: Bool, installs: Bool) -> String {
        guard checks else { return "Off" }
        if installs { return "Install automatically" }
        return downloads ? "Download, then ask" : "Check only"
    }

    static func hint(checks: Bool, downloads: Bool, installs: Bool) -> String {
        guard checks else { return "Nothing runs on its own. Use Check for updates in the menu." }
        if installs { return "Looks every 6 hours, downloads, and installs while Keep awake is off." }
        return downloads ? "Looks every 6 hours and downloads. You press Update." : "Looks every 6 hours. You press Update."
    }
}
