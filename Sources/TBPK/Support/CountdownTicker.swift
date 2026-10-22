import Foundation

// Calls `show` once per second, on the second, for as long as `remaining` answers a time. One timer at a time, and
// `sync` can be called as often as the app likes (every render does): a timer already due soon enough is left alone.
@MainActor
final class CountdownTicker {
    private var timer: Timer?
    private let remaining: () -> TimeInterval?
    private let show: () -> Void

    init(remaining: @escaping () -> TimeInterval?, show: @escaping () -> Void) {
        self.remaining = remaining
        self.show = show
    }

    var isRunning: Bool { timer?.isValid == true }

    func sync() {
        guard let left = remaining() else {
            stop()
            return
        }
        // Land just after the second changes, not a fixed second after the last tick: that drifts and skips.
        let delay = ClockText.untilNextSecond(left) + 0.03
        if let running = timer, running.isValid, running.fireDate.timeIntervalSinceNow <= delay + 0.2 { return }
        timer?.invalidate()
        let next = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.fire() }
        }
        next.tolerance = 0.02
        RunLoop.main.add(next, forMode: .common)
        timer = next
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // A one-shot timer is still valid, and still pending in `timer`, while its own block runs: it must be dropped
    // before `sync` looks at it, or `sync` takes it for the next tick and the countdown stops after one second.
    private func fire() {
        timer = nil
        show()
        sync()
    }
}
