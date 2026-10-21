import AppKit

@MainActor
enum WhatsNewWindow {
    static let lastVersionKey = "lastLaunchedVersion"

    static func show() {
        let releases = ReleaseNotes.bundledText().map(ReleaseNotes.all(in:)) ?? []
        InfoWindow.show(id: "whatsnew", title: "What's new", size: NSSize(width: 440, height: 480)) {
            WhatsNewView(releases: releases, current: AppInfo.version)
        }
    }

    // After an update the list opens once. A first install has no earlier version, so it stays quiet.
    static func shouldShowAtLaunch(current: String, in defaults: UserDefaults = .standard) -> Bool {
        let last = defaults.string(forKey: lastVersionKey)
        defaults.set(current, forKey: lastVersionKey)
        return last != nil && last != current
    }
}
