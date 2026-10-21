import AppKit
import XCTest
@testable import TBPK

@MainActor
final class MenuSubtitleTests: XCTestCase {
    func testTheSubtitleIsSetThroughKeyValueCodingWhereTheMacHasIt() throws {
        let item = NSMenuItem(title: "Mac sounds", action: nil, keyEquivalent: "")
        try XCTSkipUnless(item.responds(to: NSSelectorFromString("setSubtitle:")), "NSMenuItem has no subtitle before macOS 14.4")
        MenuParts.setSubtitle("System alert", on: item)
        XCTAssertEqual(item.value(forKey: "subtitle") as? String, "System alert")
    }

    func testOnAMacWithoutSubtitlesNothingHappensAndNothingCrashes() {
        let item = NSMenuItem(title: "Mac sounds", action: nil, keyEquivalent: "")
        MenuParts.setSubtitle("System alert", on: item)
        XCTAssertEqual(item.title, "Mac sounds")
    }
}
