import XCTest
@testable import TBPK

final class SleepDisabledParsingTests: XCTestCase {
    func testKeyAbsentMeansOff() {
        let realCapture = """
        System-wide power settings:
        Currently in use:
         standby              1
         Sleep On Power Button 1
         disksleep            10
         sleep                1 (sleep prevented by coreaudiod, caffeinate, powerd)
         displaysleep         0
        """
        XCTAssertFalse(PrivilegedShell.sleepDisabledValue(in: realCapture))
    }

    func testEmptyOutputMeansOff() {
        XCTAssertFalse(PrivilegedShell.sleepDisabledValue(in: ""))
    }

    func testOneMeansOn() {
        XCTAssertTrue(PrivilegedShell.sleepDisabledValue(in: " SleepDisabled        1\n"))
    }

    func testZeroMeansOff() {
        XCTAssertFalse(PrivilegedShell.sleepDisabledValue(in: " SleepDisabled        0\n"))
    }

    func testTrailingAnnotationIsIgnored() {
        XCTAssertTrue(PrivilegedShell.sleepDisabledValue(in: " SleepDisabled        1 (sleep prevented by foo)\n"))
    }

    func testSimilarKeysDoNotMatch() {
        XCTAssertFalse(PrivilegedShell.sleepDisabledValue(in: " disksleep 1\n sleep 1\n displaysleep 1\n Sleep On Power Button 1\n"))
    }

    func testSingleSpaceSeparator() {
        XCTAssertTrue(PrivilegedShell.sleepDisabledValue(in: " SleepDisabled 1\n"))
    }
}
