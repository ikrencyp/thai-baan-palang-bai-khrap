import XCTest
@testable import TBPK

final class UpdateStoreTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() { defaults = scratchDefaults("tbpk-update") }

    func testTheDefaultsAreLookAndDownloadButNeverInstallBehindYourBack() {
        XCTAssertTrue(UpdateStore.checksAutomatically(in: defaults))
        XCTAssertTrue(UpdateStore.downloadsAutomatically(in: defaults))
        XCTAssertFalse(UpdateStore.installsAutomatically(in: defaults))
    }

    func testEachSwitchOnlyCountsWhileTheOnesBeforeItAreOn() {
        UpdateStore.set(UpdateStore.installAutomaticallyKey, true, in: defaults)
        XCTAssertTrue(UpdateStore.installsAutomatically(in: defaults))
        UpdateStore.set(UpdateStore.downloadAutomaticallyKey, false, in: defaults)
        XCTAssertFalse(UpdateStore.installsAutomatically(in: defaults))
        UpdateStore.set(UpdateStore.downloadAutomaticallyKey, true, in: defaults)
        UpdateStore.set(UpdateStore.checkAutomaticallyKey, false, in: defaults)
        XCTAssertFalse(UpdateStore.downloadsAutomatically(in: defaults))
        XCTAssertFalse(UpdateStore.installsAutomatically(in: defaults))
    }

    func testManualOnlyNeverChecksOnItsOwn() {
        UpdateStore.set(UpdateStore.checkAutomaticallyKey, false, in: defaults)
        XCTAssertFalse(UpdateStore.isDue(in: defaults))
    }

    func testADownloadIsRememberedForItsVersionWhileTheFolderExists() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("tbpk-dl-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let version = AppVersion("2.3.0")!
        UpdateStore.recordDownload(version, at: folder, in: defaults)
        XCTAssertEqual(UpdateStore.downloadedRoot(for: version, in: defaults)?.path, folder.path)
        XCTAssertNil(UpdateStore.downloadedRoot(for: AppVersion("2.4.0")!, in: defaults))
        XCTAssertEqual(UpdateStore.clearDownload(in: defaults)?.path, folder.path)
        XCTAssertNil(UpdateStore.downloadedRoot(for: version, in: defaults))
        UpdateStore.recordDownload(version, at: folder, in: defaults)
        try FileManager.default.removeItem(at: folder)
        XCTAssertNil(UpdateStore.downloadedRoot(for: version, in: defaults), "a deleted folder is not a download")
    }

    func testACheckIsDueEverySixHoursAfterTheLastAttempt() {
        let now = Date()
        XCTAssertTrue(UpdateStore.isDue(now: now, in: defaults))
        UpdateStore.recordFailure(now: now, in: defaults)
        XCTAssertFalse(UpdateStore.isDue(now: now.addingTimeInterval(3600), in: defaults))
        XCTAssertTrue(UpdateStore.isDue(now: now.addingTimeInterval(UpdateStore.checkInterval), in: defaults))
    }

    func testAMacThatNeverReachedTheRepositoryHidesTheUpdateItems() {
        XCTAssertTrue(UpdateStore.isOfferedHere(in: defaults))
        UpdateStore.recordFailure(in: defaults)
        XCTAssertFalse(UpdateStore.isOfferedHere(in: defaults))
        UpdateStore.record(found: nil, in: defaults)
        XCTAssertTrue(UpdateStore.isOfferedHere(in: defaults))
    }

    func testAMacThatReachedItOnceKeepsTheItemsWhenOffline() {
        UpdateStore.record(found: nil, in: defaults)
        UpdateStore.recordFailure(in: defaults)
        XCTAssertTrue(UpdateStore.isOfferedHere(in: defaults))
        XCTAssertTrue(UpdateStore.hasReachedRepository(in: defaults))
    }

    func testAFoundVersionIsPendingUntilTheAppCatchesUp() {
        UpdateStore.record(found: AppVersion("2.1.0"), in: defaults)
        XCTAssertEqual(UpdateStore.pending(current: AppVersion("2.0.0")!, in: defaults)?.text, "2.1.0")
        XCTAssertNil(UpdateStore.pending(current: AppVersion("2.1.0")!, in: defaults))
        UpdateStore.record(found: nil, in: defaults)
        XCTAssertNil(UpdateStore.pending(current: AppVersion("2.0.0")!, in: defaults))
    }

    func testTheAssetsOfTheWaitingReleaseAreKeptAndClearedWithIt() throws {
        let assets = (dmg: try XCTUnwrap(URL(string: "https://github.com/x/y/releases/download/v2.4.0/TBPK-2.4.0.dmg")),
                      checksum: try XCTUnwrap(URL(string: "https://github.com/x/y/releases/download/v2.4.0/TBPK-2.4.0.dmg.sha256")))
        UpdateStore.record(found: AppVersion("2.4.0"), assets: assets, in: defaults)
        XCTAssertEqual(UpdateStore.availableAssets(in: defaults)?.dmg, assets.dmg)
        XCTAssertEqual(UpdateStore.availableAssets(in: defaults)?.checksum, assets.checksum)
        UpdateStore.record(found: nil, assets: assets, in: defaults)
        XCTAssertNil(UpdateStore.availableAssets(in: defaults))
    }

    func testTheNotesOfTheFoundVersionAreKeptAndClearedWithIt() {
        UpdateStore.record(found: AppVersion("2.1.0"), notes: "• one", in: defaults)
        XCTAssertEqual(UpdateStore.pendingNotes(in: defaults), "• one")
        UpdateStore.record(found: nil, notes: "• one", in: defaults)
        XCTAssertNil(UpdateStore.pendingNotes(in: defaults))
    }
}
