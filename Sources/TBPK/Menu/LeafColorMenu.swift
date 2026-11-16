import AppKit

@MainActor
enum LeafColorMenu {
    static func item(target: StatusMenuTarget) -> NSMenuItem {
        item(target: target, charger: .stored(.charger), battery: .stored(.battery))
    }

    // Both slots sit in one list under their own headers, so a colour is two steps from Settings, not three.
    static func item(target: StatusMenuTarget, charger: LeafColor, battery: LeafColor) -> NSMenuItem {
        let submenu = NSMenu()
        addPalette("On the charger", .charger, stored: charger, to: submenu, target: target)
        submenu.addItem(.separator())
        addPalette("On battery", .battery, stored: battery, to: submenu, target: target)
        submenu.addItem(.separator())
        submenu.addItem(MenuParts.info("Both show while Keep awake is on. An alert shows the battery colour."))
        return MenuParts.parent("Leaf colour", symbol: "paintpalette", subtitle: "\(charger.name) / \(battery.name)",
                                submenu: submenu)
    }

    private static func addPalette(_ header: String, _ slot: LeafColor.Slot, stored: LeafColor, to menu: NSMenu,
                                   target: StatusMenuTarget) {
        menu.addItem(MenuParts.sectionHeader(header))
        for choice in LeafColor.choices {
            let row = MenuParts.radio(choice.name, LeafColor.Pick(slot: slot, color: choice.color), choice.color == stored,
                                      #selector(StatusMenuTarget.leafColorClicked(_:)), target)
            row.image = swatch(choice.color)
            menu.addItem(row)
        }
        menu.addItem(.separator())
        let custom = MenuParts.action(stored.isCustom ? "Custom \(stored.hex)..." : "Custom colour...", symbol: nil,
                                      #selector(StatusMenuTarget.customLeafColorClicked(_:)), target)
        custom.representedObject = slot
        custom.state = stored.isCustom ? .on : .off
        if stored.isCustom { custom.image = swatch(stored) }
        menu.addItem(custom)
    }

    // A round dot of the colour with a thin edge, so white and pale colours stay visible on a light menu.
    static func swatch(_ color: LeafColor) -> NSImage {
        let image = NSImage(size: NSSize(width: 14, height: 14), flipped: false) { bounds in
            let dot = NSBezierPath(ovalIn: bounds.insetBy(dx: 1.5, dy: 1.5))
            color.nsColor.setFill()
            dot.fill()
            NSColor.labelColor.withAlphaComponent(0.3).setStroke()
            dot.lineWidth = 0.8
            dot.stroke()
            return true
        }
        image.isTemplate = false
        return image
    }
}
