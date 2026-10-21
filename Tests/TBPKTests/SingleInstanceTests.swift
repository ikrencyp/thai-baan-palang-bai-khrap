import XCTest
@testable import TBPK

final class SingleInstanceTests: XCTestCase {
    func testAnotherCopyOfARunningAppIsSeen() {
        XCTAssertTrue(SingleInstance.isAnotherRunning(bundleIdentifier: "com.apple.finder", ownPID: -1))
    }

    func testTheCopyItselfDoesNotCountAsAnotherOne() throws {
        let finder = try XCTUnwrap(NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first)
        XCTAssertFalse(SingleInstance.isAnotherRunning(bundleIdentifier: "com.apple.finder", ownPID: finder.processIdentifier)
                       && NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").count == 1)
    }

    func testAnAppThatIsNotRunningIsNotSeen() {
        XCTAssertFalse(SingleInstance.isAnotherRunning(bundleIdentifier: "com.thaibaan.no-such-app", ownPID: -1))
    }

    func testWithoutABundleIdentifierThereIsNothingToCompare() {
        XCTAssertFalse(SingleInstance.isAnotherRunning(bundleIdentifier: nil, ownPID: -1))
    }
}
