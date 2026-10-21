import Foundation

// How much the app may spend to look alive and to check on the Mac. Automatic follows macOS: calm on the charger,
// still on battery, in Low Power Mode, or with Reduce Motion on.
enum EnergyProfile: String, CaseIterable {
    case automatic
    case full
    case saver

    static let storageKey = "energyProfile"

    static func stored(in defaults: UserDefaults = .standard) -> EnergyProfile {
        defaults.string(forKey: storageKey).flatMap(EnergyProfile.init(rawValue:)) ?? .automatic
    }

    func store(in defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.storageKey)
    }

    var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .full: return "Full performance"
        case .saver: return "Power saver"
        }
    }

    var detail: String {
        switch self {
        case .automatic: return "Follows macOS: calm on the charger, still on battery or in Low Power Mode."
        case .full: return "Smooth heartbeat and the quickest checks. Uses the most power."
        case .saver: return "Still leaf, slow checks. Uses the least power."
        }
    }
}
