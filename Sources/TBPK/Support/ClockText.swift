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

    // Whole minutes, for the countdown that is redrawn once a minute: 1h 05m, 12m, <1m.
    static func coarse(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.up)))
        guard total >= 60 else { return total == 0 ? "0m" : "<1m" }
        let minutes = (total + 59) / 60
        return minutes >= 60 ? String(format: "%dh %02dm", minutes / 60, minutes % 60) : "\(minutes)m"
    }

    // Seconds until the coarse text changes, so the countdown is redrawn exactly when it matters.
    static func untilCoarseChange(_ interval: TimeInterval) -> TimeInterval {
        let total = max(0, interval)
        let toBoundary = total.truncatingRemainder(dividingBy: 60)
        return total < 60 ? max(total, 0.5) : (toBoundary == 0 ? 60 : toBoundary)
    }

    static func hourMinute(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
