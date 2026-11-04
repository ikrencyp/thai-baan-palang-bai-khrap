import AppKit

// What\u{2019}s new "Show me where" opens the menu with a numbered badge in the icon column of every step of the path
// (the same numbers the card on top and What\u{2019}s new use), the name in bold: orange for the ones to open next, green
// for the last one. The badge sits where every row's icon sits, so nothing is pushed to the edge beside the arrow.
@MainActor
enum MenuHighlight {
    static var path: [String] = []
    // Set when the way ends at "At a date and time…": the window that opens there marks the new minutes row with Here.
    static var endDateTip = false
    // Orange: open this one next. Green: this is the one to find.
    static let wayColor = NSColor.systemOrange
    static let hereColor = NSColor.systemGreen

    // The menu gets the whole route as a card on top, and every step along it, in the submenus too, in its colour.
    static func apply(to menu: NSMenu) {
        guard !path.isEmpty else { return }
        mark(menu)
        menu.insertItem(MenuGuideRow.item(path: path), at: 0)
        menu.insertItem(.separator(), at: 1)
    }

    private static func mark(_ menu: NSMenu) {
        for item in menu.items {
            if item.isEnabled, let step = path.firstIndex(of: item.title) {
                // The last step is the one to find; the ones before it only say where to open next.
                let color = step == path.count - 1 ? hereColor : wayColor
                item.image = badge(number: step + 1, color: color)
                item.attributedTitle = UpdateMenu.emphasizedTitle(item.title, color: color)
            }
            if let submenu = item.submenu { mark(submenu) }
        }
    }

    static func badge(number: Int, color: NSColor) -> NSImage {
        let side: CGFloat = 18
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5)).fill()
            let text = NSAttributedString(string: "\(number)", attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .bold), .foregroundColor: NSColor.white,
            ])
            let size = text.size()
            text.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2))
            return true
        }
        image.accessibilityDescription = "Step \(number)"
        return image
    }

    // "Settings > Screen > Look present at the screen" -> the three names.
    nonisolated static func steps(of findIt: String) -> [String] {
        findIt.components(separatedBy: " > ").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    static func begin(_ findIt: String) {
        path = steps(of: findIt)
        endDateTip = path.last == SleepDuration.untilDate.label
    }
}
