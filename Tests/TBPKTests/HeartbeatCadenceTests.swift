import AppKit
import XCTest
@testable import TBPK

final class HeartbeatCadenceTests: XCTestCase {
    func testTheBeatRepeatsEveryGapAndRestsBetween() {
        let gap = 3.6
        XCTAssertEqual(Heartbeat.pulse(at: 0.12 * Heartbeat.period, every: gap), Heartbeat.pulse(at: 0.12 * Heartbeat.period), accuracy: 1e-9)
        XCTAssertEqual(Heartbeat.pulse(at: 0.12 * Heartbeat.period + gap, every: gap), Heartbeat.pulse(at: 0.12 * Heartbeat.period), accuracy: 1e-9)
        XCTAssertEqual(Heartbeat.pulse(at: 2, every: gap), 0)
        XCTAssertTrue(Heartbeat.isBeating(at: 0.2, every: gap))
        XCTAssertFalse(Heartbeat.isBeating(at: 0.5, every: gap))
    }

    func testTheRestEndsExactlyWhenTheNextBeatStarts() {
        let gap = 3.6
        XCTAssertEqual(Heartbeat.restLeft(at: 0.5, every: gap), 3.1, accuracy: 1e-9)
        XCTAssertEqual(Heartbeat.restLeft(at: gap + 1, every: gap), 2.6, accuracy: 1e-9)
    }

    func testAGapShorterThanTheNaturalBeatIsStretchedToIt() {
        XCTAssertEqual(Heartbeat.pulse(at: 0.1, every: 0.2), Heartbeat.pulse(at: 0.1), accuracy: 1e-9)
        XCTAssertEqual(Heartbeat.restLeft(at: 0.5, every: 0.1), Heartbeat.period - 0.5, accuracy: 1e-9)
    }

    func testBetweenTheBeatsTheLeafIsAtRest() {
        for time in stride(from: Heartbeat.activeLength, to: Heartbeat.period, by: 0.05) {
            XCTAssertEqual(Heartbeat.pulse(at: time, every: Heartbeat.period), 0)
        }
        XCTAssertLessThan(Heartbeat.pulse(at: Heartbeat.activeLength - 0.0001), 0.06, "the cut-off is where the beat has already faded")
    }
}
