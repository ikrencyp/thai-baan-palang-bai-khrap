import XCTest
@testable import TBPK

@MainActor
final class UpdateProgressPanelTests: XCTestCase {
    func testTheWindowIsSizedToItsWrappedTextSoNothingIsCutOff() throws {
        UpdateProgressPanel.show("Checking for updates…", detail: "Looking for the newest version. This usually takes a few seconds.")
        let long = try XCTUnwrap(UpdateProgressPanel.contentSize)
        UpdateProgressPanel.show("Checking for updates…", detail: "Short.")
        let short = try XCTUnwrap(UpdateProgressPanel.contentSize)
        UpdateProgressPanel.hide()
        XCTAssertGreaterThan(long.height, short.height, "a longer text gets a taller window, not a clipped one")
        XCTAssertGreaterThan(long.width, 300)
        XCTAssertEqual(long.width, short.width, accuracy: 1)
    }

    func testThePanelDoesNotHideItselfWhileTheAppIsNotActive() {
        UpdateProgressPanel.show("Checking for updates…", detail: "wait")
        defer { UpdateProgressPanel.hide() }
        XCTAssertTrue(UpdateProgressPanel.staysUpWhenInactive)
    }

    func testThePanelShowsWhileWorkingAndGoesAwayAfter() {
        UpdateProgressPanel.show("Checking for updates…", detail: "wait")
        XCTAssertTrue(UpdateProgressPanel.isShowing)
        UpdateProgressPanel.hide()
        XCTAssertFalse(UpdateProgressPanel.isShowing)
    }
}
