import Foundation

enum AlertBeepCount: Int, CaseIterable, Identifiable {
    case one = 1
    case three = 3
    case five = 5
    case ten = 10
    case twenty = 20

    static let storageKey = "alertBeepCount"
    static let perSoundKey = "alertBeepCountBySound"
    static let sharedKey = "alertBeepCountShared"

    // Mac sounds are short; your own file is usually a clip or a tune: one play is enough to start with.
    static func defaultCount(for sound: AlertSound) -> AlertBeepCount {
        sound.isCustom ? .one : .five
    }

    static func isShared(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: sharedKey)
    }

    static func setShared(_ shared: Bool, in defaults: UserDefaults = .standard) {
        defaults.set(shared, forKey: sharedKey)
    }

    static func stored(for sound: AlertSound, in defaults: UserDefaults = .standard) -> AlertBeepCount {
        if isShared(in: defaults) { return sharedCount(in: defaults) }
        let remembered = defaults.dictionary(forKey: perSoundKey)?[sound.name] as? Int
        return remembered.flatMap(AlertBeepCount.init(rawValue:)) ?? defaultCount(for: sound)
    }

    static func store(_ count: AlertBeepCount, for sound: AlertSound, in defaults: UserDefaults = .standard) {
        if isShared(in: defaults) {
            defaults.set(count.rawValue, forKey: storageKey)
        } else {
            var remembered = defaults.dictionary(forKey: perSoundKey) ?? [:]
            remembered[sound.name] = count.rawValue
            defaults.set(remembered, forKey: perSoundKey)
        }
    }

    static func forget(_ sound: AlertSound, in defaults: UserDefaults = .standard) {
        var remembered = defaults.dictionary(forKey: perSoundKey) ?? [:]
        remembered.removeValue(forKey: sound.name)
        defaults.set(remembered, forKey: perSoundKey)
    }

    private static func sharedCount(in defaults: UserDefaults) -> AlertBeepCount {
        (defaults.object(forKey: storageKey) as? Int).flatMap(AlertBeepCount.init(rawValue:)) ?? .five
    }

    var id: Int { rawValue }

    var label: String { "\(rawValue)×" }
}
