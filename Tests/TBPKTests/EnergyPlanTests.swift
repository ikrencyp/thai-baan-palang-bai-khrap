import AppKit
import XCTest
@testable import TBPK

final class EnergyPlanTests: XCTestCase {
    private typealias Conditions = EnergyPlan.Conditions

    func testAutomaticIsCalmOnTheChargerAndStillWhenMacOSAsksToSave() {
        XCTAssertEqual(EnergyPlan.resolve(.automatic, Conditions()), .standard)
        XCTAssertEqual(EnergyPlan.resolve(.automatic, Conditions(onBattery: true)), .saver)
        XCTAssertEqual(EnergyPlan.resolve(.automatic, Conditions(lowPowerMode: true)), .saver)
        XCTAssertEqual(EnergyPlan.resolve(.automatic, Conditions(reduceMotion: true)), .saver)
    }

    func testAFixedChoiceIgnoresWhatMacOSSays() {
        let everything = Conditions(onBattery: true, lowPowerMode: true, reduceMotion: true)
        XCTAssertEqual(EnergyPlan.resolve(.full, everything), .full)
        XCTAssertEqual(EnergyPlan.resolve(.saver, Conditions()), .saver)
    }

    func testNothingIsDrawnWhileTheDisplayIsAsleepWhateverTheChoice() {
        for profile in EnergyProfile.allCases {
            let plan = EnergyPlan.resolve(profile, Conditions(displayAsleep: true))
            XCTAssertFalse(plan.isVisible, profile.title)
            XCTAssertNil(plan.beatEvery, profile.title)
            XCTAssertFalse(plan.animatesTransitions, profile.title)
        }
    }

    func testTheDisplayAsleepKeepsTheSafetyChecksOfTheChoice() {
        let asleep = EnergyPlan.resolve(.full, Conditions(displayAsleep: true))
        XCTAssertEqual(asleep.governorTick, EnergyPlan.full.governorTick)
        XCTAssertEqual(asleep.idleWatchTick, EnergyPlan.full.idleWatchTick)
    }

    func testEachStepDownWakesTheAppLessOften() {
        let steps = [EnergyPlan.full, .standard, .saver]
        XCTAssertEqual(steps.map(\.governorTick), steps.map(\.governorTick).sorted())
        XCTAssertEqual(steps.map(\.syncTick), steps.map(\.syncTick).sorted())
        XCTAssertEqual(steps.map(\.idleWatchTick), steps.map(\.idleWatchTick).sorted())
        XCTAssertTrue(EnergyPlan.saver.coarseCountdown)
        XCTAssertFalse(EnergyPlan.standard.coarseCountdown)
    }

    func testTheSafetyNetNeverWaitsLongerThanFiveSeconds() {
        for plan in [EnergyPlan.full, .standard, .saver] { XCTAssertLessThanOrEqual(plan.idleWatchTick, 5) }
    }

    func testTheSummaryNamesWhatYouSee() {
        XCTAssertEqual(EnergyPlan.full.summary, "Continuous heartbeat")
        XCTAssertEqual(EnergyPlan.standard.summary, "Calm heartbeat")
        XCTAssertEqual(EnergyPlan.saver.summary, "Still leaf")
        XCTAssertEqual(EnergyPlan.resolve(.full, Conditions(displayAsleep: true)).summary, "Paused while the display is asleep")
    }

    // The leaf used to be redrawn 30 times a second for as long as the Mac was awake. Frames drawn over a minute,
    // counting one per 1/30 s while a beat is on screen and none while it rests.
    private func framesPerSecond(_ plan: EnergyPlan) -> Double {
        guard let gap = plan.beatEvery else { return 0 }
        let step = 1 / plan.frameRate
        let seconds = 360.0
        let frames = stride(from: 0.0, to: seconds, by: step).filter { Heartbeat.isBeating(at: $0, every: gap) }.count
        return Double(frames) / seconds
    }

    func testFramesDrawnWhileAwakeFallFromThirtyToAboutFifteenFourAndZero() {
        XCTAssertEqual(framesPerSecond(.full), 15, accuracy: 1)
        XCTAssertEqual(framesPerSecond(.standard), 3.75, accuracy: 0.5)
        XCTAssertEqual(framesPerSecond(.saver), 0)
    }
}
