import AppKit

@MainActor
enum UpdateMenu {
    static func item(coordinator: UpdateCoordinator, target: StatusMenuTarget) -> NSMenuItem? {
        guard UpdateStore.isOfferedHere() || coordinator.pending != nil else { return nil }
        let selector = #selector(StatusMenuTarget.updateClicked)
        switch coordinator.phase {
        case .checking:
            return disabled(MenuParts.action("Checking for updates…", symbol: "arrow.triangle.2.circlepath", selector, target))
        case .downloading:
            return disabled(MenuParts.action("Downloading the update…", symbol: "arrow.down.circle", selector, target))
        case .idle:
            if let version = coordinator.pending {
                let ready = UpdateStore.downloadedRoot(for: version) != nil
                let item = MenuParts.action(ready ? "Update to \(version.text) now…" : "Download and update to \(version.text)…",
                                            symbol: ready ? "arrow.clockwise.circle.fill" : "arrow.down.circle.fill", selector, target)
                item.image = item.image?.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [.systemBlue]))
                tag(item)
                return withStatus(item)
            }
            return withStatus(MenuParts.action("Check for updates…", symbol: "arrow.triangle.2.circlepath", selector, target))
        }
    }

    nonisolated static let updateLabel = "Update"

    // A tag at the end of the line, so the item that installs the update is the one that stands out.
    // macOS 14 draws it as a native badge; macOS 13 gets the same word in blue after the title.
    static func tag(_ item: NSMenuItem) {
        if #available(macOS 14.0, *) {
            item.badge = NSMenuItemBadge(string: updateLabel)
        } else {
            let text = NSMutableAttributedString(string: item.title)
            text.append(NSAttributedString(string: "  \(updateLabel)", attributes: [
                .foregroundColor: NSColor.systemBlue, .font: NSFont.menuFont(ofSize: 0),
            ]))
            item.attributedTitle = text
        }
    }

    static func emphasizedTitle(_ title: String, color: NSColor) -> NSAttributedString {
        let bold = NSFontManager.shared.convert(NSFont.menuFont(ofSize: 0), toHaveTrait: .boldFontMask)
        return NSAttributedString(string: title, attributes: [.font: bold, .foregroundColor: color])
    }

    static func badgeText(of item: NSMenuItem) -> String? {
        if #available(macOS 14.0, *) { return item.badge?.stringValue }
        return nil
    }

    static func isTagged(_ item: NSMenuItem) -> Bool {
        if #available(macOS 14.0, *) { return badgeText(of: item) == updateLabel }
        return item.attributedTitle?.string.hasSuffix(updateLabel) == true
    }

    private static func withStatus(_ item: NSMenuItem) -> NSMenuItem {
        if let current = AppVersion(AppInfo.version), let line = UpdateStore.statusLine(current: current) {
            MenuParts.setSubtitle(line, on: item)
        }
        return item
    }

    private static func disabled(_ item: NSMenuItem) -> NSMenuItem {
        item.isEnabled = false
        return item
    }
}
