import XCTest
@testable import TBPK

final class EndDateTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 7 * 3600) ?? .current
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
        let parts = DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute, second: second)
        return calendar.date(from: parts) ?? Date()
    }

    func testCombineTakesTheDayFromTheCalendarAndTheClockFromTheTimeField() {
        let combined = EndDateMoment.combine(day: date(21, 23, 59, 30), time: date(1, 8, 5, 40), calendar: calendar)
        XCTAssertEqual(combined, date(21, 8, 5))
    }

    func testDescribeNamesTodayAndTomorrowAndOtherwiseTheWeekday() {
        let now = date(20, 10, 0)
        XCTAssertEqual(EndDateText.describe(date(20, 18, 0), now: now, calendar: calendar), "Today 18:00")
        XCTAssertEqual(EndDateText.describe(date(21, 8, 0), now: now, calendar: calendar), "Tomorrow 08:00")
        XCTAssertEqual(EndDateText.describe(date(23, 8, 0), now: now, calendar: calendar), "Fri 23 Oct, 08:00")
    }

    func testTimeLeftReadsInTheLargestUsefulUnits() {
        let now = date(20, 10, 0)
        XCTAssertEqual(EndDateText.timeLeft(until: date(20, 10, 25), now: now), "in 25 min")
        XCTAssertEqual(EndDateText.timeLeft(until: date(20, 13, 20), now: now), "in 3 h 20 min")
        XCTAssertEqual(EndDateText.timeLeft(until: date(20, 12, 0), now: now), "in 2 h")
        XCTAssertEqual(EndDateText.timeLeft(until: date(21, 14, 0), now: now), "in 1 day 4 h")
        XCTAssertEqual(EndDateText.timeLeft(until: date(22, 10, 0), now: now), "in 2 days 0 h")
    }

    func testTimeLeftIsNilWhenTheMomentIsNotAhead() {
        let now = date(20, 10, 0)
        XCTAssertNil(EndDateText.timeLeft(until: now, now: now))
        XCTAssertNil(EndDateText.timeLeft(until: date(20, 9, 0), now: now))
    }

    func testRestoreLineShowsTheDayOnlyWhenItIsNotToday() {
        let now = date(20, 10, 0)
        XCTAssertEqual(EndDateText.restoreLine(date(20, 19, 30, 5), now: now, calendar: calendar), "Restores at 19:30:05")
        XCTAssertEqual(EndDateText.restoreLine(date(21, 8, 0), now: now, calendar: calendar), "Restores Wed 21 Oct, 08:00:00")
    }

    func testRelativePresetsLandOnWholeMinutesAheadOfNow() {
        let now = date(20, 10, 0, 42)
        XCTAssertEqual(EndDatePreset.inThirtyMinutes.moment(from: now, calendar: calendar), date(20, 10, 30))
        XCTAssertEqual(EndDatePreset.inOneHour.moment(from: now, calendar: calendar), date(20, 11, 0))
        XCTAssertEqual(EndDatePreset.inFourHours.moment(from: now, calendar: calendar), date(20, 14, 0))
        XCTAssertEqual(EndDatePreset.inEightHours.moment(from: now, calendar: calendar), date(20, 18, 0))
    }

    func testAClockChipMeansTodayWhileItIsAheadAndTomorrowOnceItHasPassed() {
        let now = date(20, 10, 0)
        XCTAssertEqual(EndDateMoment.nextOccurrence(hour: 18, after: now, calendar: calendar), date(20, 18, 0))
        XCTAssertEqual(EndDateMoment.nextOccurrence(hour: 8, after: now, calendar: calendar), date(21, 8, 0))
        XCTAssertEqual(EndDateMoment.nextOccurrence(hour: 10, after: now, calendar: calendar), date(21, 10, 0))
    }

    func testDayLabelsNameTodayAndTomorrowThenTheDate() {
        let now = date(20, 10, 0)
        XCTAssertEqual(EndDateText.dayLabel(date(20, 0, 0), now: now, calendar: calendar), "Today")
        XCTAssertEqual(EndDateText.dayLabel(date(21, 0, 0), now: now, calendar: calendar), "Tomorrow")
        XCTAssertEqual(EndDateText.dayLabel(date(23, 0, 0), now: now, calendar: calendar), "Fri 23 Oct")
    }
}
