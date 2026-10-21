import Foundation

// The power-up when Keep awake turns on, as phases of one 0...1 progress: the leaf trembles and heats up, a white flash
// peaks, then the flame aura bursts out with a few bolts and settles. Pure functions of the progress, so every frame is
// reproducible and unit tested.
enum Transformation {
    static let flashPeak = 0.42

    // 0 until the charge begins, 1 at the flash: the leaf turns white-hot.
    static func charge(at progress: Double) -> Double {
        guard progress > 0, progress < flashPeak else { return 0 }
        return min(progress / flashPeak, 1) * 0.8
    }

    // A narrow peak at flashPeak.
    static func flash(at progress: Double) -> Double {
        max(0, 1 - abs(progress - flashPeak) / 0.1)
    }

    // A fast side-to-side tremble that grows until the flash (points).
    static func shake(at progress: Double) -> Double {
        guard progress > 0, progress < flashPeak else { return 0 }
        return sin(progress * 150) * 0.9 * (progress / flashPeak)
    }

    // The aura swells during the charge, flares past full after the flash, then eases back to nothing so the steady
    // aura of the running state takes over.
    static func aura(at progress: Double) -> Double {
        guard progress > 0, progress < 1 else { return 0 }
        if progress < flashPeak { return 0.2 + 0.5 * progress / flashPeak }
        let after = (progress - flashPeak) / (1 - flashPeak)
        return 1.35 * (1 - after) + 0.0
    }

    // The bolts live between the flash and the end.
    static func sparks(at progress: Double) -> Double {
        guard progress > flashPeak, progress < 1 else { return 0 }
        return (progress - flashPeak) / (1 - flashPeak)
    }
}
