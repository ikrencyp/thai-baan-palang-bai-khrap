import AppKit

struct IconTarget: Equatable {
    var awake: Bool
    var busy: Bool
    var failed: Bool
    var alerting: Bool
    var beating: Bool
    var beatEvery: TimeInterval = Heartbeat.period
    var intensity: Double = PowerIntensity.unknown
    var leaf: LeafColor = .standard
    var batteryLeaf: LeafColor = .batteryStandard
}
