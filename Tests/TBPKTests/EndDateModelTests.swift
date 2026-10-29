import XCTest
@testable import TBPK

@MainActor
final class EndDateModelTests: XCTestCase {
    private let calendar = Calendar.current
    private var defaults: UserDefaults!

    // 14:30 on a fixed day, so "today has time left" in every time zone.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 14, minute: 30, second: 20))!
    }

    override func setUp() { defaults = scratchDefaults("tbpk-enddate") }

    private func model(start: Date? = nil, now: Date? = nil) -> EndDateModel {
        EndDateModel(start: start, now: now ?? self.now, calendar: calendar, defaults: defaults)
    }

    func testItOpensOnHowLongWithAnHourSelected() throws {
        let m = model()
        XCTAssertEqual(m.mode, .duration)
        XCTAssertEqual(try XCTUnwrap(m.moment(now: now)).timeIntervalSince(now), 3_600, accuracy: 60)
        XCTAssertTrue(m.isChipSelected(EndDateModel.chips[1]))
    }

    func testASavedEndOpensOnItsOwnDayAndTime() throws {
        let saved = now.addingTimeInterval(30 * 3_600)
        let m = model(start: saved)
        XCTAssertEqual(m.mode, .time)
        XCTAssertEqual(try XCTUnwrap(m.moment(now: now)).timeIntervalSince(saved), 0, accuracy: 60)
    }

    func testASavedEndThatHasPassedIsPulledForward() throws {
        let m = model(start: now.addingTimeInterval(-5 * 3_600))
        XCTAssertTrue(m.isAhead(now: now))
    }

    func testEachChipFillsTheLengthWithTheMostNaturalUnit() {
        let m = model()
        m.applyChip(minutes: 30); XCTAssertEqual(m.amount, 30); XCTAssertEqual(m.unit, .minutes)
        m.applyChip(minutes: 240); XCTAssertEqual(m.amount, 4); XCTAssertEqual(m.unit, .hours)
        XCTAssertTrue(m.isChipSelected(EndDateModel.chips[3]))
        XCTAssertFalse(m.isChipSelected(EndDateModel.chips[0]))
        XCTAssertEqual(EndDateModel.split(minutes: 1_440).1, .days)
    }

    func testTypingAnyLengthMovesTheMomentAndClearsTheChipHighlight() throws {
        let m = model()
        m.amount = 90; m.unit = .minutes
        XCTAssertEqual(try XCTUnwrap(m.moment(now: now)).timeIntervalSince(now), 5_400, accuracy: 60)
        XCTAssertFalse(EndDateModel.chips.contains { m.isChipSelected($0) })
    }

    func testHoursAndMinutesAddUp() throws {
        let m = model()
        m.amount = 1; m.unit = .hours; m.extraMinutes = 30
        XCTAssertEqual(m.lengthMinutes, 90)
        XCTAssertEqual(try XCTUnwrap(m.moment(now: now)).timeIntervalSince(now), 5_400, accuracy: 60)
        XCTAssertEqual(m.pick(now: now), .duration(minutes: 90))
        XCTAssertFalse(EndDateModel.chips.contains { m.isChipSelected($0) })
        m.amount = 0; m.extraMinutes = 45
        XCTAssertEqual(try XCTUnwrap(m.moment(now: now)).timeIntervalSince(now), 2_700, accuracy: 60)
    }

    func testAChipClearsTheExtraMinutes() {
        let m = model()
        m.extraMinutes = 20
        m.applyChip(minutes: 120)
        XCTAssertEqual(m.extraMinutes, 0)
        XCTAssertTrue(m.isChipSelected(EndDateModel.chips[2]))
    }

    func testAnEmptyLengthIsNotAheadAndNegativesAreClamped() {
        let m = model()
        m.amount = 0; m.extraMinutes = 0; m.normalize(now: now)
        XCTAssertFalse(m.isAhead(now: now))
        XCTAssertNil(m.pick(now: now))
        m.amount = -4; m.extraMinutes = 75; m.normalize(now: now)
        XCTAssertEqual(m.amount, 0)
        XCTAssertEqual(m.extraMinutes, 59)
        m.amount = 100_000; m.normalize(now: now)
        XCTAssertEqual(m.amount, EndDateUnit.largestAmount)
    }

    func testTodayOffersOnlyTimesStillAhead() {
        let m = model()
        m.mode = .time
        m.chooseDay(offsetFrom: now, days: 0)
        XCTAssertEqual(m.hourRange(now: now), 14...23)
        XCTAssertEqual(m.availableClockHours(now: now), [18, 22])
        m.clockHour = 14
        m.normalize(now: now)
        XCTAssertEqual(m.minuteRange(now: now), 31...59)
        XCTAssertGreaterThanOrEqual(m.clockMinute, 31)
    }

    func testTomorrowOffersEveryHourAndMinute() {
        let m = model()
        m.mode = .time
        m.chooseDay(offsetFrom: now, days: 1)
        XCTAssertEqual(m.hourRange(now: now), 0...23)
        XCTAssertEqual(m.minuteRange(now: now), 0...59)
        XCTAssertEqual(m.availableClockHours(now: now), EndDateModel.clockHours)
    }

    func testAPastTimeTypedForTodayIsPulledToTheEarliestAheadAndNeverStaysSelected() {
        let m = model()
        m.mode = .time
        m.chooseDay(offsetFrom: now, days: 0)
        m.clockHour = 3; m.clockMinute = 10
        m.normalize(now: now)
        XCTAssertTrue(m.isAhead(now: now))
        XCTAssertEqual(m.clockHour, 14)
        XCTAssertEqual(m.clockMinute, 31)
    }

    func testAPastDayIsPulledToTheFirstSelectableDay() {
        let m = model()
        m.mode = .time
        m.day = calendar.date(byAdding: .day, value: -9, to: now)!
        m.normalize(now: now)
        XCTAssertTrue(calendar.isDate(m.day, inSameDayAs: now))
        XCTAssertTrue(m.isAhead(now: now))
    }

    func testWhenTodayHasRunOutTodayDisappearsAndTheFirstDayIsTomorrow() throws {
        let late = calendar.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: 23, minute: 59, second: 30))!
        let m = model(now: late)
        m.mode = .time
        m.normalize(now: late)
        XCTAssertFalse(m.isTodayAvailable(now: late))
        XCTAssertTrue(calendar.isDate(m.day, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: late)!))
        XCTAssertTrue(m.isAhead(now: late))
    }

    func testAnyLaterDateStaysSelectable() throws {
        let m = model()
        m.mode = .time
        m.chooseDay(offsetFrom: now, days: 200)
        m.clockHour = 9; m.clockMinute = 30
        m.normalize(now: now)
        let moment = try XCTUnwrap(m.moment(now: now))
        XCTAssertGreaterThan(moment.timeIntervalSince(now), 199 * 86_400)
        XCTAssertEqual(calendar.component(.hour, from: moment), 9)
    }

    func testAClockHourButtonSwitchesToTheTimeTab() {
        let m = model()
        m.applyClock(hour: 18, now: now)
        XCTAssertEqual(m.mode, .time)
        XCTAssertEqual(m.clockHour, 18)
        XCTAssertEqual(m.clockMinute, 0)
        XCTAssertTrue(m.isAhead(now: now))
    }

    func testTheConfirmButtonNamesTheMomentOrSaysPickOne() {
        XCTAssertTrue(model().confirmTitle(now: now).hasPrefix("Stay awake until "))
    }

    func testTheChosenTabIsRemembered() {
        let m = model()
        m.mode = .time
        m.remember(defaults: defaults)
        XCTAssertEqual(EndDateModel(start: nil, now: now, calendar: calendar, defaults: defaults).mode, .time)
    }
}
