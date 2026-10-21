import Foundation

enum EndDatePreset: CaseIterable {
    case inThirtyMinutes
    case inOneHour
    case inFourHours
    case inEightHours

    var label: String {
        switch self {
        case .inThirtyMinutes: return "30 min"
        case .inOneHour: return "1 hour"
        case .inFourHours: return "4 hours"
        case .inEightHours: return "8 hours"
        }
    }

    private var seconds: TimeInterval {
        switch self {
        case .inThirtyMinutes: return 30 * 60
        case .inOneHour: return 60 * 60
        case .inFourHours: return 4 * 60 * 60
        case .inEightHours: return 8 * 60 * 60
        }
    }

    func moment(from now: Date, calendar: Calendar = .current) -> Date {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now.addingTimeInterval(seconds))
        return calendar.date(from: parts) ?? now
    }
}
