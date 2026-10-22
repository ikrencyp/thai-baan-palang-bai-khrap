import AppKit

// Draws a frame only when the leaf really looks different, and sleeps between heartbeats: frames are the most
// expensive thing this app does, because every one of them is a redraw of the menu bar.
@MainActor
final class StatusIconAnimator {
    private static let frameInterval: TimeInterval = 1.0 / 30
    // A long rest must not make the spring jump: it is stepped with at most this much time.
    private static let longestStep: TimeInterval = 0.05

    private enum Pace {
        case still
        case frames
        case resting(TimeInterval)
    }

    private struct Look: Equatable {
        enum Tint { case none, alert, power }

        let fill: Double
        let scale: Double
        let alpha: Double
        let burst: Double
        let glow: Double
        let tint: Tint

        init(fill: Double, scale: Double, alpha: Double, burst: Double, glow: Double, tint: Tint) {
            self.fill = Self.coarse(fill)
            self.scale = Self.coarse(scale)
            self.alpha = Self.coarse(alpha)
            self.burst = Self.coarse(burst)
            self.glow = Self.coarse(glow)
            self.tint = tint
        }

        private static func coarse(_ value: Double) -> Double { (value * 500).rounded() / 500 }
    }

    private let applyImage: (NSImage?) -> Void
    private var motion = LeafMotion(fill: 0)
    private var target = IconTarget(awake: false, busy: false, failed: false, alerting: false, beating: false)
    private var animated = true
    private var timer: Timer?
    private let epoch = ProcessInfo.processInfo.systemUptime
    private var lastTick: TimeInterval?
    private var burstStart: TimeInterval?
    private var lastLook: Look?
    // The power level the beat is shaped by now; a new one is taken between beats so a beat never changes shape halfway.
    private var intensity = PowerIntensity.unknown
    static let burstLength: TimeInterval = 1.1

    init(applyImage: @escaping (NSImage?) -> Void) {
        self.applyImage = applyImage
    }

    private var clock: TimeInterval { ProcessInfo.processInfo.systemUptime - epoch }

    func retarget(_ next: IconTarget, animated: Bool) {
        self.animated = animated
        if animated, next.awake, !target.awake, !next.failed { burstStart = clock }
        target = next
        adoptIntensityIfResting()
        if !animated { motion.snap(to: goal) }
        draw()
        syncTimer()
    }

    private var goal: Double { target.awake ? 1 : 0 }

    private var pace: Pace {
        guard animated, !target.failed else { return .still }
        let settled = motion.isSettled && motion.fill == goal
        if !settled || burstProgress != nil || target.busy { return .frames }
        guard target.beating, target.awake else { return .still }
        let now = clock
        return Heartbeat.isBeating(at: now, every: gap)
            ? .frames : .resting(Heartbeat.restLeft(at: now, every: gap))
    }

    private var gap: TimeInterval { Heartbeat.gap(base: target.beatEvery, intensity: intensity) }

    private func adoptIntensityIfResting() {
        guard intensity != target.intensity, !Heartbeat.isBeating(at: clock, every: gap) else { return }
        intensity = target.intensity
    }

    // Before the timer stops or sleeps the leaf is drawn once more, so the last frame on screen is the resting one.
    private func syncTimer() {
        switch pace {
        case .still:
            draw()
            stopTimer()
        case .frames:
            runFrames()
        case .resting(let wait):
            draw()
            sleep(for: wait)
        }
    }

    private func runFrames() {
        if let timer, timer.isValid, timer.timeInterval == Self.frameInterval { return }
        install(Timer(timeInterval: Self.frameInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }, tolerance: 0.004)
    }

    private func sleep(for wait: TimeInterval) {
        install(Timer(timeInterval: wait, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }, tolerance: min(0.2, wait * 0.1))
    }

    private func install(_ next: Timer, tolerance: TimeInterval) {
        timer?.invalidate()
        next.tolerance = tolerance
        RunLoop.main.add(next, forMode: .common)
        timer = next
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        lastTick = nil
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let step = min(now - (lastTick ?? now - Self.frameInterval), Self.longestStep)
        lastTick = now
        adoptIntensityIfResting()
        motion.step(toward: goal, dt: step)
        draw()
        syncTimer()
    }

    // The flame around the leaf is always golden; the leaf itself is green on the charger and red off it.
    static let powerGold = NSColor(srgbRed: 1, green: 0.8, blue: 0.1, alpha: 1)
    static let powerGreen = NSColor(srgbRed: 0.18, green: 0.86, blue: 0.43, alpha: 1)

    private func beating(_ settled: Bool) -> Bool {
        animated && target.beating && target.awake && settled
    }

    private var burstProgress: Double? {
        guard let start = burstStart else { return nil }
        let progress = (clock - start) / Self.burstLength
        return progress < 1 ? progress : nil
    }

    private func draw() {
        guard !target.failed else {
            lastLook = nil
            applyImage(LeafGlyph.failureImage())
            return
        }
        let now = clock
        let settledOnLeaf = motion.fill == goal
        let pulse = beating(settledOnLeaf) ? Heartbeat.pulse(at: now, every: gap) : 0
        let beat = 1 + Heartbeat.swell(intensity: intensity) * pulse
        let pop = 1 + motion.overshoot * 1.1 - motion.undershoot * 0.9
        let shimmer = animated && target.busy ? 0.7 + 0.3 * sin(now * 9) : 1
        let powered = motion.fill > 0.35
        let glow = powered ? (0.45 + 0.55 * min(pulse, 1.2) / 1.2) * (0.6 + 0.4 * intensity) : 0
        let look = Look(fill: motion.drawnFill, scale: beat * pop, alpha: shimmer, burst: burstProgress ?? 0, glow: glow,
                        tint: target.alerting ? .alert : (powered || burstProgress != nil ? .power : .none))
        guard look != lastLook else { return }
        lastLook = look
        applyImage(LeafGlyph.image(
            fill: look.fill, scale: look.scale, alpha: look.alpha, tint: Self.color(look.tint), burst: look.burst, glow: look.glow,
            glowColor: look.tint == .none ? nil : Self.powerGold))
    }

    private static func color(_ tint: Look.Tint) -> NSColor? {
        switch tint {
        case .none: return nil
        case .alert: return .systemRed
        case .power: return powerGreen
        }
    }
}
