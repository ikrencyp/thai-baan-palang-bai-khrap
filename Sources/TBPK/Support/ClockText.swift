import Foundation

enum ClockText {
    static func short(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.up)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }

    // Seconds until the whole-second text changes: it counts up, so it changes the moment the time left falls to
    // the next lower whole second. Waiting for exactly that moment keeps the seconds from slipping and skipping.
    static func untilNextSecond(_ interval: TimeInterval) -> TimeInterval {
        let fraction = max(0, interval) - max(0, interval).rounded(.down)
        return fraction < 0.001 ? 1 : fraction
    }

    static func hourMinute(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
