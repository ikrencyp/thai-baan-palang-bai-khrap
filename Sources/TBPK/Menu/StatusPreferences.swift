import Foundation

enum StatusPreferences {
    private static let countdownKey = "showCountdown"
    private static let animationKey = "showAnimation"
    static let darkenKey = "darkenWhenClosed"
    private static let keepScreenKey = "keepScreenOn"
    private static let lookPresentKey = "lookPresent"

    static var showCountdown: Bool {
        stored(countdownKey)
    }

    static var showAnimation: Bool {
        stored(animationKey)
    }

    // Off on a new install: the screen stays as it is until the person asks for it to go dark.
    static var darkenWhenClosed: Bool {
        UserDefaults.standard.bool(forKey: darkenKey)
    }

    // Earlier versions had this on without the person ever choosing it. An install that already ran keeps it on,
    // so an update changes nothing for it; only a new install starts with it off. Run before the launch is recorded.
    static func keepEarlierDarkenChoice(in defaults: UserDefaults = .standard) {
        guard defaults.object(forKey: darkenKey) == nil, defaults.string(forKey: WhatsNewWindow.lastVersionKey) != nil else { return }
        defaults.set(true, forKey: darkenKey)
    }

    // On (the default): while awake the app holds a "do not dim or sleep the display" request with macOS.
    // Off: it holds none, so the display follows the Mac's own display sleep time.
    static var keepScreenOn: Bool {
        stored(keepScreenKey)
    }

    // Off (the default): the app sends no input. On: while awake it keeps the Mac from looking idle (see ScreenPresence).
    static var lookPresent: Bool {
        UserDefaults.standard.bool(forKey: lookPresentKey)
    }

    static func toggleLookPresent() {
        set(!lookPresent, forKey: lookPresentKey)
    }

    static func toggleKeepScreenOn() {
        set(!keepScreenOn, forKey: keepScreenKey)
    }

    static func toggleDarkenWhenClosed() {
        set(!darkenWhenClosed, forKey: darkenKey)
    }

    static func toggleCountdown() {
        set(!showCountdown, forKey: countdownKey)
    }

    static func toggleAnimation() {
        set(!showAnimation, forKey: animationKey)
    }

    private static func stored(_ key: String) -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: key) != nil else { return true }
        return defaults.bool(forKey: key)
    }

    private static func set(_ value: Bool, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
}
