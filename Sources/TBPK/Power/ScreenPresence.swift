import ApplicationServices
import Foundation

// While on, one tap of F19 (a key no app or keyboard maps by default) is posted every half minute, but only when the
// Mac is idle, unlocked and lit. macOS counts it as input, so the Mac does not look idle to other apps. A key tap, unlike
// a mouse move, never wakes a status item tooltip, a menu, a hot corner or the Dock, wherever the pointer rests.
// Off: nothing is posted and the idle time runs as it did before.
//
// The timer is strict and the app holds an activity while it runs: a menu bar app with no window is otherwise
// throttled by App Nap, and a pulse that arrives minutes late lets a chat app mark the user as away.
@MainActor
final class ScreenPresence {
    static let interval: TimeInterval = 30

    private var timer: DispatchSourceTimer?
    private var activity: NSObjectProtocol?
    private var askedForAccess = false
    private var lastOutcome = ""

    func setActive(_ active: Bool) {
        guard active else {
            timer?.cancel()
            timer = nil
            if let activity { ProcessInfo.processInfo.endActivity(activity) }
            activity = nil
            askedForAccess = false
            lastOutcome = ""
            return
        }
        guard timer == nil else { return }
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep, reason: "Look present at the screen")
        let next = DispatchSource.makeTimerSource(flags: .strict, queue: .main)
        next.schedule(deadline: .now() + Self.interval, repeating: Self.interval, leeway: .seconds(1))
        next.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.pulse() } }
        next.resume()
        timer = next
    }

    // Posting input needs the Accessibility permission; without it macOS drops the event.
    static func requestAccess() {
        if !CGPreflightPostEventAccess() { CGRequestPostEventAccess() }
    }

    // Only an idle, unlocked, lit Mac gets the pulse: a pulse while someone types, or on the lock screen, can
    // swallow shortcuts and Spotlight, and a pulse with no known cursor position would park the cursor in a hot corner.
    nonisolated static func shouldPulse(idle: TimeInterval, locked: Bool, displayAsleep: Bool) -> Bool {
        !locked && !displayAsleep && idle >= interval * 0.5
    }

    nonisolated static let keyCode: CGKeyCode = 80

    // Posting input needs the Accessibility permission; without it macOS drops the event. The first miss asks for the
    // permission again (the grant is lost when the app file changes) and every change of outcome is logged.
    private func pulse() {
        guard CGPreflightPostEventAccess() else {
            if !askedForAccess {
                askedForAccess = true
                CGRequestPostEventAccess()
            }
            record("no Accessibility permission, nothing posted")
            return
        }
        let snapshot = UnattendedSnapshot.read(buzzing: true)
        let idle = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: CGEventType(rawValue: ~0)!)
        guard Self.shouldPulse(idle: idle, locked: snapshot.screenLocked,
                               displayAsleep: CGDisplayIsAsleep(CGMainDisplayID()) != 0) else {
            record("skipped (idle \(Int(idle))s, locked \(snapshot.screenLocked))")
            return
        }
        let source = CGEventSource(stateID: .hidSystemState)
        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: Self.keyCode, keyDown: isDown) else { continue }
            event.flags = []
            event.post(tap: .cghidEventTap)
        }
        record("posted")
    }

    private func record(_ outcome: String) {
        let kind = outcome.prefix(while: { $0 != " " })
        guard kind != lastOutcome else { return }
        lastOutcome = String(kind)
        NSLog("TBPK look present: %@", outcome)
    }
}
