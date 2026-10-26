import AppKit

@MainActor
enum LeafColorMenu {
    static func item(target: StatusMenuTarget) -> NSMenuItem {
        item(target: target, charger: .stored(.charger), battery: .stored(.battery))
    }

    static func item(target: StatusMenuTarget, charger: LeafColor, battery: LeafColor) -> NSMenuItem {
        let submenu = NSMenu()
        submenu.addItem(MenuParts.parent("On the charger", symbol: "bolt.fill", subtitle: charger.name,
                                         submenu: palette(.charger, stored: charger, target: target)))
        submenu.addItem(MenuParts.parent("On battery", symbol: "battery.75", subtitle: battery.name,
                                         submenu: palette(.battery, stored: battery, target: target)))
        submenu.addItem(.separator())
        submenu.addItem(MenuParts.info("Both show while Keep awake is on. An alert shows the battery colour."))
        return MenuParts.parent("Leaf colour", symbol: "paintpalette", subtitle: "\(charger.name) / \(battery.name)",
                                submenu: submenu)
    }

    private static func palette(_ slot: LeafColor.Slot, stored: LeafColor, target: StatusMenuTarget) -> NSMenu {
        let submenu = NSMenu()
        for choice in LeafColor.choices {
            let row = MenuParts.radio(choice.name, LeafColor.Pick(slot: slot, color: choice.color), choice.color == stored,
                                      #selector(StatusMenuTarget.leafColorClicked(_:)), target)
            row.image = swatch(choice.color)
            submenu.addItem(row)
        }
        submenu.addItem(.separator())
        let custom = MenuParts.action(stored.isCustom ? "Custom \(stored.hex)..." : "Custom colour...", symbol: nil,
                                      #selector(StatusMenuTarget.customLeafColorClicked(_:)), target)
        custom.representedObject = slot
        custom.state = stored.isCustom ? .on : .off
        if stored.isCustom { custom.image = swatch(stored) }
        submenu.addItem(custom)
        return submenu
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
