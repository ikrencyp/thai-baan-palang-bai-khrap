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

    func testInstallStepsTickTheFinishedOnesAndMarkTheCurrentOne() {
        let texts = UpdateProgressPanel.Step.allCases.map { UpdateProgressPanel.stepText($0, current: .prepare).string }
        XCTAssertEqual(texts, ["\u{2713} Download", "\u{25CF} Prepare", "\u{25CB} Install and restart"])
    }

    func testTheStepRowMakesTheWindowTallerAndDisappearsWithoutAStep() throws {
        UpdateProgressPanel.show("Installing", detail: "wait")
        let plain = try XCTUnwrap(UpdateProgressPanel.contentSize)
        UpdateProgressPanel.show("Installing", detail: "wait", step: .install)
        let stepped = try XCTUnwrap(UpdateProgressPanel.contentSize)
        UpdateProgressPanel.hide()
        XCTAssertGreaterThan(stepped.height, plain.height)
    }
}
