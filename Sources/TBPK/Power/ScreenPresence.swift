import ApplicationServices
import Foundation

// While on, one tap of F19 (a key no app or keyboard maps by default) is posted once a minute, but only when the
// Mac is idle, unlocked and lit. macOS counts it as input, so the Mac does not look idle to other apps. A key tap, unlike
// a mouse move, never wakes a status item tooltip, a menu, a hot corner or the Dock, wherever the pointer rests.
// Off: nothing is posted and the idle time runs as it did before.
@MainActor
final class ScreenPresence {
    static let interval: TimeInterval = 60

    private var timer: Timer?

    func setActive(_ active: Bool) {
        guard active else {
            timer?.invalidate()
            timer = nil
            return
        }
        guard timer == nil else { return }
        let next = Timer(timeInterval: Self.interval, repeats: true) { _ in Self.pulse() }
        next.tolerance = Self.interval / 6
        RunLoop.main.add(next, forMode: .common)
        timer = next
    }

    // Posting input needs the Accessibility permission; without it macOS drops the event.
    static func requestAccess() {
        if !CGPreflightPostEventAccess() { CGRequestPostEventAccess() }
    }

    // Only an idle, unlocked, lit Mac gets the pulse: a pulse while someone types, or on the lock screen, can
    // swallow shortcuts and Spotlight, and a pulse with no known cursor position would park the cursor in a hot corner.
    nonisolated static func shouldPulse(idle: TimeInterval, locked: Bool, displayAsleep: Bool) -> Bool {
        !locked && !displayAsleep && idle >= interval * 0.75
    }

    nonisolated static let keyCode: CGKeyCode = 80

    static func pulse() {
        guard CGPreflightPostEventAccess() else { return }
        let snapshot = UnattendedSnapshot.read(buzzing: true)
        let idle = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: CGEventType(rawValue: ~0)!)
        guard shouldPulse(idle: idle, locked: snapshot.screenLocked,
                          displayAsleep: CGDisplayIsAsleep(CGMainDisplayID()) != 0) else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isDown) else { continue }
            event.flags = []
            event.post(tap: .cghidEventTap)
        }
    }
}
