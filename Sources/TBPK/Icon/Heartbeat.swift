import Foundation

enum Heartbeat {
    static let period = 0.9

    static func pulse(at time: TimeInterval) -> Double {
        let phase = time.truncatingRemainder(dividingBy: period) / period
        return bump(phase, center: 0.12, width: 0.06) + 0.75 * bump(phase, center: 0.33, width: 0.07)
    }

    static func scale(at time: TimeInterval) -> Double {
        1 + 0.28 * pulse(at: time)
    }

    // Both pulses are over by the middle of a period; the second half is rest, so no frame is needed there.
    static let activeLength = period / 2

    // The same heartbeat, repeated every `gap` seconds (never faster than the natural period).
    static func pulse(at time: TimeInterval, every gap: TimeInterval) -> Double {
        let local = time.truncatingRemainder(dividingBy: max(gap, period))
        return local < activeLength ? pulse(at: local) : 0
    }

    static func isBeating(at time: TimeInterval, every gap: TimeInterval) -> Bool {
        time.truncatingRemainder(dividingBy: max(gap, period)) < activeLength
    }

    // How long until the next beat starts, while at rest.
    static func restLeft(at time: TimeInterval, every gap: TimeInterval) -> TimeInterval {
        let length = max(gap, period)
        return length - time.truncatingRemainder(dividingBy: length)
    }

    private static func bump(_ phase: Double, center: Double, width: Double) -> Double {
        let distance = (phase - center) / width
        return exp(-distance * distance)
    }
}
