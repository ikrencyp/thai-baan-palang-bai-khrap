import Foundation

// Turns watts into a 0...1 "how hard is the Mac working" that the heartbeat follows: a laptop idles around 8 W and
// is flat out near 60 W, and the curve is a little steeper at the low end, where most of the time is spent.
enum PowerIntensity {
    static let idleWatts = 8.0
    static let flatOutWatts = 60.0
    // What the leaf uses until the first reading arrives, or on a Mac that cannot be read.
    static let unknown = 0.5

    static func level(watts: Double) -> Double {
        let share = min(max((watts - idleWatts) / (flatOutWatts - idleWatts), 0), 1)
        return pow(share, 0.8)
    }

    // Half way to each new reading, so one spike does not make the leaf lurch.
    static func smoothed(previous: Double, next: Double) -> Double {
        previous + 0.5 * (next - previous)
    }

    // Tenths only: the leaf is redrawn when the level changes, and redraws are the expensive part.
    static func quantised(_ level: Double) -> Double {
        (min(max(level, 0), 1) * 10).rounded() / 10
    }
}
