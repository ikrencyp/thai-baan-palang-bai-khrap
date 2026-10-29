import Foundation

enum EndDateUnit: CaseIterable {
    case minutes
    case hours
    case days
    case weeks

    var label: String {
        switch self {
        case .minutes: return "minutes"
        case .hours: return "hours"
        case .days: return "days"
        case .weeks: return "weeks"
        }
    }

    var minutes: Int {
        switch self {
        case .minutes: return 1
        case .hours: return 60
        case .days: return 1_440
        case .weeks: return 10_080
        }
    }

    // `total` is the whole length in minutes (an amount of this unit plus any extra minutes); the seconds are dropped.
    static func moment(afterMinutes total: Int, from now: Date, calendar: Calendar = .current) -> Date? {
        guard total > 0 else { return nil }
        let parts = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute], from: now.addingTimeInterval(Double(total) * 60))
        return calendar.date(from: parts)
    }

    static let largestAmount = 9_999
}
