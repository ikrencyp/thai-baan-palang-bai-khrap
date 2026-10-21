import Foundation

enum UpdateStore {
    static let checkAutomaticallyKey = "updateCheckAutomatically"
    static let downloadAutomaticallyKey = "updateDownloadAutomatically"
    static let installAutomaticallyKey = "updateInstallAutomatically"
    static let lastCheckKey = "updateLastCheck"
    static let availableKey = "updateAvailableVersion"
    static let notesKey = "updateAvailableNotes"
    static let reachedKey = "updateRepositoryReached"
    static let failedKey = "updateRepositoryFailed"
    static let availableDMGKey = "updateAvailableDMG"
    static let availableChecksumKey = "updateAvailableChecksum"
    static let announcedKey = "updateAnnouncedVersion"
    static let downloadedVersionKey = "updateDownloadedVersion"
    static let downloadedPathKey = "updateDownloadedPath"
    static let checkInterval: TimeInterval = 6 * 3600

    // The three switches work like macOS Software Update: look for updates, download them, install them.
    // A switch only counts while the ones before it are on.
    static func checksAutomatically(in defaults: UserDefaults = .standard) -> Bool {
        storedFlag(checkAutomaticallyKey, in: defaults, fallback: true)
    }

    static func downloadsAutomatically(in defaults: UserDefaults = .standard) -> Bool {
        checksAutomatically(in: defaults) && storedFlag(downloadAutomaticallyKey, in: defaults, fallback: true)
    }

    static func installsAutomatically(in defaults: UserDefaults = .standard) -> Bool {
        downloadsAutomatically(in: defaults) && storedFlag(installAutomaticallyKey, in: defaults, fallback: false)
    }

    static func set(_ key: String, _ on: Bool, in defaults: UserDefaults = .standard) {
        defaults.set(on, forKey: key)
    }

    private static func storedFlag(_ key: String, in defaults: UserDefaults, fallback: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? fallback
    }

    // A Mac that never got an answer from the repository has nothing to offer: the update items stay hidden there.
    // One that did answer once keeps them, so a night offline does not make them vanish.
    static func isOfferedHere(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: reachedKey) || !defaults.bool(forKey: failedKey)
    }

    static func hasReachedRepository(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: reachedKey)
    }

    static func isDue(now: Date = Date(), in defaults: UserDefaults = .standard) -> Bool {
        guard checksAutomatically(in: defaults) else { return false }
        guard let last = defaults.object(forKey: lastCheckKey) as? Date else { return true }
        return now.timeIntervalSince(last) >= checkInterval
    }

    static func record(found: AppVersion?, notes: String? = nil, assets: (dmg: URL, checksum: URL)? = nil, now: Date = Date(), in defaults: UserDefaults = .standard) {
        if let assets, found != nil {
            defaults.set(assets.dmg.absoluteString, forKey: availableDMGKey)
            defaults.set(assets.checksum.absoluteString, forKey: availableChecksumKey)
        } else {
            defaults.removeObject(forKey: availableDMGKey)
            defaults.removeObject(forKey: availableChecksumKey)
        }
        defaults.set(now, forKey: lastCheckKey)
        defaults.set(true, forKey: reachedKey)
        defaults.removeObject(forKey: failedKey)
        if let found { defaults.set(found.text, forKey: availableKey) } else { defaults.removeObject(forKey: availableKey) }
        if let notes, found != nil { defaults.set(notes, forKey: notesKey) } else { defaults.removeObject(forKey: notesKey) }
    }

    static func recordFailure(now: Date = Date(), in defaults: UserDefaults = .standard) {
        defaults.set(now, forKey: lastCheckKey)
        defaults.set(true, forKey: failedKey)
    }

    // A version is offered in a dialog once; after "Not now" it waits in the menu instead of asking again.
    static func shouldAnnounce(_ version: String, in defaults: UserDefaults = .standard) -> Bool {
        defaults.string(forKey: announcedKey) != version
    }

    static func markAnnounced(_ version: String, in defaults: UserDefaults = .standard) {
        defaults.set(version, forKey: announcedKey)
    }

    static func recordDownload(_ version: AppVersion, at root: URL, in defaults: UserDefaults = .standard) {
        defaults.set(version.text, forKey: downloadedVersionKey)
        defaults.set(root.path, forKey: downloadedPathKey)
    }

    // The folder of a finished download of exactly this version, if it is still on disk.
    static func downloadedRoot(for version: AppVersion, in defaults: UserDefaults = .standard) -> URL? {
        guard defaults.string(forKey: downloadedVersionKey) == version.text,
              let path = defaults.string(forKey: downloadedPathKey),
              FileManager.default.fileExists(atPath: path) else { return nil }
        return URL(fileURLWithPath: path)
    }

    // Forgets the download and returns its folder so the caller can delete it.
    @discardableResult
    static func clearDownload(in defaults: UserDefaults = .standard) -> URL? {
        let path = defaults.string(forKey: downloadedPathKey)
        defaults.removeObject(forKey: downloadedVersionKey)
        defaults.removeObject(forKey: downloadedPathKey)
        return path.map { URL(fileURLWithPath: $0) }
    }

    // The line under "Check for updates": what the last check found, so the answer is visible without a dialog.
    static func statusLine(current: AppVersion, now: Date = Date(), in defaults: UserDefaults = .standard) -> String? {
        if let version = pending(current: current, in: defaults) {
            return downloadedRoot(for: version, in: defaults) == nil
                ? "Version \(version.text) is ready to install" : "Version \(version.text) is downloaded and ready"
        }
        guard let last = defaults.object(forKey: lastCheckKey) as? Date else { return nil }
        if defaults.bool(forKey: failedKey) { return "Last check could not reach GitHub" }
        return "Up to date, checked \(ago(last, now: now))"
    }

    private static func ago(_ date: Date, now: Date) -> String {
        guard now.timeIntervalSince(date) >= 60 else { return "just now" }
        return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: now)
    }

    // Where the waiting release's dmg and checksum are, so the download is exactly that release.
    static func availableAssets(in defaults: UserDefaults = .standard) -> (dmg: URL, checksum: URL)? {
        guard let dmg = defaults.string(forKey: availableDMGKey).flatMap(URL.init(string:)),
              let checksum = defaults.string(forKey: availableChecksumKey).flatMap(URL.init(string:)) else { return nil }
        return (dmg, checksum)
    }

    static func pendingNotes(in defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: notesKey)
    }

    // A remembered version stops counting as new once this app is that version or newer.
    static func pending(current: AppVersion, in defaults: UserDefaults = .standard) -> AppVersion? {
        defaults.string(forKey: availableKey).flatMap(AppVersion.init).flatMap { $0 > current ? $0 : nil }
    }
}
