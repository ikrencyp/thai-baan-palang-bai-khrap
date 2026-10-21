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

    private var seconds: TimeInterval {
        switch self {
        case .minutes: return 60
        case .hours: return 3_600
        case .days: return 86_400
        case .weeks: return 604_800
        }
    }

    func moment(after amount: Int, from now: Date, calendar: Calendar = .current) -> Date? {
        guard amount > 0, amount <= Self.largestAmount else { return nil }
        let parts = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute], from: now.addingTimeInterval(Double(amount) * seconds))
        return calendar.date(from: parts)
    }

    static let largestAmount = 9_999
}
