import Foundation

enum PresenceRhythm: String, CaseIterable {
    case continuous
    case deepFocus
    case balanced
    case relaxed

    static let storageKey = "presenceRhythm"

    static func stored(in defaults: UserDefaults = .standard) -> PresenceRhythm {
        guard let raw = defaults.string(forKey: storageKey) else { return .continuous }
        return PresenceRhythm(rawValue: raw) ?? .continuous
    }

    static var stored: PresenceRhythm {
        stored(in: .standard)
    }

    func store(in defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.storageKey)
    }

    var label: String {
        switch self {
        case .continuous: return "Continuous (always green)"
        case .deepFocus: return "Deep focus (45–90m work, 0–8m break)"
        case .balanced: return "Balanced (30–60m work, 3–15m break)"
        case .relaxed: return "Relaxed (20–40m work, 5–18m break)"
        }
    }

    var shortLabel: String {
        switch self {
        case .continuous: return "Continuous"
        case .deepFocus: return "Deep focus"
        case .balanced: return "Balanced"
        case .relaxed: return "Relaxed"
        }
    }

    var activeRange: ClosedRange<TimeInterval> {
        switch self {
        case .continuous: return 0...0
        case .deepFocus: return 45 * 60 ... 90 * 60
        case .balanced: return 30 * 60 ... 60 * 60
        case .relaxed: return 20 * 60 ... 40 * 60
        }
    }

    var restingRange: ClosedRange<TimeInterval> {
        switch self {
        case .continuous: return 0...0
        case .deepFocus: return 0 ... 8 * 60
        case .balanced: return 3 * 60 ... 15 * 60
        case .relaxed: return 5 * 60 ... 18 * 60
        }
    }
}
