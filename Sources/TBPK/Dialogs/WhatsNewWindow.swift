import AppKit

@MainActor
enum WhatsNewWindow {
    static let lastVersionKey = "lastLaunchedVersion"

    static func show(showMenu: @escaping (String) -> Void = { _ in }) {
        let releases = ReleaseNotes.bundledText().map(ReleaseNotes.all(in:)) ?? []
        InfoWindow.show(id: "whatsnew", title: "What's new", size: WhatsNewView.size) {
            WhatsNewView(releases: releases, current: AppInfo.version, showMenu: showMenu)
        }
    }

    enum Launch: Equatable { case firstInstall, updated, same }

    // Records this launch and says what kind it is: a first install has no earlier version.
    static func launch(current: String, in defaults: UserDefaults = .standard) -> Launch {
        let last = defaults.string(forKey: lastVersionKey)
        defaults.set(current, forKey: lastVersionKey)
        guard let last else { return .firstInstall }
        return last == current ? .same : .updated
    }

    // After an update the list opens once. A first install opens How to use instead.
    static func shouldShowAtLaunch(current: String, in defaults: UserDefaults = .standard) -> Bool {
        launch(current: current, in: defaults) == .updated
    }
}
