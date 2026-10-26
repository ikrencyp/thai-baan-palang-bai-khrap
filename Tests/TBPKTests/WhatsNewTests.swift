import XCTest
@testable import TBPK

@MainActor
final class WhatsNewTests: XCTestCase {
    private let log = "# Changelog\n\nintro\n\n## 2.1.0 - May\n- one\n- two\nprose\n\n## 2.0.0\n- old\n\n## 1.0.0\nnothing here\n"

    func testEverySectionWithBulletsIsListedNewestFirst() {
        XCTAssertEqual(ReleaseNotes.all(in: log), [Release(version: "2.1.0", lines: ["one", "two"]), Release(version: "2.0.0", lines: ["old"])])
    }

    func testAFindItLineIsKeptApartFromTheChanges() {
        let text = "## 1.1.0\n- one\n- Find it: Power rules > Screen\n- two\n"
        XCTAssertEqual(ReleaseNotes.all(in: text), [Release(version: "1.1.0", lines: ["one", "two"], findIt: "Power rules > Screen")])
    }

    func testEveryFindItPathOfTheChangelogStartsAtAMenuEntry() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let changelog = try String(contentsOf: root.appendingPathComponent("CHANGELOG.md"), encoding: .utf8)
        let menu = StatusMenuBuilder.build(power: PowerManager.shared, watch: UnattendedWatch(power: PowerManager.shared), target: StubMenuTarget())
        let titles = menu.items.map(\.title)
        for path in ReleaseNotes.all(in: changelog).compactMap(\.findIt) {
            XCTAssertTrue(titles.contains(path.components(separatedBy: " > ")[0]), path)
        }
    }

    func testAFindItLineStaysOutOfTheUpdateDialog() {
        XCTAssertEqual(ReleaseNotes.summary(ofReleaseBody: "- one\n- Find it: Power rules\n- two"), "\u{2022} one\n\u{2022} two")
    }

    func testTheListOpensOnceAfterAnUpdateButNotOnAFirstInstall() {
        let defaults = scratchDefaults("tbpk-whatsnew")
        XCTAssertFalse(WhatsNewWindow.shouldShowAtLaunch(current: "2.2.0", in: defaults))
        XCTAssertFalse(WhatsNewWindow.shouldShowAtLaunch(current: "2.2.0", in: defaults))
        XCTAssertTrue(WhatsNewWindow.shouldShowAtLaunch(current: "2.3.0", in: defaults))
        XCTAssertFalse(WhatsNewWindow.shouldShowAtLaunch(current: "2.3.0", in: defaults))
    }

    func testTheChangelogOfThisRepositoryStartsWithTheVersionFileDeclares() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let changelog = try String(contentsOf: root.appendingPathComponent("CHANGELOG.md"), encoding: .utf8)
        let declared = try XCTUnwrap(AppVersion(String(contentsOf: root.appendingPathComponent("VERSION"), encoding: .utf8)))
        XCTAssertEqual(ReleaseNotes.all(in: changelog).first?.version, declared.text)
        XCTAssertEqual(AppInfo.fallbackVersion, declared.text)
    }
}
