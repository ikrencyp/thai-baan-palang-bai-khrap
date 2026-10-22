import XCTest
@testable import TBPK

@MainActor
final class CountdownTickerTests: XCTestCase {
    private func run(for seconds: TimeInterval, during work: () -> Void = {}) {
        work()
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    func testItKeepsTickingEverySecondNotJustOnce() {
        let end = Date().addingTimeInterval(60.4)
        var shown: [String] = []
        let ticker = CountdownTicker(remaining: { end.timeIntervalSinceNow }, show: { shown.append(ClockText.short(end.timeIntervalSinceNow)) })
        run(for: 4.3) { ticker.sync() }
        ticker.stop()
        XCTAssertGreaterThanOrEqual(shown.count, 4, "ticks seen: \(shown)")
        let seconds = shown.compactMap { Int($0.split(separator: ":").last ?? "") }
        for pair in zip(seconds, seconds.dropFirst()) { XCTAssertEqual((pair.0 - pair.1 + 60) % 60, 1, "\(shown)") }
    }

    func testCallingSyncOftenBetweenTicksNeitherStallsNorDoublesIt() {
        let end = Date().addingTimeInterval(60.4)
        var ticks = 0
        let ticker = CountdownTicker(remaining: { end.timeIntervalSinceNow }, show: { ticks += 1 })
        ticker.sync()
        let nagger = Timer(timeInterval: 0.13, repeats: true) { _ in MainActor.assumeIsolated { ticker.sync() } }
        RunLoop.main.add(nagger, forMode: .common)
        run(for: 4.3)
        nagger.invalidate()
        ticker.stop()
        XCTAssertGreaterThanOrEqual(ticks, 4)
        XCTAssertLessThanOrEqual(ticks, 5)
    }

    func testItStopsWhenThereIsNothingToCountAndStartsAgainOnSync() {
        var left: TimeInterval? = nil
        var ticks = 0
        let ticker = CountdownTicker(remaining: { left }, show: { ticks += 1 })
        ticker.sync()
        XCTAssertFalse(ticker.isRunning)
        left = 30.2
        ticker.sync()
        XCTAssertTrue(ticker.isRunning)
        run(for: 1.4)
        XCTAssertGreaterThanOrEqual(ticks, 1)
        left = nil
        ticker.sync()
        let after = ticks
        run(for: 1.3)
        XCTAssertEqual(ticks, after, "no tick once there is nothing to count")
        XCTAssertFalse(ticker.isRunning)
    }
}
