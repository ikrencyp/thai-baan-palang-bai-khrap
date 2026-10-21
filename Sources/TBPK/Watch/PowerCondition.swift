import Foundation

enum PowerCondition: String, CaseIterable, Identifiable {
    case batteryOnly
    case anyPower

    static let storageKey = "warningPowerCondition"

    static var stored: PowerCondition {
        guard let raw = UserDefaults.standard.string(forKey: storageKey) else { return .batteryOnly }
        return PowerCondition(rawValue: raw) ?? .batteryOnly
    }

    var id: String { rawValue }

    var label: String {
        switch self {
        case .batteryOnly: return "Only on battery"
        case .anyPower: return "On battery or plugged in"
        }
    }

    func covers(onBattery: Bool) -> Bool {
        self == .anyPower || onBattery
    }
}
