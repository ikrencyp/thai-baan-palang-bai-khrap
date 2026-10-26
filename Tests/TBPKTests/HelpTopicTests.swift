import XCTest
@testable import TBPK

final class HelpTopicTests: XCTestCase {
    func testEveryTopMenuEntryHasAHelpCard() {
        let titles = HelpTopic.menu.map(\.title)
        for entry in ["Keep this Mac awake", "Stay awake for", "Alerts", "Power rules", "Look present at the screen", "Energy use", "Settings", "What\u{2019}s new"] {
            XCTAssertTrue(titles.contains(entry), entry)
        }
    }

    func testCardIdsAreUniqueAndFilled() {
        XCTAssertEqual(Set(HelpTopic.menu.map(\.id)).count, HelpTopic.menu.count)
        for topic in HelpTopic.menu { XCTAssertFalse(topic.summary.isEmpty); XCTAssertFalse(topic.detail.isEmpty) }
    }

    func testTheVersionLineNamesTheAppAndAVersion() {
        XCTAssertTrue(AppInfo.versionLine.hasPrefix("TBPK "))
        XCTAssertFalse(AppInfo.version.isEmpty)
    }
}
