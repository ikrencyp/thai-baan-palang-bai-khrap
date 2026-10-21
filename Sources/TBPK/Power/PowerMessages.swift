import Foundation

enum PowerMessages {
    static let idle = "Normal sleep is active."
    static let externallyDisabled = "Sleep is disabled. No timer set."
    static let restoredTimer = "Sleep is disabled. Timer restored from last time."
    static let timeIsUp = "Time is up."
    static let reading = "Reading power settings…"
    static let disabling = "Disabling sleep…"
    static let restoring = "Restoring normal sleep…"
    static let firstTimePrompt = "Thai Baan Palang Bai Khrap needs admin rights once. After this it will never ask again."
    static let enablePrompt = "Thai Baan Palang Bai Khrap wants to disable sleep so this Mac keeps running with the lid closed."
    static let disablePrompt = "Thai Baan Palang Bai Khrap wants to restore normal sleep."
    static let batterySaverPrompt = "Thai Baan Palang Bai Khrap needs admin rights once to switch Low Power Mode on while you are on battery. It adds the same small no-password rule as \"Allow, no password after this\": four exact pmset commands, nothing else."
    static let quitPrompt = "Thai Baan Palang Bai Khrap wants to restore normal sleep before quitting."

    static func active(for duration: SleepDuration) -> String {
        switch duration {
        case .indefinite:
            return "Sleep disabled until you turn it off."
        case .untilDate:
            return "Sleep disabled until the time you picked."
        default:
            guard let seconds = duration.seconds else { return "Sleep disabled until you turn it off." }
            return "Sleep disabled for \(ClockText.short(seconds))."
        }
    }

    static func untilWallClock(_ date: Date) -> String {
        "Sleep disabled until \(EndDateText.describe(date, now: Date()))."
    }
}
