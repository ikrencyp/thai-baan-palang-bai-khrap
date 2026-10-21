import XCTest
@testable import TBPK

final class AppVersionTests: XCTestCase {
    func testNewerVersionsCompareAsNumbersNotText() {
        XCTAssertTrue(AppVersion("2.0.0")! < AppVersion("2.0.1")!)
        XCTAssertTrue(AppVersion("2.9.0")! < AppVersion("2.10.0")!)
        XCTAssertTrue(AppVersion("2.0")! == AppVersion("2.0.0")! || AppVersion("2.0")! >= AppVersion("2.0.0")!)
        XCTAssertFalse(AppVersion("2.0.0")! < AppVersion("2.0.0")!)
        XCTAssertTrue(AppVersion("1.3.0")! < AppVersion("2.0.0")!)
    }

    func testTextThatIsNotAVersionIsRefused() {
        XCTAssertNil(AppVersion(""))
        XCTAssertNil(AppVersion("2.x.0"))
        XCTAssertNil(AppVersion("2..0"))
        XCTAssertNil(AppVersion("-1.0.1"), "a negative part is not a version")
        XCTAssertNil(AppVersion("1.-2.0"))
    }
}
