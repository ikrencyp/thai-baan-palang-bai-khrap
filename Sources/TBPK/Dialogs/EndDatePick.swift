import Foundation

// What a person chose in "At a date and time": a length, or a clock reading that comes round every day.
enum EndDatePick: Equatable {
    case duration(minutes: Int)
    case clock(hour: Int, minute: Int)

    init?(key: String) {
        let parts = key.split(separator: ":").map(String.init)
        switch (parts.first, parts.dropFirst().compactMap(Int.init)) {
        case ("d", let numbers) where numbers.count == 1 && numbers[0] > 0:
            self = .duration(minutes: numbers[0])
        case ("c", let numbers) where numbers.count == 2 && (0...23).contains(numbers[0]) && (0...59).contains(numbers[1]):
            self = .clock(hour: numbers[0], minute: numbers[1])
        default:
            return nil
        }
    }

    var key: String {
        switch self {
        case .duration(let minutes): return "d:\(minutes)"
        case .clock(let hour, let minute): return "c:\(hour):\(minute)"
        }
    }

    // The menu already lists these lengths, so they are never offered a second time.
    var isInTheMenuAlready: Bool {
        guard case .duration(let minutes) = self else { return false }
        return SleepDuration.allCases.contains { $0.seconds.map { Int($0 / 60) } == minutes }
    }

    var label: String {
        switch self {
        case .duration(let minutes): return "For \(Self.length(minutes))"
        case .clock(let hour, let minute): return String(format: "Until %02d:%02d", hour, minute)
        }
    }

    func moment(now: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .duration(let minutes): return now.addingTimeInterval(Double(minutes) * 60)
        case .clock(let hour, let minute): return EndDateMoment.nextOccurrence(hour: hour, minute: minute, after: now, calendar: calendar)
        }
    }

    private static func length(_ minutes: Int) -> String {
        if minutes % 1_440 == 0 { return plural(minutes / 1_440, "day") }
        if minutes % 60 == 0 { return plural(minutes / 60, "hour") }
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60) h \(minutes % 60) min"
    }

    private static func plural(_ count: Int, _ word: String) -> String {
        "\(count) \(word)\(count == 1 ? "" : "s")"
    }
}
