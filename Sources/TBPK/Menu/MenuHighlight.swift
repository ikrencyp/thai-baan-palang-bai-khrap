import AppKit

// What's new "Show me where" opens the menu with a tag on every step of the path to the new item.
@MainActor
enum MenuHighlight {
    static var path: [String] = []
    static let onTheWayLabel = "Open"
    // The steps on the way are blue, the new item at the end is orange, so the way reads at a glance.
    static let onTheWayColor = NSColor.systemBlue
    static let newColor = NSColor.systemOrange
    // Set when the way ends at "At a date and time…": the window that opens there marks the new minutes row.
    static var endDateTip = false

    static func apply(to menu: NSMenu) {
        guard !path.isEmpty else { return }
        for item in menu.items {
            if item.isEnabled, let step = path.firstIndex(of: item.title) {
                // The last step is the new thing; the ones before it only say where to open next.
                let isLast = step == path.count - 1
                UpdateMenu.markAsNew(item, label: isLast ? UpdateMenu.newLabel : onTheWayLabel, emphasized: true,
                                     tint: isLast ? newColor : onTheWayColor)
            }
            if let submenu = item.submenu { apply(to: submenu) }
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
