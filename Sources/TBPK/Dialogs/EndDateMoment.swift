import Foundation

enum EndDateMoment {
    static func combine(day: Date, time: Date, calendar: Calendar = .current) -> Date {
        var parts = calendar.dateComponents([.year, .month, .day], from: day)
        let clock = calendar.dateComponents([.hour, .minute], from: time)
        parts.hour = clock.hour
        parts.minute = clock.minute
        parts.second = 0
        return calendar.date(from: parts) ?? day
    }

    static func combine(day: Date, hour: Int, minute: Int, calendar: Calendar = .current) -> Date {
        var parts = calendar.dateComponents([.year, .month, .day], from: day)
        parts.hour = hour
        parts.minute = minute
        parts.second = 0
        return calendar.date(from: parts) ?? day
    }

    static func nextOccurrence(hour: Int, minute: Int = 0, after now: Date, calendar: Calendar = .current) -> Date {
        var parts = calendar.dateComponents([.year, .month, .day], from: now)
        parts.hour = hour
        parts.minute = minute
        parts.second = 0
        let today = calendar.date(from: parts) ?? now
        guard today <= now else { return today }
        return calendar.date(byAdding: .day, value: 1, to: today) ?? today
    }
}
