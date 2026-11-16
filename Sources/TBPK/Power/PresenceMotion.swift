import Foundation

// How Look present spaces its moves: on a fixed beat, or at irregular gaps. Breaks (PresenceRhythm) are a separate choice.
enum PresenceMotion: String, CaseIterable {
    case steady
    case random

    static let storageKey = "presenceMotion"

    static func stored(in defaults: UserDefaults = .standard) -> PresenceMotion {
        defaults.string(forKey: storageKey).flatMap(PresenceMotion.init(rawValue:)) ?? .steady
    }

    static var stored: PresenceMotion {
        stored(in: .standard)
    }

    func store(in defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.storageKey)
    }

    var label: String {
        switch self {
        case .steady: return "Steady (every 30 seconds)"
        case .random: return "Random (every 20 to 60 seconds)"
        }
    }

    var shortLabel: String {
        switch self {
        case .steady: return "Steady"
        case .random: return "Random"
        }
    }

    // Both stay far below the five minutes after which chat apps show a person as away.
    var gap: ClosedRange<TimeInterval> {
        switch self {
        case .steady: return 30 ... 30
        case .random: return 20 ... 60
        }
    }

    func nextGap() -> TimeInterval {
        TimeInterval.random(in: gap)
    }
}
