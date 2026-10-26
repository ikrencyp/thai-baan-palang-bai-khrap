import AppKit

// What's new "Show me where" opens the menu with a tag on every step of the path to the new item.
@MainActor
enum MenuHighlight {
    static var path: [String] = []
    static let onTheWayLabel = "Open"

    static func apply(to menu: NSMenu) {
        guard !path.isEmpty else { return }
        for item in menu.items {
            if item.isEnabled, let step = path.firstIndex(of: item.title) {
                // The last step is the new thing; the ones before it only say where to open next.
                UpdateMenu.markAsNew(item, label: step == path.count - 1 ? UpdateMenu.newLabel : onTheWayLabel, emphasized: true)
            }
            if let submenu = item.submenu { apply(to: submenu) }
        }
    }

    // "Power rules > Screen > Look present at the screen" -> the three names.
    static func steps(of findIt: String) -> [String] {
        findIt.components(separatedBy: " > ").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
