import ApplicationServices
import Foundation

// While on, a mouse-moved event with no movement is posted every minute. macOS counts that as input, so the Mac
// does not look idle to other apps. Off: nothing is posted and the idle time runs as it did before.
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
        Self.pulse()
        let next = Timer(timeInterval: Self.interval, repeats: true) { _ in Self.pulse() }
        next.tolerance = Self.interval / 6
        RunLoop.main.add(next, forMode: .common)
        timer = next
    }

    // Posting input needs the Accessibility permission; without it macOS drops the event.
    static func requestAccess() {
        if !CGPreflightPostEventAccess() { CGRequestPostEventAccess() }
    }

    static func pulse() {
        guard CGPreflightPostEventAccess() else { return }
        let location = CGEvent(source: nil)?.location ?? .zero
        CGEvent(mouseEventSource: CGEventSource(stateID: .hidSystemState), mouseType: .mouseMoved,
                mouseCursorPosition: location, mouseButton: .left)?.post(tap: .cghidEventTap)
    }
}
