import AppKit

enum UpdateOutcome: Equatable {
    case upToDate
    case available(String)
    case unreachable
}
