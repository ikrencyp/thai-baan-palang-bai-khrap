import Foundation

// Remembers what was picked in the date and time window, so the few that come back most often sit in the menu.
enum EndDateFavorites {
    static let storageKey = "endDateFavorites"
    static let menuLimit = 3
    private static let keepLimit = 20

    // key -> [times chosen, last chosen]
    private static func entries(in defaults: UserDefaults) -> [String: [Double]] {
        defaults.dictionary(forKey: storageKey) as? [String: [Double]] ?? [:]
    }

    static func record(_ pick: EndDatePick, now: Date = Date(), in defaults: UserDefaults = .standard) {
        guard !pick.isInTheMenuAlready else { return }
        var all = entries(in: defaults)
        all[pick.key] = [(all[pick.key]?.first ?? 0) + 1, now.timeIntervalSince1970]
        let kept = all.sorted(by: ranksAbove).prefix(keepLimit)
        defaults.set(Dictionary(uniqueKeysWithValues: kept.map { ($0.key, $0.value) }), forKey: storageKey)
    }

    // Most chosen first; a tie goes to the one used last.
    static func top(limit: Int = menuLimit, in defaults: UserDefaults = .standard) -> [EndDatePick] {
        entries(in: defaults).sorted(by: ranksAbove).compactMap { EndDatePick(key: $0.key) }.prefix(limit).map { $0 }
    }

    static func clear(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey)
    }

    private static func ranksAbove(_ a: (key: String, value: [Double]), _ b: (key: String, value: [Double])) -> Bool {
        a.value[0] != b.value[0] ? a.value[0] > b.value[0] : a.value[1] > b.value[1]
    }
}
