import XCTest
@testable import TBPK

final class ReleaseNotesTests: XCTestCase {
    func testTheFirstBulletsOfAReleaseBodyComeBackAsBullets() {
        let body = "## What's new\n- one\n* two\nprose\n- three\n- four\n- five\n"
        XCTAssertEqual(ReleaseNotes.summary(ofReleaseBody: body), "• one\n• two\n• three\n• four")
        XCTAssertEqual(ReleaseNotes.summary(ofReleaseBody: body, maxLines: 1), "• one")
    }

    func testABodyWithoutBulletsHasNoNotes() {
        XCTAssertNil(ReleaseNotes.summary(ofReleaseBody: "Just prose."))
        XCTAssertNil(ReleaseNotes.summary(ofReleaseBody: ""))
    }
}
