import Foundation

@MainActor
final class BatterySaver {
    static let storageKey = "saveBatteryPower"
    nonisolated private static let originalKey = "batteryLowPowerOriginal"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: storageKey)
    }

    static func setEnabled(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: storageKey)
    }

    nonisolated static var isApplied: Bool {
        UserDefaults.standard.object(forKey: originalKey) != nil
    }

    func sync(awake: Bool) {
        let wanted = awake && Self.isEnabled
        guard wanted != Self.isApplied else { return }
        Task.detached(priority: .userInitiated) {
            if wanted { Self.apply() } else { Self.restoreNow() }
        }
    }

    nonisolated static func apply() {
        guard !isApplied, let original = PrivilegedShell.lowPowerOnBattery() else { return }
        UserDefaults.standard.set(original, forKey: originalKey)
        if !PrivilegedShell.setLowPowerOnBattery(true) {
            UserDefaults.standard.removeObject(forKey: originalKey)
        }
    }

    nonisolated static func restoreNow() {
        guard let original = UserDefaults.standard.object(forKey: originalKey) as? Bool else { return }
        if PrivilegedShell.setLowPowerOnBattery(original) {
            UserDefaults.standard.removeObject(forKey: originalKey)
        }
    }
}
