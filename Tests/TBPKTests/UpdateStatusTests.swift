import XCTest
@testable import TBPK

final class UpdateStatusTests: XCTestCase {
    private var defaults: UserDefaults!
    private let now = Date()

    override func setUp() { defaults = scratchDefaults("tbpk-status") }

    func testBeforeAnyCheckThereIsNothingToSay() {
        XCTAssertNil(UpdateStore.statusLine(current: AppVersion("2.1.0")!, now: now, in: defaults))
    }

    func testAFoundVersionIsReadyToInstall() {
        UpdateStore.record(found: AppVersion("2.2.0"), now: now, in: defaults)
        XCTAssertEqual(UpdateStore.statusLine(current: AppVersion("2.1.0")!, now: now, in: defaults), "Version 2.2.0 is ready to install")
    }

    func testAnEmptyCheckSaysUpToDateAndWhen() {
        UpdateStore.record(found: nil, now: now, in: defaults)
        XCTAssertEqual(UpdateStore.statusLine(current: AppVersion("2.1.0")!, now: now.addingTimeInterval(5), in: defaults),
                       "Up to date, checked just now")
        let later = UpdateStore.statusLine(current: AppVersion("2.1.0")!, now: now.addingTimeInterval(3 * 3600), in: defaults)
        XCTAssertTrue(try XCTUnwrap(later).hasPrefix("Up to date, checked "))
        XCTAssertNotEqual(later, "Up to date, checked just now")
    }

    func testAFailedCheckSaysSo() {
        UpdateStore.record(found: nil, now: now, in: defaults)
        UpdateStore.recordFailure(now: now, in: defaults)
        XCTAssertEqual(UpdateStore.statusLine(current: AppVersion("2.1.0")!, now: now, in: defaults),
                       "Last check could not reach GitHub")
    }

    func testAVersionIsOfferedInADialogOnlyOnce() {
        XCTAssertTrue(UpdateStore.shouldAnnounce("2.2.0", in: defaults))
        UpdateStore.markAnnounced("2.2.0", in: defaults)
        XCTAssertFalse(UpdateStore.shouldAnnounce("2.2.0", in: defaults))
        XCTAssertTrue(UpdateStore.shouldAnnounce("2.3.0", in: defaults))
    }

    func testADownloadedVersionSaysSoUnderTheMenuItem() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("tbpk-dl-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        UpdateStore.record(found: AppVersion("2.2.0"), now: now, in: defaults)
        XCTAssertEqual(UpdateStore.statusLine(current: AppVersion("2.1.0")!, now: now, in: defaults), "Version 2.2.0 is ready to install")
        UpdateStore.recordDownload(AppVersion("2.2.0")!, at: folder, in: defaults)
        XCTAssertEqual(UpdateStore.statusLine(current: AppVersion("2.1.0")!, now: now, in: defaults), "Version 2.2.0 is downloaded and ready")
    }
}
