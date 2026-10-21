import Foundation

enum MenuBarIcon: Equatable {
    case failed
    case busy
    case disabledTimed
    case disabledIndefinite
    case normalSleep

    var isAwake: Bool {
        self == .disabledTimed || self == .disabledIndefinite
    }

    var isPulsing: Bool {
        self == .disabledTimed || self == .disabledIndefinite
    }

    var accessibilityLabel: String {
        switch self {
        case .failed: return "Thai Baan Palang Bai Khrap: the last change failed"
        case .busy: return "Thai Baan Palang Bai Khrap: working"
        case .disabledTimed: return "Thai Baan Palang Bai Khrap: sleep disabled, timer running"
        case .disabledIndefinite: return "Thai Baan Palang Bai Khrap: sleep disabled"
        case .normalSleep: return "Thai Baan Palang Bai Khrap: normal sleep"
        }
    }

    static func resolve(isSleepDisabled: Bool, isWorking: Bool, hasTimer: Bool, hasFailure: Bool) -> MenuBarIcon {
        guard !hasFailure else { return .failed }
        guard !isWorking else { return .busy }
        guard isSleepDisabled else { return .normalSleep }
        return hasTimer ? .disabledTimed : .disabledIndefinite
    }
}
