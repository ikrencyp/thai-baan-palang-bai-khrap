import Foundation

enum SleepDuration: String, CaseIterable, Identifiable {
    case thirtyMinutes
    case oneHour
    case twoHours
    case fourHours
    case eightHours
    case twelveHours
    case indefinite
    case untilDate

    static let storageKey = "selectedDuration"

    static var stored: SleepDuration {
        guard let raw = UserDefaults.standard.string(forKey: storageKey) else { return .indefinite }
        return SleepDuration(rawValue: raw) ?? .indefinite
    }

    var id: String { rawValue }

    var label: String {
        switch self {
        case .thirtyMinutes: return "30 minutes"
        case .oneHour: return "1 hour"
        case .twoHours: return "2 hours"
        case .fourHours: return "4 hours"
        case .eightHours: return "8 hours"
        case .twelveHours: return "12 hours"
        case .indefinite: return "Until I turn it off"
        case .untilDate: return "At a date and time…"
        }
    }

    var seconds: TimeInterval? {
        switch self {
        case .thirtyMinutes: return 30 * 60
        case .oneHour: return 60 * 60
        case .twoHours: return 2 * 60 * 60
        case .fourHours: return 4 * 60 * 60
        case .eightHours: return 8 * 60 * 60
        case .twelveHours: return 12 * 60 * 60
        case .indefinite, .untilDate: return nil
        }
    }

    var restoresAsCountdown: Bool { self != .indefinite }
}
