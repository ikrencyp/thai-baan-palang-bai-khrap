import Foundation

@MainActor
final class EndDateModel: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case duration
        case time

        var id: String { rawValue }

        var label: String {
            switch self {
            case .duration: return "For how long"
            case .time: return "At a time"
            }
        }
    }

    struct Chip: Identifiable, Equatable {
        let minutes: Int
        let label: String
        var id: Int { minutes }
    }

    static let chips = [
        Chip(minutes: 30, label: "30 min"), Chip(minutes: 60, label: "1 hour"), Chip(minutes: 120, label: "2 hours"),
        Chip(minutes: 240, label: "4 hours"), Chip(minutes: 480, label: "8 hours"), Chip(minutes: 720, label: "12 hours"),
    ]
    static let clockHours = [6, 7, 8, 9, 12, 18, 22]
    static let modeKey = "endDateMode"

    @Published var mode: Mode
    @Published var amount: Int
    @Published var unit: EndDateUnit
    @Published var day: Date
    @Published var clockHour: Int
    @Published var clockMinute: Int

    private let calendar: Calendar

    init(start: Date?, now: Date = Date(), calendar: Calendar = .current, defaults: UserDefaults = .standard) {
        self.calendar = calendar
        let stored = defaults.string(forKey: Self.modeKey).flatMap(Mode.init(rawValue:))
        mode = start == nil ? (stored ?? .duration) : .time
        amount = 1
        unit = .hours
        let seed = start ?? now.addingTimeInterval(3_600)
        day = calendar.startOfDay(for: seed)
        clockHour = calendar.component(.hour, from: seed)
        clockMinute = calendar.component(.minute, from: seed)
        normalize(now: now)
    }

    func moment(now: Date) -> Date? {
        switch mode {
        case .duration: return unit.moment(after: amount, from: now)
        case .time: return EndDateMoment.combine(day: day, hour: clockHour, minute: clockMinute, calendar: calendar)
        }
    }

    func isAhead(now: Date) -> Bool {
        guard let moment = moment(now: now) else { return false }
        return moment > now
    }

    func headline(now: Date) -> String {
        guard let moment = moment(now: now), moment > now else { return "Pick a time ahead" }
        return EndDateText.describe(moment, now: now, calendar: calendar)
    }

    func detail(now: Date) -> String {
        guard let moment = moment(now: now), let left = EndDateText.timeLeft(until: moment, now: now) else {
            return "Nothing is selected yet."
        }
        return left
    }

    func confirmTitle(now: Date) -> String {
        isAhead(now: now) ? "Stay awake until \(headline(now: now))" : "Pick a time ahead"
    }

    func applyChip(minutes: Int) {
        mode = .duration
        (amount, unit) = Self.split(minutes: minutes)
    }

    func isChipSelected(_ chip: Chip) -> Bool {
        mode == .duration && amount * unit.minutes == chip.minutes
    }

    func applyClock(hour: Int, now: Date) {
        mode = .time
        clockHour = hour
        clockMinute = 0
        normalize(now: now)
    }

    func chooseDay(offsetFrom now: Date, days: Int) {
        let today = calendar.startOfDay(for: now)
        day = calendar.date(byAdding: .day, value: days, to: today) ?? today
        normalize(now: now)
    }

    func isDayChosen(offsetFrom now: Date, days: Int) -> Bool {
        let today = calendar.startOfDay(for: now)
        guard let target = calendar.date(byAdding: .day, value: days, to: today) else { return false }
        return calendar.isDate(day, inSameDayAs: target)
    }

    // The soonest clock reading still ahead today, or nil once today has run out.
    func earliestToday(now: Date) -> (hour: Int, minute: Int)? {
        let next = now.addingTimeInterval(60)
        guard calendar.isDate(next, inSameDayAs: now) else { return nil }
        return (calendar.component(.hour, from: next), calendar.component(.minute, from: next))
    }

    func isTodayAvailable(now: Date) -> Bool { earliestToday(now: now) != nil }

    func firstSelectableDay(now: Date) -> Date {
        let today = calendar.startOfDay(for: now)
        guard !isTodayAvailable(now: now) else { return today }
        return calendar.date(byAdding: .day, value: 1, to: today) ?? today
    }

    func hourRange(now: Date) -> ClosedRange<Int> {
        guard calendar.isDate(day, inSameDayAs: now), let earliest = earliestToday(now: now) else { return 0...23 }
        return earliest.hour...23
    }

    func minuteRange(now: Date) -> ClosedRange<Int> {
        guard calendar.isDate(day, inSameDayAs: now), let earliest = earliestToday(now: now),
              clockHour == earliest.hour else { return 0...59 }
        return earliest.minute...59
    }

    func availableClockHours(now: Date) -> [Int] {
        guard calendar.isDate(day, inSameDayAs: now), let earliest = earliestToday(now: now) else { return Self.clockHours }
        return Self.clockHours.filter { $0 * 60 >= earliest.hour * 60 + earliest.minute }
    }

    // Pulls every field back to something that is still ahead: nothing earlier than now can stay selected.
    func normalize(now: Date) {
        amount = min(max(amount, 1), EndDateUnit.largestAmount)
        day = max(calendar.startOfDay(for: day), firstSelectableDay(now: now))
        clockHour = min(max(clockHour, hourRange(now: now).lowerBound), 23)
        clockMinute = min(max(clockMinute, minuteRange(now: now).lowerBound), 59)
    }

    // What this window's choice is worth remembering as: a length, or a clock reading within the next day.
    // A date days away would not come round again, so it is not remembered.
    func pick(now: Date) -> EndDatePick? {
        switch mode {
        case .duration: return .duration(minutes: amount * unit.minutes)
        case .time:
            guard let moment = moment(now: now), moment > now, moment.timeIntervalSince(now) <= 24 * 3_600 else { return nil }
            return .clock(hour: clockHour, minute: clockMinute)
        }
    }

    func remember(defaults: UserDefaults = .standard) {
        defaults.set(mode.rawValue, forKey: Self.modeKey)
    }

    static func split(minutes: Int) -> (Int, EndDateUnit) {
        if minutes % EndDateUnit.days.minutes == 0 { return (minutes / EndDateUnit.days.minutes, .days) }
        if minutes % EndDateUnit.hours.minutes == 0 { return (minutes / EndDateUnit.hours.minutes, .hours) }
        return (minutes, .minutes)
    }
}
