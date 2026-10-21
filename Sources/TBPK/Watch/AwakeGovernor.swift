import Combine
import Foundation

@MainActor
final class AwakeGovernor {
    private let power: PowerManager
    private let displayGuard: DisplaySleepGuard
    private let energy: EnergyMonitor
    private var timer: Timer?
    private var wasDark = false
    private let batterySaver = BatterySaver()
    private var subscriptions: [AnyCancellable] = []
    private lazy var observer = SystemChangeObserver { [weak self] in self?.evaluate() }

    init(power: PowerManager, displayGuard: DisplaySleepGuard, energy: EnergyMonitor? = nil) {
        self.power = power
        self.displayGuard = displayGuard
        let energy = energy ?? .shared
        self.energy = energy
        subscriptions = [
            power.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.evaluate() },
            energy.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.retime() },
        ]
        evaluate()
    }

    func evaluate() {
        batterySaver.sync(awake: power.isSleepDisabled && !power.isWorking)
        guard power.isSleepDisabled, !power.isWorking else {
            if !power.isSleepDisabled { release() }
            return
        }
        arm()
        let snapshot = UnattendedSnapshot.read(buzzing: true)
        if let reason = PowerLimit.stored.stopReason(onBattery: snapshot.onBattery, percent: snapshot.batteryPercent) {
            power.stopForRule(reason: reason)
            AttentionSound.playOnce()
            return
        }
        let darken = StatusPreferences.darkenWhenClosed
        let holds = DisplayPolicy.holdsDisplay(
            awake: true, keepScreenOn: StatusPreferences.keepScreenOn, darkenWhenClosed: darken, locked: snapshot.screenLocked, lidClosed: snapshot.lidClosed)
        displayGuard.setHolding(holds)
        if !holds, !wasDark, snapshot.screenLocked { DisplayControl.sleepNow() }
        wasDark = !holds
    }

    // The observers report every lid, lock, display and power change at once; the timer is only the safety net.
    private func arm() {
        observer.start()
        let interval = energy.plan.governorTick
        guard timer?.timeInterval != interval else { return }
        timer?.invalidate()
        let next = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.evaluate() }
        }
        next.tolerance = interval * 0.2
        RunLoop.main.add(next, forMode: .common)
        timer = next
    }

    private func retime() {
        guard timer != nil else { return }
        arm()
    }

    private func release() {
        timer?.invalidate()
        timer = nil
        observer.stop()
        wasDark = false
        displayGuard.setHolding(false)
    }
}
