import Foundation

enum StatusPreferences {
    private static let countdownKey = "showCountdown"
    private static let animationKey = "showAnimation"
    private static let darkenKey = "darkenWhenClosed"
    private static let keepScreenKey = "keepScreenOn"
    private static let lookPresentKey = "lookPresent"

    static var showCountdown: Bool {
        stored(countdownKey)
    }

    static var showAnimation: Bool {
        stored(animationKey)
    }

    static var darkenWhenClosed: Bool {
        stored(darkenKey)
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
