import AppKit

// What\u{2019}s new "Show me where" opens the menu with a tag on every step of the path: Open on the ones to open
// next, Here on the last one. The word New is never used; the route says where the feature lives.
@MainActor
enum MenuHighlight {
    static var path: [String] = []
    // Set when the way ends at "At a date and time…": the window that opens there marks the new minutes row with Here.
    static var endDateTip = false
    static let onTheWayLabel = "Open"
    static let hereLabel = "Here"
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
                let isLast = step == path.count - 1
                UpdateMenu.tag(item, label: isLast ? hereLabel : onTheWayLabel, emphasized: true,
                               color: isLast ? hereColor : wayColor)
            } else if !item.isEnabled, let step = path.firstIndex(where: { $0.uppercased() == item.attributedTitle?.string }) {
                // A section heading on the way ("Screen") is not clickable: it only takes the colour.
                item.attributedTitle = NSAttributedString(string: item.title.uppercased(), attributes: [
                    .font: NSFont.systemFont(ofSize: 10, weight: .bold),
                    .foregroundColor: step == path.count - 1 ? hereColor : wayColor,
                ])
            }
            if let submenu = item.submenu { mark(submenu) }
        }
    }

    // "Power rules > Screen > Look present at the screen" -> the three names.
    static func steps(of findIt: String) -> [String] {
        findIt.components(separatedBy: " > ").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    static func begin(_ findIt: String) {
        path = steps(of: findIt)
        endDateTip = path.last == SleepDuration.untilDate.label
    }
}
