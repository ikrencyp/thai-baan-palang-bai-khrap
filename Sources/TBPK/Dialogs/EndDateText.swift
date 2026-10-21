import Foundation

enum EndDateText {
    static func describe(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        let clock = format(date, "HH:mm", calendar)
        if calendar.isDate(date, inSameDayAs: now) { return "Today \(clock)" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow \(clock)"
        }
        return format(date, "EEE d MMM, HH:mm", calendar)
    }

    static func dayLabel(_ day: Date, now: Date, calendar: Calendar = .current) -> String {
        if calendar.isDate(day, inSameDayAs: now) { return "Today" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(day, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        return format(day, "EEE d MMM", calendar)
    }

    static func timeLeft(until date: Date, now: Date) -> String? {
        let minutes = Int((date.timeIntervalSince(now) / 60).rounded(.up))
        guard minutes > 0 else { return nil }
        let days = minutes / 1440
        let hours = (minutes % 1440) / 60
        let rest = minutes % 60
        if days > 0 { return "in \(days) \(days == 1 ? "day" : "days") \(hours) h" }
        if hours > 0 { return rest == 0 ? "in \(hours) h" : "in \(hours) h \(rest) min" }
        return "in \(rest) min"
    }

    static func restoreLine(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Restores at \(format(date, "HH:mm:ss", calendar))" }
        return "Restores \(format(date, "EEE d MMM, HH:mm:ss", calendar))"
    }

    private static func format(_ date: Date, _ pattern: String, _ calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
