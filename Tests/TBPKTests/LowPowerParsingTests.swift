import XCTest
@testable import TBPK

final class LowPowerParsingTests: XCTestCase {
    private let sample = """
    Battery Power:
     lowpowermode         1
     sleep                1
    AC Power:
     lowpowermode         0
    """

    func testReadsTheBatterySectionNotTheChargerSection() {
        XCTAssertEqual(PrivilegedShell.lowPowerValue(in: sample), true)
        XCTAssertEqual(PrivilegedShell.lowPowerValue(in: sample.replacingOccurrences(of: "lowpowermode         1", with: "lowpowermode         0")), false)
    }

    func testAMacWithoutTheSettingReadsAsUnknown() {
        XCTAssertNil(PrivilegedShell.lowPowerValue(in: "Battery Power:\n sleep 1\nAC Power:\n lowpowermode 1\n"))
    }

    func testTheSudoersRuleCoversTheBatteryLowPowerCommands() {
        let rule = ElevatedInstallCommand.ruleLine(for: "me")
        XCTAssertTrue(rule.contains("/usr/bin/pmset -b lowpowermode 1"))
        XCTAssertTrue(rule.contains("/usr/bin/pmset -b lowpowermode 0"))
    }
}
