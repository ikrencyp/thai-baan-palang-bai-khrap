import AppKit

// Asks for a colour code. A wrong code is explained and asked again, never silently ignored.
@MainActor
enum LeafColorPrompt {
    static func ask(current: LeafColor, title: String = "Leaf colour") -> LeafColor? {
        var note = "Type a colour code such as #FF8800 (or FF8800, or the short #F80)."
        while true {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = note
            alert.addButton(withTitle: "Use colour")
            alert.addButton(withTitle: "Cancel")
            let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
            field.stringValue = current.hex
            field.placeholderString = "#RRGGBB"
            alert.accessoryView = field
            alert.window.initialFirstResponder = field
            guard alert.runModal() == .alertFirstButtonReturn else { return nil }
            if let color = LeafColor(hex: field.stringValue) { return color }
            note = "\"\(field.stringValue)\" is not a colour code. Use 6 hex digits, like #2EDB6E."
        }
    }
}
