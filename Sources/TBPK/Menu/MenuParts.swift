import AppKit

@MainActor
enum MenuParts {
    static func radio(
        _ title: String,
        _ value: Any,
        _ isOn: Bool,
        _ action: Selector,
        _ target: StatusMenuTarget
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = target
        item.representedObject = value
        item.state = isOn ? .on : .off
        return item
    }

    static func action(_ title: String, symbol: String?, _ selector: Selector, _ target: StatusMenuTarget) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = target
        if let symbol { item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
        return item
    }

    static func parent(_ title: String, symbol: String, subtitle: String?, submenu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        item.submenu = submenu
        if let subtitle { setSubtitle(subtitle, on: item) }
        return item
    }

    static func sectionHeader(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.attributedTitle = NSAttributedString(string: title.uppercased(), attributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor,
        ])
        return item
    }

    static func info(_ text: String) -> NSMenuItem {
        let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    static func setSubtitle(_ text: String, on item: NSMenuItem) {
        if #available(macOS 14.4, *) { item.subtitle = text }
    }

    static func label(_ text: String, frame: NSRect) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.frame = frame
        field.font = .menuFont(ofSize: 0)
        field.lineBreakMode = .byTruncatingTail
        field.isBezeled = false
        field.isEditable = false
        field.drawsBackground = false
        return field
    }
}
