import Foundation

enum UnattendedKind: String {
    case lidClosed
    case screenLocked

    var label: String {
        switch self {
        case .lidClosed: return "Lid closed"
        case .screenLocked: return "Screen locked"
        }
    }
}
