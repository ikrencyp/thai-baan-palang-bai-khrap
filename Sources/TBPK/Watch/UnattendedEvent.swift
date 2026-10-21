import Foundation

struct UnattendedEvent {
    let kind: UnattendedKind
    let startedAt: Date
    var onBattery: Bool = true

    private enum StorageKey {
        static let kind = "lastUnattendedKind"
        static let date = "lastUnattendedDate"
        static let onBattery = "lastUnattendedOnBattery"
    }

    static var stored: UnattendedEvent? {
        let defaults = UserDefaults.standard
        guard let raw = defaults.string(forKey: StorageKey.kind), let kind = UnattendedKind(rawValue: raw) else {
            return nil
        }
        let seconds = defaults.double(forKey: StorageKey.date)
        guard seconds > 0 else { return nil }
        let onBattery = defaults.object(forKey: StorageKey.onBattery) as? Bool ?? true
        return UnattendedEvent(kind: kind, startedAt: Date(timeIntervalSince1970: seconds), onBattery: onBattery)
    }

    func store() {
        let defaults = UserDefaults.standard
        defaults.set(kind.rawValue, forKey: StorageKey.kind)
        defaults.set(startedAt.timeIntervalSince1970, forKey: StorageKey.date)
        defaults.set(onBattery, forKey: StorageKey.onBattery)
    }

    static func clearStored() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: StorageKey.kind)
        defaults.removeObject(forKey: StorageKey.date)
        defaults.removeObject(forKey: StorageKey.onBattery)
    }

    var menuText: String {
        "\(kind.label) \(ClockText.hourMinute(startedAt)) \(onBattery ? "on battery" : "plugged in")"
    }
}
