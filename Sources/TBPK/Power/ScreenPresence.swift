import ApplicationServices
import Foundation

// While on, a small move is posted every half minute (Steady) or at irregular gaps (Random), but only when the Mac is
// idle, unlocked and lit. macOS counts it as input, so the Mac does not look idle to other apps. The move is the pointer
// stepping a few pixels to the right and straight back, which resets the idle time the way a hand on the mouse does. A pointer that
// rests in the menu bar, on a screen edge or in a corner is over something that reacts to a move (a status item tooltip,
// a menu, a hot corner, the Dock), so there one tap of F19, a key no app or keyboard maps by default, goes out instead.
// Off: nothing is posted and the idle time runs as it did before.
//
// The timer is strict and the app holds an activity while it runs: a menu bar app with no window is otherwise
// throttled by App Nap, and a pulse that arrives minutes late lets a chat app mark the user as away.
@MainActor
final class ScreenPresence {
    nonisolated static let interval: TimeInterval = 30
    // Query AXIsProcessTrusted() before CGPreflightPostEventAccess() because macOS
    // caches CGPreflightPostEventAccess() as false for the rest of the process lifetime.
    nonisolated(unsafe) static var hasAccessCheck: () -> Bool = {
        AXIsProcessTrusted() && CGPreflightPostEventAccess()
    }
    nonisolated(unsafe) static var needsRestartCheck: () -> Bool = {
        AXIsProcessTrusted() && !CGPreflightPostEventAccess()
    }

    static var hasAccess: Bool { hasAccessCheck() }
    static var needsRestartForAccess: Bool { !hasAccess && needsRestartCheck() }

    @discardableResult
    static func scheduleRelaunch(
        bundleURL: URL = Bundle.main.bundleURL,
        pid: Int32 = ProcessInfo.processInfo.processIdentifier
    ) -> Bool {
        guard bundleURL.pathExtension == "app" else { return false }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c",
            "n=0; while kill -0 \"$1\" 2>/dev/null && [ $n -lt 150 ]; do sleep 0.2; n=$((n+1)); done; kill -0 \"$1\" 2>/dev/null || exec /usr/bin/open \"$2\"",
            "sh",
            String(pid),
            bundleURL.path,
        ]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    static func requestAccess() -> Bool {
        CGRequestPostEventAccess()
    }

    static func resetAccessRecord() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier, !bundleID.isEmpty else { return false }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "Accessibility", bundleID]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    enum Phase: Equatable {
        case active(until: Date)
        case resting(until: Date)
    }

    private var timer: DispatchSourceTimer?
    private var activity: NSObjectProtocol?
    private var askedForAccess = false
    private var lastOutcome = ""
    private var currentPhase: Phase?
    private var lastRhythm: PresenceRhythm?

    nonisolated static func nextPhase(
        current: Phase?,
        rhythm: PresenceRhythm,
        now: Date,
        activeDuration: TimeInterval? = nil,
        restingDuration: TimeInterval? = nil
    ) -> (phase: Phase?, shouldPulse: Bool) {
        guard rhythm != .continuous else { return (nil, true) }
        let nextActive = now.addingTimeInterval(activeDuration ?? TimeInterval.random(in: rhythm.activeRange))
        guard let current else { return (.active(until: nextActive), true) }
        switch current {
        case .active(let until):
            guard now >= until else { return (current, true) }
            let rest = restingDuration ?? TimeInterval.random(in: rhythm.restingRange)
            return rest > 0 ? (.resting(until: now.addingTimeInterval(rest)), false) : (.active(until: nextActive), true)
        case .resting(let until):
            return now < until ? (current, false) : (.active(until: nextActive), true)
        }
    }

    func setActive(_ active: Bool) {
        guard active else {
            timer?.cancel()
            timer = nil
            if let activity { ProcessInfo.processInfo.endActivity(activity) }
            activity = nil
            askedForAccess = false
            lastOutcome = ""
            currentPhase = nil
            lastRhythm = nil
            return
        }
        guard timer == nil else { return }
        if !Self.hasAccess { handleMissingAccess() }
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep, reason: "Look present at the screen")
        let next = DispatchSource.makeTimerSource(flags: .strict, queue: .main)
        next.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.pulse() } }
        timer = next
        scheduleNext()
        next.resume()
    }

    // One shot per pulse, so Random can pick a new gap each time and a change in the menu counts from the next one.
    private func scheduleNext() {
        timer?.schedule(deadline: .now() + PresenceMotion.stored.nextGap(), repeating: .never, leeway: .seconds(1))
    }

    // Only an idle, unlocked, lit Mac gets the pulse: a pulse while someone types, or on the lock screen, can
    // swallow shortcuts and Spotlight, and a pulse with no known cursor position would park the cursor in a hot corner.
    nonisolated static func shouldPulse(idle: TimeInterval, locked: Bool, displayAsleep: Bool) -> Bool {
        !locked && !displayAsleep && idle >= interval * 0.5
    }

    nonisolated static let keyCode: CGKeyCode = 80

    // A step smaller than this does not reset the system idle time (measured: 1px did not, 3px did).
    nonisolated static let nudgeDistance: CGFloat = 4
    nonisolated static let nudgeReturnDelay: DispatchTimeInterval = .milliseconds(80)

    // A pointer resting in the menu bar, on a screen edge or in a corner is over something that reacts to a move: a
    // status item tooltip that then floats, a menu that opens, a hot corner, the Dock. It is only moved when it is clear
    // of all of those (top: the menu bar and the notch, with room for a tooltip).
    nonisolated static let topClearance: CGFloat = 60
    nonisolated static let edgeClearance: CGFloat = 40

    nonisolated static func isClearSpot(_ point: CGPoint, in displays: [CGRect]) -> Bool {
        guard let display = displays.first(where: { $0.contains(point) }) else { return false }
        return point.y - display.minY >= topClearance
            && display.maxY - point.y >= edgeClearance
            && point.x - display.minX >= edgeClearance
            && display.maxX - point.x >= edgeClearance
    }

    // Where the pointer steps to before it comes straight back, or nil when it is not in the open and a key tap is used.
    nonisolated static func nudgeTarget(from location: CGPoint, in displays: [CGRect]) -> CGPoint? {
        guard isClearSpot(location, in: displays) else { return nil }
        return CGPoint(x: location.x + nudgeDistance, y: location.y)
    }

    private static var displayBounds: [CGRect] {
        var count: UInt32 = 0
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        guard CGGetActiveDisplayList(16, &ids, &count) == .success else { return [] }
        return ids.prefix(Int(count)).map { CGDisplayBounds($0) }
    }

    private nonisolated static func postPointer(to point: CGPoint) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point,
                                  mouseButton: .left) else { return }
        event.flags = []
        event.post(tap: .cghidEventTap)
    }

    private nonisolated static func postKeyTap() {
        let source = CGEventSource(stateID: .hidSystemState)
        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isDown) else { continue }
            event.flags = []
            event.post(tap: .cghidEventTap)
        }
    }

    // Posting input needs the Accessibility permission; without it macOS drops the event. The first miss asks for the
    // permission again (the grant is lost when the app file changes) and every change of outcome is logged.
    private func pulse() {
        defer { scheduleNext() }
        guard Self.hasAccess else {
            handleMissingAccess()
            return
        }
        let rhythm = PresenceRhythm.stored
        if lastRhythm != rhythm {
            currentPhase = nil
            lastRhythm = rhythm
        }
        let now = Date()
        let evaluated = Self.nextPhase(current: currentPhase, rhythm: rhythm, now: now)
        currentPhase = evaluated.phase
        guard evaluated.shouldPulse else {
            if case .resting(let until) = evaluated.phase {
                let left = max(0, Int(until.timeIntervalSince(now)))
                record("resting (\(left)s left)")
            }
            return
        }
        let snapshot = UnattendedSnapshot.read(buzzing: true)
        let idle = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: CGEventType(rawValue: ~0)!)
        guard Self.shouldPulse(idle: idle, locked: snapshot.screenLocked,
                               displayAsleep: CGDisplayIsAsleep(CGMainDisplayID()) != 0) else {
            record("skipped (idle \(Int(idle))s, locked \(snapshot.screenLocked))")
            return
        }
        if let origin = CGEvent(source: nil)?.location, let target = Self.nudgeTarget(from: origin, in: Self.displayBounds) {
            Self.postPointer(to: target)
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.nudgeReturnDelay) { Self.postPointer(to: origin) }
            record("moved the pointer")
        } else {
            Self.postKeyTap()
            record("tapped a key")
        }
    }

    private func handleMissingAccess() {
        if Self.needsRestartForAccess {
            record("Accessibility granted, restart app to apply")
            return
        }
        if !askedForAccess {
            askedForAccess = true
            _ = Self.requestAccess()
        }
        record("no Accessibility permission, nothing posted")
    }

    private func record(_ outcome: String) {
        let kind = outcome.prefix(while: { $0 != " " })
        guard kind != lastOutcome else { return }
        lastOutcome = String(kind)
        NSLog("TBPK look present: %@", outcome)
    }
}
