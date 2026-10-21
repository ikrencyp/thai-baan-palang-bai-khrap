import Foundation
import IOKit.pwr_mgt

@MainActor
final class DisplaySleepGuard {
    private var assertionID: IOPMAssertionID?

    func setHolding(_ active: Bool) {
        if active {
            create()
        } else {
            release()
        }
    }

    private func create() {
        guard assertionID == nil else { return }
        var id: IOPMAssertionID = 0
        let status = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Thai Baan Palang Bai Khrap is holding this Mac awake" as CFString,
            &id
        )
        guard status == kIOReturnSuccess else { return }
        assertionID = id
    }

    private func release() {
        guard let id = assertionID else { return }
        IOPMAssertionRelease(id)
        assertionID = nil
    }
}
