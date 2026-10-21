import Foundation

struct LeafMotion {
    static let stiffness = 190.0
    static let damping = 11.0

    private(set) var fill: Double
    private var velocity = 0.0

    init(fill: Double) {
        self.fill = fill
    }

    var isSettled: Bool { abs(velocity) < 0.01 }

    mutating func step(toward target: Double, dt: Double) {
        let pull = Self.stiffness * (target - fill) - Self.damping * velocity
        velocity += pull * dt
        fill += velocity * dt
        guard abs(target - fill) < 0.002, abs(velocity) < 0.02 else { return }
        fill = target
        velocity = 0
    }

    mutating func snap(to target: Double) {
        fill = target
        velocity = 0
    }

    var overshoot: Double { max(0, fill - 1) }

    var undershoot: Double { max(0, -fill) }

    var drawnFill: Double { min(max(fill, 0), 1) }
}
