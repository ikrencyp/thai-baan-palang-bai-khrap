import Foundation

// True only while this app is the one that switched the sleep override on, so Quit gives back
// the setting the Mac had before the app touched it and leaves an override somebody else set.
enum SleepOwnership {
    static let storageKey = "appEnabledSleepOverride"

    static var isOwned: Bool {
        get { UserDefaults.standard.bool(forKey: storageKey) }
        set { UserDefaults.standard.set(newValue, forKey: storageKey) }
    }
}
