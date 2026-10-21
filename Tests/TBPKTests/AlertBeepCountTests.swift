import XCTest
@testable import TBPK

final class AlertBeepCountTests: XCTestCase {
    private var defaults: UserDefaults!
    private let ding = AlertSound(name: "Ping")
    private let mine = AlertSound(name: AlertSound.customPrefix + "tune.wav")

    override func setUp() {
        defaults = scratchDefaults("tbpk-beep")
    }

    func testBuiltInSoundsStartAtFiveAndYourOwnFileAtOne() {
        XCTAssertEqual(AlertBeepCount.stored(for: ding, in: defaults), .five)
        XCTAssertEqual(AlertBeepCount.stored(for: .systemAlert, in: defaults), .five)
        XCTAssertEqual(AlertBeepCount.stored(for: mine, in: defaults), .one)
    }

    func testEachSoundRemembersItsOwnCount() {
        AlertBeepCount.store(.twenty, for: ding, in: defaults)
        AlertBeepCount.store(.three, for: mine, in: defaults)
        XCTAssertEqual(AlertBeepCount.stored(for: ding, in: defaults), .twenty)
        XCTAssertEqual(AlertBeepCount.stored(for: mine, in: defaults), .three)
        XCTAssertEqual(AlertBeepCount.stored(for: .systemAlert, in: defaults), .five)
    }

    func testForgettingASoundBringsBackItsDefault() {
        AlertBeepCount.store(.twenty, for: mine, in: defaults)
        AlertBeepCount.forget(mine, in: defaults)
        XCTAssertEqual(AlertBeepCount.stored(for: mine, in: defaults), .one)
    }

    func testSharedModeUsesOneCountForEverySound() {
        AlertBeepCount.setShared(true, in: defaults)
        XCTAssertEqual(AlertBeepCount.stored(for: mine, in: defaults), .five)
        AlertBeepCount.store(.ten, for: ding, in: defaults)
        XCTAssertEqual(AlertBeepCount.stored(for: mine, in: defaults), .ten)
        XCTAssertEqual(AlertBeepCount.stored(for: .systemAlert, in: defaults), .ten)
    }

    func testLeavingSharedModeKeepsEachSoundsOwnEarlierCount() {
        AlertBeepCount.store(.three, for: ding, in: defaults)
        AlertBeepCount.setShared(true, in: defaults)
        AlertBeepCount.store(.twenty, for: mine, in: defaults)
        AlertBeepCount.setShared(false, in: defaults)
        XCTAssertEqual(AlertBeepCount.stored(for: ding, in: defaults), .three)
        XCTAssertEqual(AlertBeepCount.stored(for: mine, in: defaults), .one)
    }

    func testAnUnknownStoredNumberFallsBackToTheDefault() {
        defaults.set([ding.name: 99], forKey: AlertBeepCount.perSoundKey)
        XCTAssertEqual(AlertBeepCount.stored(for: ding, in: defaults), .five)
        AlertBeepCount.setShared(true, in: defaults)
        defaults.set("x", forKey: AlertBeepCount.storageKey)
        XCTAssertEqual(AlertBeepCount.stored(for: ding, in: defaults), .five)
    }

    func testTheChoicesAreOneThreeFiveTenTwenty() {
        XCTAssertEqual(AlertBeepCount.allCases.map(\.rawValue), [1, 3, 5, 10, 20])
    }
}
