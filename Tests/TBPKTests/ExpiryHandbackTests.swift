import XCTest
@testable import TBPK

final class ExpiryHandbackTests: XCTestCase {
    private func action(lid: Bool, locked: Bool, external: Bool = false) -> ExpiryHandback.Action {
        ExpiryHandback.action(for: UnattendedSnapshot(
            lidClosed: lid, screenLocked: locked, onBattery: true, buzzing: false, hasExternalDisplay: external))
    }

    func testAClosedLidWithNoExternalDisplaySleepsTheMac() {
        XCTAssertEqual(action(lid: true, locked: false), .sleepMac)
        XCTAssertEqual(action(lid: true, locked: true), .sleepMac)
    }

    func testClamshellOnAnExternalDisplayIsLeftToTheSystem() {
        XCTAssertEqual(action(lid: true, locked: false, external: true), .none)
    }

    func testAnOpenLockedMacSleepsOnlyTheDisplay() {
        XCTAssertEqual(action(lid: false, locked: true), .sleepDisplay)
    }

    func testSomeoneAtTheMacIsLeftAlone() {
        XCTAssertEqual(action(lid: false, locked: false), .none)
    }
}
