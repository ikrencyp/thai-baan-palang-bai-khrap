import AppKit
import Combine

// Reads what macOS says (charger, Low Power Mode, Reduce Motion, display asleep) and the person's choice, and
// publishes the one plan every timer follows. It only listens: nothing here polls.
@MainActor
final class EnergyMonitor: ObservableObject {
    static let shared = EnergyMonitor()

    @Published private(set) var plan: EnergyPlan
    private lazy var systemObserver = SystemChangeObserver { [weak self] in self?.refresh() }
    private var observing = false

    private init() {
        plan = Self.currentPlan()
    }

    func start() {
        guard !observing else { return }
        observing = true
        systemObserver.start()
        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
    }

    func refresh() {
        let next = Self.currentPlan()
        guard next != plan else { return }
        plan = next
    }

    private static func currentPlan() -> EnergyPlan {
        let conditions = conditions()
        return EnergyPlan.resolve(EnergyProfile.active(onBattery: conditions.onBattery), conditions)
    }

    static func conditions() -> EnergyPlan.Conditions {
        EnergyPlan.Conditions(
            onBattery: UnattendedSnapshot.isOnBattery,
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
            displayAsleep: CGDisplayIsAsleep(CGMainDisplayID()) != 0
        )
    }
}
