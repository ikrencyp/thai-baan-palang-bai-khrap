import XCTest
@testable import TBPK

final class ReleasePagerTests: XCTestCase {
    private func releases(_ count: Int) -> [Release] { (1...max(count, 1)).prefix(count).map { Release(version: "1.\($0).0", lines: ["x"]) } }

    func testAShortListIsOnePageWithNoControls() {
        let pager = ReleasePager(releases: releases(3))
        XCTAssertEqual(pager.pageCount, 1)
        XCTAssertEqual(pager.current.count, 3)
        XCTAssertFalse(pager.hasNewer)
        XCTAssertFalse(pager.hasOlder)
    }

    func testALongListIsCutIntoPagesOfThreeAndWalkedBothWays() {
        var pager = ReleasePager(releases: releases(8))
        XCTAssertEqual(pager.pageCount, 3)
        XCTAssertEqual(pager.caption, "Page 1 of 3")
        XCTAssertEqual(pager.current.map(\.version), ["1.1.0", "1.2.0", "1.3.0"])
        pager.showOlder(); pager.showOlder()
        XCTAssertEqual(pager.current.map(\.version), ["1.7.0", "1.8.0"])
        XCTAssertFalse(pager.hasOlder)
        pager.showOlder()
        XCTAssertEqual(pager.caption, "Page 3 of 3")
        pager.showNewer()
        XCTAssertEqual(pager.caption, "Page 2 of 3")
    }

    func testAnEmptyListStillHasOnePage() {
        let pager = ReleasePager(releases: [])
        XCTAssertEqual(pager.pageCount, 1)
        XCTAssertTrue(pager.current.isEmpty)
    }

    func testTheRealChangelogHasAtLeastOneRelease() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let all = ReleaseNotes.all(in: try String(contentsOf: root.appendingPathComponent("CHANGELOG.md"), encoding: .utf8))
        XCTAssertFalse(all.isEmpty)
    }
}
