import Foundation

// Turning disablesleep back off only lifts the block: macOS does not look at a lid that was closed or a screen
// that was locked while the block was on, so the Mac would keep running (and stay warm) until some later idle timer.
// After a restore this says what to hand back to the system right away.
enum ExpiryHandback {
    enum Action: Equatable {
        case none
        case sleepMac
        case sleepDisplay
    }

    static func action(for snapshot: UnattendedSnapshot) -> Action {
        if snapshot.lidClosed, !snapshot.hasExternalDisplay { return .sleepMac }
        if snapshot.screenLocked { return .sleepDisplay }
        return .none
    }

    static func run() {
        switch action(for: .read(buzzing: false)) {
        case .sleepMac: DisplayControl.sleepMacNow()
        case .sleepDisplay: DisplayControl.sleepNow()
        case .none: break
        }
    }
}
