import Foundation
import ServiceManagement

enum LoginItem {
    static var isEnabled: Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval: return true
        case .notRegistered, .notFound: return false
        @unknown default: return false
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled {
            guard !isEnabled else { return }
            try service.register()
        } else {
            guard isEnabled else { return }
            try service.unregister()
        }
    }
}
