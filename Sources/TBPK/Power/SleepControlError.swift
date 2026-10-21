import Foundation

enum SleepControlError: LocalizedError {
    case userCancelled
    case privilegeFailure(String)

    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "The password prompt was cancelled."
        case .privilegeFailure(let detail):
            return "Could not change the sleep setting. \(detail)"
        }
    }
}
