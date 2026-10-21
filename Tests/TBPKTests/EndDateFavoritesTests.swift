import XCTest
@testable import TBPK

@MainActor
final class EndDateFavoritesTests: XCTestCase {
    private let calendar = Calendar.current
    private var defaults: UserDefaults!
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 14, minute: 30))!
    }

    override func setUp() { defaults = scratchDefaults("tbpk-fav") }

    func testAPickSurvivesItsKeyAndNamesItself() {
        for pick in [EndDatePick.duration(minutes: 180), .duration(minutes: 90), .duration(minutes: 2_880), .clock(hour: 6, minute: 5)] {
            XCTAssertEqual(EndDatePick(key: pick.key), pick)
        }
        XCTAssertEqual(EndDatePick.duration(minutes: 180).label, "For 3 hours")
        XCTAssertEqual(EndDatePick.duration(minutes: 60).label, "For 1 hour")
        XCTAssertEqual(EndDatePick.duration(minutes: 45).label, "For 45 min")
        XCTAssertEqual(EndDatePick.duration(minutes: 90).label, "For 1 h 30 min")
        XCTAssertEqual(EndDatePick.duration(minutes: 2_880).label, "For 2 days")
        XCTAssertEqual(EndDatePick.clock(hour: 6, minute: 5).label, "Until 06:05")
        XCTAssertNil(EndDatePick(key: "c:25:00"))
        XCTAssertNil(EndDatePick(key: "d:0"))
        XCTAssertNil(EndDatePick(key: "junk"))
    }

    func testTheTopThreeAreTheMostChosenAndTiesGoToTheNewest() {
        func use(_ pick: EndDatePick, times: Int, at offset: TimeInterval) {
            for _ in 0..<times { EndDateFavorites.record(pick, now: now.addingTimeInterval(offset), in: defaults) }
        }
        use(.duration(minutes: 180), times: 5, at: 0)
        use(.clock(hour: 18, minute: 0), times: 3, at: 10)
        use(.clock(hour: 22, minute: 0), times: 1, at: 20)
        use(.duration(minutes: 90), times: 1, at: 30)
        use(.clock(hour: 7, minute: 30), times: 1, at: 5)
        XCTAssertEqual(EndDateFavorites.top(in: defaults),
                       [.duration(minutes: 180), .clock(hour: 18, minute: 0), .duration(minutes: 90)])
    }

    func testALengthThatIsAlreadyInTheMenuIsNotRemembered() {
        EndDateFavorites.record(.duration(minutes: 240), in: defaults)
        EndDateFavorites.record(.duration(minutes: 30), in: defaults)
        XCTAssertTrue(EndDateFavorites.top(in: defaults).isEmpty)
    }

    func testClearingForgetsEverything() {
        EndDateFavorites.record(.duration(minutes: 180), in: defaults)
        EndDateFavorites.clear(in: defaults)
        XCTAssertTrue(EndDateFavorites.top(in: defaults).isEmpty)
        EndDateFavorites.record(.duration(minutes: 90), in: defaults)
        XCTAssertEqual(EndDateFavorites.top(in: defaults), [.duration(minutes: 90)])
    }

    func testOnlyTwentyAreKept() {
        for minute in 1...30 { EndDateFavorites.record(.duration(minutes: 1_000 + minute), now: now.addingTimeInterval(Double(minute)), in: defaults) }
        XCTAssertEqual((defaults.dictionary(forKey: EndDateFavorites.storageKey) ?? [:]).count, 20)
    }

    func testAClockPickComesRoundAtTheNextOccurrence() {
        let tonight = EndDatePick.clock(hour: 18, minute: 0).moment(now: now, calendar: calendar)
        XCTAssertEqual(calendar.component(.day, from: tonight), 21)
        let tomorrow = EndDatePick.clock(hour: 6, minute: 0).moment(now: now, calendar: calendar)
        XCTAssertEqual(calendar.component(.day, from: tomorrow), 22)
        XCTAssertEqual(EndDatePick.duration(minutes: 180).moment(now: now).timeIntervalSince(now), 10_800, accuracy: 1)
    }

    func testTheWindowRemembersALengthOrAClockWithinADayButNotADateDaysAway() {
        let model = EndDateModel(start: nil, now: now, calendar: calendar, defaults: defaults)
        model.applyChip(minutes: 180)
        XCTAssertEqual(model.pick(now: now), .duration(minutes: 180))
        model.applyClock(hour: 18, now: now)
        XCTAssertEqual(model.pick(now: now), .clock(hour: 18, minute: 0))
        model.chooseDay(offsetFrom: now, days: 5)
        XCTAssertNil(model.pick(now: now))
    }
}
