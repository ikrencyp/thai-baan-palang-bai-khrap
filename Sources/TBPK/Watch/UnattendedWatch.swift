import AppKit
import Combine
import Foundation

@MainActor
final class UnattendedWatch: ObservableObject {
    // The decision says when it can next change by itself (the hold, a repeat); the system observers report every
    // change in the Mac. Between the two the watch sleeps, and never longer than the energy plan allows.
    private static let shortestWait: TimeInterval = 0.1

    struct PowerState {
        let isSleepDisabled: Bool
        let pendingValue: Bool?
        let expiresAt: Date?
    }

    @Published private(set) var isAlerting = false
    @Published private(set) var lastEvent: UnattendedEvent?

    private let energy: EnergyMonitor
    private let readPowerState: () -> PowerState
    private let expirePowerIfDue: (Date) -> Void
    private let refreshPower: () -> Void
    private let systemSleepDisabled: () -> Bool
    private let hasBatteryCheck: () -> Bool
    private let readSnapshot: () -> UnattendedSnapshot
    private let now: () -> Date
    private let playAlert: () -> Void
    private let stopAlert: () -> Void
    private var subscriptions: [AnyCancellable] = []
    private var decision = UnattendedDecision()
    private var timer: Timer?
    // Without it macOS may nap a windowless app once the lid is down, delaying the beep.
    private var activity: NSObjectProtocol?
    private lazy var observer = SystemChangeObserver { [weak self] in self?.tick() }

    convenience init(power: PowerManager, energy: EnergyMonitor? = nil) {
        self.init(
            energy: energy,
            powerChanges: power.objectWillChange.receive(on: DispatchQueue.main).eraseToAnyPublisher(),
            powerState: {
                PowerState(
                    isSleepDisabled: power.isSleepDisabled,
                    pendingValue: power.pendingValue,
                    expiresAt: power.expiresAt
                )
            },
            expireIfDue: { power.expireIfDue(now: $0) },
            refreshPower: { power.refresh() }
        )
    }

    init(
        energy: EnergyMonitor? = nil,
        powerChanges: AnyPublisher<Void, Never> = Empty<Void, Never>().eraseToAnyPublisher(),
        powerState: @escaping () -> PowerState,
        expireIfDue: @escaping (Date) -> Void = { _ in },
        refreshPower: @escaping () -> Void = {},
        systemSleepDisabled: @escaping () -> Bool = { PrivilegedShell.isSleepDisabled() },
        hasBattery: @escaping () -> Bool = { UnattendedSnapshot.hasBattery },
        readSnapshot: @escaping () -> UnattendedSnapshot = { UnattendedSnapshot.read(buzzing: true) },
        now: @escaping () -> Date = Date.init,
        playAlert: (@MainActor () -> Void)? = nil,
        stopAlert: (@MainActor () -> Void)? = nil
    ) {
        let energy = energy ?? .shared
        self.energy = energy
        self.readPowerState = powerState
        self.expirePowerIfDue = expireIfDue
        self.refreshPower = refreshPower
        self.systemSleepDisabled = systemSleepDisabled
        self.hasBatteryCheck = hasBattery
        self.readSnapshot = readSnapshot
        self.now = now
        self.playAlert = playAlert ?? { AttentionSound.play() }
        self.stopAlert = stopAlert ?? { AttentionSound.stopAlert() }
        lastEvent = UnattendedEvent.stored
        subscriptions = [
            powerChanges.sink { [weak self] _ in self?.reconcile() },
            energy.objectWillChange.receive(on: DispatchQueue.main).sink { [weak self] _ in self?.reconcile() },
        ]
        reconcile()
        if !powerState().isSleepDisabled { clearRecord() }
    }

    static var isAvailable: Bool { UnattendedSnapshot.hasBattery }

    func setMode(_ mode: LidWarningMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: LidWarningMode.storageKey)
        decision.endSession()
        apply(alerting: false)
        if mode == .off { clearRecord() }
        reconcile(stopAlertIfWatching: true)
    }

    func setPowerCondition(_ condition: PowerCondition) {
        UserDefaults.standard.set(condition.rawValue, forKey: PowerCondition.storageKey)
        decision.endSession()
        apply(alerting: false)
        stopAlert()
    }

    // Watching stops as soon as sleep is back on, turning back on is already under way, or a timer has reached its end.
    nonisolated static func shouldWatch(
        mode: LidWarningMode,
        hasBattery: Bool,
        isSleepDisabled: Bool,
        pendingValue: Bool?,
        expiresAt: Date?,
        now: Date
    ) -> Bool {
        guard mode != .off, hasBattery, isSleepDisabled else { return false }
        if pendingValue == false { return false }
        if let expiresAt, expiresAt <= now { return false }
        return true
    }

    private func wantsTicking(at current: Date) -> Bool {
        let state = readPowerState()
        return Self.shouldWatch(
            mode: LidWarningMode.stored,
            hasBattery: hasBatteryCheck(),
            isSleepDisabled: state.isSleepDisabled,
            pendingValue: state.pendingValue,
            expiresAt: state.expiresAt,
            now: current
        )
    }

    func reconcile() {
        reconcile(stopAlertIfWatching: false)
    }

    private func reconcile(stopAlertIfWatching: Bool) {
        let current = now()
        expirePowerIfDue(current)
        guard wantsTicking(at: current) else { return settle() }
        if stopAlertIfWatching { stopAlert() }
        scheduleNext()
        observer.start()
        guard activity == nil else { return }
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Watching for a closed lid or a locked screen")
    }

    private func scheduleNext() {
        timer?.invalidate()
        let idle = energy.plan.idleWatchTick
        let wait = decision.nextWake(mode: LidWarningMode.stored, now: now()).map { min($0, idle) } ?? idle
        let delay = max(wait, Self.shortestWait)
        let next = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        next.tolerance = min(delay * 0.25, 0.5)
        RunLoop.main.add(next, forMode: .common)
        timer = next
    }

    private func settle() {
        decision.endSession()
        apply(alerting: false)
        stopAlert()
        guard timer != nil || activity != nil else { return }
        timer?.invalidate()
        timer = nil
        observer.stop()
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        activity = nil
        clearRecord()
    }

    func tick() {
        let mode = LidWarningMode.stored
        let current = now()
        expirePowerIfDue(current)
        let state = readPowerState()
        guard Self.shouldWatch(
            mode: mode,
            hasBattery: hasBatteryCheck(),
            isSleepDisabled: state.isSleepDisabled,
            pendingValue: state.pendingValue,
            expiresAt: state.expiresAt,
            now: current
        ) else { return settle() }
        let snapshot = readSnapshot()
        let event = decision.observe(snapshot, mode: mode, condition: PowerCondition.stored, now: current)
        if (decision.isAlerting || event != nil), !systemSleepDisabled() {
            refreshPower()
            return settle()
        }
        apply(alerting: decision.isAlerting)
        scheduleNext()
        guard let event else { return }
        event.store()
        lastEvent = event
        playAlert()
    }

    // Publish only real changes: a per-tick publish rebuilds an open menu under the pointer.
    private func apply(alerting: Bool) {
        guard alerting != isAlerting else { return }
        isAlerting = alerting
    }

    private func clearRecord() {
        guard lastEvent != nil else { return }
        lastEvent = nil
        UnattendedEvent.clearStored()
    }
}
