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

    private var isRunning = false
    private var awake = false

    // One change at a time. The governor asks on every power, lid and timer event; two overlapping runs could read the
    // Low Power Mode that the first one had just set as the "original" and leave it on for good.
    func sync(awake: Bool) {
        self.awake = awake
        let wanted = awake && Self.isEnabled
        guard !isRunning, wanted != Self.isApplied else { return }
        isRunning = true
        Task {
            await Task.detached(priority: .userInitiated) {
                if wanted { Self.apply() } else { Self.restoreNow() }
            }.value
            isRunning = false
            // Asked again only when the wish moved while it ran: a failed change is not retried in a loop.
            if (self.awake && Self.isEnabled) != wanted { sync(awake: self.awake) }
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
