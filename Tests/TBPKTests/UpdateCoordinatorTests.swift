import XCTest
@testable import TBPK

// "Update to <version> now" names the version found earlier. A newer release may have come out since, so pressing it
// must look again and offer the newest, not install the old find and leave a second update to do.
@MainActor
final class UpdateCoordinatorTests: XCTestCase {
    private var savedKeys: [String: Any] = [:]

    // The coordinator keeps its state in the standard defaults, so the update keys are put back as they were.
    override func setUp() {
        super.setUp()
        savedKeys = UserDefaults.standard.dictionaryRepresentation().filter { $0.key.hasPrefix("update") }
    }

    override func tearDown() {
        let defaults = UserDefaults.standard
        defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("update") }.forEach(defaults.removeObject(forKey:))
        savedKeys.forEach { defaults.set($1, forKey: $0) }
        super.tearDown()
    }

    private func release(_ text: String) -> UpdateSource.Latest {
        let base = URL(string: "https://github.com/ikrencyp/thai-baan-palang-bai-khrap/releases/download/v\(text)/")!
        return UpdateSource.Latest(version: AppVersion(text)!, tag: "v\(text)", notes: nil,
                                   dmg: base.appendingPathComponent("TBPK-\(text).dmg"),
                                   checksum: base.appendingPathComponent("TBPK-\(text).dmg.sha256"))
    }

    private func offered(after lookup: UpdateSource.Lookup, earlierFind: String) async -> [String] {
        let earlier = release(earlierFind)
        UpdateStore.record(found: earlier.version, notes: nil, assets: (earlier.dmg, earlier.checksum))
        let coordinator = UpdateCoordinator()
        coordinator.lookUp = { lookup }
        var versions: [String] = []
        let done = expectation(description: "a version is offered")
        coordinator.offer = { version in
            versions.append(version)
            done.fulfill()
        }
        coordinator.installPending()
        await fulfillment(of: [done], timeout: 10)
        return versions
    }

    func testPressingUpdateOffersTheNewestEvenWhenAnOlderOneWasFoundEarlier() async {
        let newest = release("99.0.0")
        let versions = await offered(after: .found(newest), earlierFind: "98.0.0")
        XCTAssertEqual(versions, ["99.0.0"])
    }

    func testOfflinePressingUpdateStillOffersTheVersionFoundEarlier() async {
        let versions = await offered(after: .unreachable, earlierFind: "98.0.0")
        XCTAssertEqual(versions, ["98.0.0"])
    }

    // A release is only offered once its signature is attached, so for a few minutes the newest one is "no release".
    func testPressingUpdateWhileTheNewestReleaseIsNotSignedYetStillOffersTheEarlierFindAndKeepsItsDownloadLinks() async {
        let versions = await offered(after: .noRelease, earlierFind: "98.0.0")
        XCTAssertEqual(versions, ["98.0.0"])
        XCTAssertEqual(UpdateStore.availableAssets()?.dmg.lastPathComponent, "TBPK-98.0.0.dmg")
    }
}
