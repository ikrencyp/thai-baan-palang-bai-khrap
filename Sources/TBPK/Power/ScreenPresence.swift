import ApplicationServices
import Foundation

// While on, a mouse-moved event with no movement is posted once a minute, but only when the Mac
// is idle, unlocked and lit and the pointer is in the open. macOS counts that as input, so the Mac does not look idle to other apps. Off: nothing is posted and the idle time runs as it did before.
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

    // A pointer resting in the menu bar, on a screen edge or in a corner is over something that reacts to a move: a
    // status item tooltip that then floats, a menu that opens, a hot corner, the Dock. The nudge is only sent when the
    // pointer is clear of all of those (top: the menu bar and the notch, with room for a tooltip).
    nonisolated static let topClearance: CGFloat = 60
    nonisolated static let edgeClearance: CGFloat = 40

    nonisolated static func isClearSpot(_ point: CGPoint, in displays: [CGRect]) -> Bool {
        guard let display = displays.first(where: { $0.contains(point) }) else { return false }
        return point.y - display.minY >= topClearance
            && display.maxY - point.y >= edgeClearance
            && point.x - display.minX >= edgeClearance
            && display.maxX - point.x >= edgeClearance
    }

    private static var displayBounds: [CGRect] {
        var count: UInt32 = 0
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        guard CGGetActiveDisplayList(16, &ids, &count) == .success else { return [] }
        return ids.prefix(Int(count)).map { CGDisplayBounds($0) }
    }

    static func pulse() {
        guard CGPreflightPostEventAccess() else { return }
        let snapshot = UnattendedSnapshot.read(buzzing: true)
        let idle = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: CGEventType(rawValue: ~0)!)
        guard shouldPulse(idle: idle, locked: snapshot.screenLocked,
                          displayAsleep: CGDisplayIsAsleep(CGMainDisplayID()) != 0),
              let location = CGEvent(source: nil)?.location,
              isClearSpot(location, in: displayBounds),
              let event = CGEvent(mouseEventSource: CGEventSource(stateID: .hidSystemState), mouseType: .mouseMoved,
                                  mouseCursorPosition: location, mouseButton: .left) else { return }
        event.flags = []
        event.setIntegerValueField(.mouseEventDeltaX, value: 0)
        event.setIntegerValueField(.mouseEventDeltaY, value: 0)
        event.post(tap: .cghidEventTap)
    }
}
