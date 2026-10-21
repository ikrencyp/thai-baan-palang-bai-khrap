import Foundation

enum QuitPlan: Equatable {
    case quitNow
    case restoreThenQuit

    static func decide(sleepDisabled: Bool, ownsOverride: Bool) -> QuitPlan {
        sleepDisabled && ownsOverride ? .restoreThenQuit : .quitNow
    }
}
