import Foundation

enum LidWarningMode: String, CaseIterable, Identifiable {
    case off
    case firstTimeOnly
    case everyFiveMinutes
    case everyFifteenMinutes
    case everyThirtyMinutes

    static let storageKey = "lidWarningMode"

    static var stored: LidWarningMode {
        guard let raw = UserDefaults.standard.string(forKey: storageKey) else { return .firstTimeOnly }
        return LidWarningMode(rawValue: raw) ?? .firstTimeOnly
    }

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: return "Off"
        case .firstTimeOnly: return "Once"
        case .everyFiveMinutes: return "Every 5 minutes"
        case .everyFifteenMinutes: return "Every 15 minutes"
        case .everyThirtyMinutes: return "Every 30 minutes"
        }
    }

    var repeatInterval: TimeInterval? {
        switch self {
        case .off, .firstTimeOnly: return nil
        case .everyFiveMinutes: return 5 * 60
        case .everyFifteenMinutes: return 15 * 60
        case .everyThirtyMinutes: return 30 * 60
        }
    }
}
