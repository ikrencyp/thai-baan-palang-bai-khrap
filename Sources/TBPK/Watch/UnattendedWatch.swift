import AppKit
import Combine
import Foundation

@MainActor
final class UnattendedWatch: ObservableObject {
    // The decision says when it can next change by itself (the hold, a repeat); the system observers report every
    // change in the Mac. Between the two the watch sleeps, and never longer than the energy plan allows.
    private static let shortestWait: TimeInterval = 0.1

    @Published private(set) var isAlerting = false
    @Published private(set) var lastEvent: UnattendedEvent?

    private let power: PowerManager
    private let energy: EnergyMonitor
    private var subscriptions: [AnyCancellable] = []
    private var decision = UnattendedDecision()
    private var timer: Timer?
    // Without it macOS may nap a windowless app once the lid is down, delaying the beep.
    private var activity: NSObjectProtocol?
    private lazy var observer = SystemChangeObserver { [weak self] in self?.tick() }

    init(power: PowerManager, energy: EnergyMonitor? = nil) {
        self.power = power
        let energy = energy ?? .shared
        self.energy = energy
        lastEvent = UnattendedEvent.stored
        subscriptions = [
            power.objectWillChange.receive(on: RunLoop.main).sink { [weak self] _ in self?.reconcile() },
            energy.objectWillChange.receive(on: RunLoop.main).sink { [weak self] _ in self?.reconcile() },
        ]
        reconcile()
        if !power.isSleepDisabled { clearRecord() }
    }

    static var isAvailable: Bool { UnattendedSnapshot.hasBattery }

    func setMode(_ mode: LidWarningMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: LidWarningMode.storageKey)
        decision.endSession()
        apply(alerting: false)
        if mode == .off { clearRecord() }
        reconcile()
    }

    func setPowerCondition(_ condition: PowerCondition) {
        UserDefaults.standard.set(condition.rawValue, forKey: PowerCondition.storageKey)
        decision.endSession()
        apply(alerting: false)
    }

    // Only a Mac that is kept awake has anything to watch: when sleep is not disabled the timer, the observers and
    // the "do not nap" request are all released.
    private var wantsTicking: Bool {
        LidWarningMode.stored != .off && Self.isAvailable && power.isSleepDisabled
    }

    private func reconcile() {
        guard wantsTicking else { return settle() }
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
        let wait = decision.nextWake(mode: LidWarningMode.stored, now: Date()).map { min($0, idle) } ?? idle
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
        guard timer != nil || activity != nil else { return }
        timer?.invalidate()
        timer = nil
        observer.stop()
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        activity = nil
        clearRecord()
    }

    private func tick() {
        let mode = LidWarningMode.stored
        guard mode != .off, power.isSleepDisabled else { return settle() }
        let snapshot = UnattendedSnapshot.read(buzzing: true)
        let event = decision.observe(snapshot, mode: mode, condition: PowerCondition.stored, now: Date())
        apply(alerting: decision.isAlerting)
        scheduleNext()
        guard let event else { return }
        event.store()
        lastEvent = event
        AttentionSound.play()
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
