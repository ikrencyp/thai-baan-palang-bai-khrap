import Foundation

struct UnattendedDecision {
    // Lifting the lid to look, or locking for a coffee, must not cost a beep.
    static let holdTime: TimeInterval = 1.5

    private(set) var isAlerting = false

    private var since: Date?
    private var lastWarnedAt: Date?
    private var knownTriggers: Set<UnattendedKind> = []
    private var wasOnBattery = true

    mutating func observe(
        _ snapshot: UnattendedSnapshot,
        mode: LidWarningMode,
        condition: PowerCondition = .batteryOnly,
        now: Date,
        holdTime: TimeInterval = UnattendedDecision.holdTime
    ) -> UnattendedEvent? {
        guard snapshot.buzzing else {
            endSession()
            return nil
        }
        let active = mode != .off && snapshot.isUnattended(under: condition)
        isAlerting = active
        guard active else {
            forgetEpisode()
            return nil
        }
        let startsNewEpisode = since == nil || joinsNewRisk(snapshot)
        remember(snapshot)
        if startsNewEpisode {
            since = now
            lastWarnedAt = nil
            return nil
        }
        guard let startedAt = since,
              shouldWarn(mode: mode, now: now, startedAt: startedAt, holdTime: holdTime) else { return nil }
        lastWarnedAt = now
        return UnattendedEvent(kind: snapshot.alertKind, startedAt: startedAt, onBattery: snapshot.onBattery)
    }

    // Seconds until this decision could change by itself (the hold running out, the next repeat), or nil when
    // only a change in the Mac, which the system observers report, can matter. Lets the watch sleep until then.
    func nextWake(mode: LidWarningMode, now: Date, holdTime: TimeInterval = UnattendedDecision.holdTime) -> TimeInterval? {
        guard let startedAt = since else { return nil }
        if let last = lastWarnedAt {
            return mode.repeatInterval.map { max(0, $0 - now.timeIntervalSince(last)) }
        }
        return max(0, holdTime - now.timeIntervalSince(startedAt))
    }

    mutating func endSession() {
        isAlerting = false
        forgetEpisode()
    }

    // Triggers going away never start an episode: lifting the lid on a locked screen is the user coming back.
    private func joinsNewRisk(_ snapshot: UnattendedSnapshot) -> Bool {
        !snapshot.triggers.isSubset(of: knownTriggers) || (snapshot.onBattery && !wasOnBattery)
    }

    private mutating func remember(_ snapshot: UnattendedSnapshot) {
        knownTriggers = snapshot.triggers
        wasOnBattery = snapshot.onBattery
    }

    private mutating func forgetEpisode() {
        since = nil
        lastWarnedAt = nil
        knownTriggers = []
        wasOnBattery = true
    }

    private func shouldWarn(
        mode: LidWarningMode,
        now: Date,
        startedAt: Date,
        holdTime: TimeInterval
    ) -> Bool {
        if let last = lastWarnedAt {
            guard let repeatEvery = mode.repeatInterval else { return false }
            return now.timeIntervalSince(last) >= repeatEvery
        }
        return now.timeIntervalSince(startedAt) >= holdTime
    }
}
