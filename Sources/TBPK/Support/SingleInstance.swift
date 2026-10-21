import AppKit

// One copy at a time: a second launch (Login Items plus a click, or a copy opened from the dmg) would give two
// menu bar icons that both switch the Mac's sleep setting.
enum SingleInstance {
    static func isAnotherRunning(bundleIdentifier: String? = Bundle.main.bundleIdentifier, ownPID: pid_t = getpid()) -> Bool {
        guard let bundleIdentifier else { return false }
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .contains { $0.processIdentifier != ownPID && !$0.isTerminated }
    }
}
