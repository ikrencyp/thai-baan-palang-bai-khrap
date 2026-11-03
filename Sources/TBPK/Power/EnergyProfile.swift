import Foundation

// How much the app may spend to look alive and to check on the Mac. Automatic follows macOS: calm on the charger
// and on battery, still with Reduce Motion on.
enum EnergyProfile: String, CaseIterable {
    case automatic
    case full
    case saver

    // The choice is kept for the charger and for the battery. While "separate" is off the charger one counts for both,
    // and the battery one stays remembered for when it is switched on again.
    enum Slot: Equatable {
        case charger
        case battery

        var storageKey: String { self == .charger ? "energyProfile" : "energyProfileBattery" }
    }

    // What a choice row in the menu carries: the slot it fills and the profile itself.
    struct Pick: Equatable {
        let slot: Slot
        let profile: EnergyProfile
    }

    static let separateKey = "energyProfileSeparate"

    // The battery slot that was never set follows the charger one, so switching "separate" on changes nothing yet.
    static func stored(_ slot: Slot = .charger, in defaults: UserDefaults = .standard) -> EnergyProfile {
        let charger = defaults.string(forKey: Slot.charger.storageKey).flatMap(EnergyProfile.init(rawValue:)) ?? .automatic
        guard slot == .battery else { return charger }
        return defaults.string(forKey: slot.storageKey).flatMap(EnergyProfile.init(rawValue:)) ?? charger
    }

    func store(_ slot: Slot = .charger, in defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: slot.storageKey)
    }

    static func isSeparate(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: separateKey)
    }

    static func setSeparate(_ on: Bool, in defaults: UserDefaults = .standard) {
        defaults.set(on, forKey: separateKey)
    }

    // The choice that counts right now.
    static func active(onBattery: Bool, in defaults: UserDefaults = .standard) -> EnergyProfile {
        stored(isSeparate(in: defaults) && onBattery ? .battery : .charger, in: defaults)
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
        case .automatic: return "Follows macOS: calm heartbeat, still leaf with Reduce Motion on."
        case .full: return "Smooth heartbeat and the quickest checks. Uses the most power."
        case .saver: return "Still leaf, slow checks. Uses the least power."
        }
    }
}
