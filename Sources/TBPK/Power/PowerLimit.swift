import Foundation

enum PowerLimit: String, CaseIterable, Identifiable {
    case none
    case below20
    case below10
    case chargerOnly

    static let storageKey = "powerLimit"

    static var stored: PowerLimit {
        guard let raw = UserDefaults.standard.string(forKey: storageKey) else { return .none }
        return PowerLimit(rawValue: raw) ?? .none
    }

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "Never"
        case .below20: return "Battery drops below 20%"
        case .below10: return "Battery drops below 10%"
        case .chargerOnly: return "The charger is unplugged"
        }
    }

    func stopReason(onBattery: Bool, percent: Int?) -> String? {
        guard onBattery else { return nil }
        switch self {
        case .none: return nil
        case .chargerOnly: return "The charger was unplugged, so normal sleep is back."
        case .below20: return reason(percent, floor: 20)
        case .below10: return reason(percent, floor: 10)
        }
    }

    private func reason(_ percent: Int?, floor: Int) -> String? {
        guard let percent, percent < floor else { return nil }
        return "Battery fell to \(percent)%, so normal sleep is back."
    }
}
