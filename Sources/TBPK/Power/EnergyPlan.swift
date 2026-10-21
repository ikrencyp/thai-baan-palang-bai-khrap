import Foundation

// What the energy profile means in numbers, so every timer in the app asks one place how often to wake up.
struct EnergyPlan: Equatable {
    struct Conditions: Equatable {
        var onBattery = false
        var lowPowerMode = false
        var reduceMotion = false
        var displayAsleep = false
    }

    // Frames per second while the leaf moves (switching on or off, working). Zero keeps the leaf still.
    let frameRate: Double
    // Gap between heartbeats. Nil: no heartbeat.
    let beatEvery: TimeInterval?
    // How often the app looks for a reason to stop, or to let the screen go dark.
    let governorTick: TimeInterval
    // How often it asks the system whether sleep was switched back on elsewhere.
    let syncTick: TimeInterval
    // The longest it waits between looks at the lid and the lock while nothing is going on.
    let idleWatchTick: TimeInterval
    // Whole minutes in the menu bar countdown: it changes once a minute instead of once a second.
    let coarseCountdown: Bool
    // Nobody sees the menu bar while the display is asleep, so nothing is drawn.
    let isVisible: Bool

    static let full = EnergyPlan(frameRate: 30, beatEvery: Heartbeat.period, governorTick: 5, syncTick: 15,
                                 idleWatchTick: 1, coarseCountdown: false, isVisible: true)
    static let standard = EnergyPlan(frameRate: 30, beatEvery: 3.6, governorTick: 15, syncTick: 30,
                                     idleWatchTick: 2, coarseCountdown: false, isVisible: true)
    static let saver = EnergyPlan(frameRate: 0, beatEvery: nil, governorTick: 30, syncTick: 60,
                                  idleWatchTick: 5, coarseCountdown: true, isVisible: true)

    var animatesTransitions: Bool { frameRate > 0 }

    static func resolve(_ profile: EnergyProfile, _ conditions: Conditions) -> EnergyPlan {
        let base: EnergyPlan
        switch profile {
        case .full: base = .full
        case .saver: base = .saver
        case .automatic:
            let spare = conditions.onBattery || conditions.lowPowerMode || conditions.reduceMotion
            base = spare ? .saver : .standard
        }
        return conditions.displayAsleep ? base.unseen : base
    }

    private var unseen: EnergyPlan {
        EnergyPlan(frameRate: 0, beatEvery: nil, governorTick: governorTick, syncTick: syncTick,
                   idleWatchTick: idleWatchTick, coarseCountdown: coarseCountdown, isVisible: false)
    }

    // The line under the menu item: what is actually happening right now.
    var summary: String {
        guard isVisible else { return "Paused while the display is asleep" }
        guard let beatEvery else { return "Still leaf" }
        return beatEvery <= Heartbeat.period ? "Continuous heartbeat" : "Calm heartbeat"
    }
}
