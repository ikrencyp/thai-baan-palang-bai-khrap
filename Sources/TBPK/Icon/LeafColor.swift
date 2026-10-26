import AppKit

// The colour of the leaf while Keep awake is on: one of a few named choices, or any #RRGGBB the person types.
// There are two of them, one for the charger and one for the battery. Both are stored as the hex text, so a custom
// colour and a named one are the same thing to the rest of the app.
struct LeafColor: Equatable {
    let rgb: UInt32

    // Which of the two colours a stored value, a menu row or a prompt is about.
    enum Slot: Equatable {
        case charger
        case battery

        var storageKey: String { self == .charger ? "leafColor" : "leafColorBattery" }
        var fallback: LeafColor { self == .charger ? .standard : .batteryStandard }
        var label: String { self == .charger ? "Leaf colour on the charger" : "Leaf colour on battery" }
    }

    // What a colour row in the menu carries: the slot it fills and the colour itself.
    struct Pick: Equatable {
        let slot: Slot
        let color: LeafColor
    }

    struct Choice {
        let name: String
        let color: LeafColor
    }

    static let choices: [Choice] = [
        Choice(name: "Green", color: LeafColor(rgb: 0x2EDB6E)),
        Choice(name: "Mint", color: LeafColor(rgb: 0x5EF2C8)),
        Choice(name: "Sky", color: LeafColor(rgb: 0x3FC1FF)),
        Choice(name: "Blue", color: LeafColor(rgb: 0x4C7DFF)),
        Choice(name: "Purple", color: LeafColor(rgb: 0xB06CFF)),
        Choice(name: "Pink", color: LeafColor(rgb: 0xFF5FA8)),
        Choice(name: "Red", color: LeafColor.red),
        Choice(name: "Orange", color: LeafColor(rgb: 0xFF8A2B)),
        Choice(name: "White", color: LeafColor(rgb: 0xFFFFFF)),
    ]

    static let red = LeafColor(rgb: 0xFF4530)
    static var standard: LeafColor { choices[0].color }
    static var batteryStandard: LeafColor { red }

    // "#2EDB6E", "2edb6e" and the short "#3c9" are all accepted; anything else is not a colour.
    init?(hex text: String) {
        var digits = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if digits.hasPrefix("#") { digits.removeFirst() }
        if digits.count == 3 { digits = digits.map { "\($0)\($0)" }.joined() }
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.rgb = value
    }

    init(rgb: UInt32) {
        self.rgb = rgb
    }

    var hex: String { String(format: "#%06X", rgb) }

    var name: String { Self.choices.first { $0.color == self }?.name ?? hex }

    var isCustom: Bool { !Self.choices.contains { $0.color == self } }

    var nsColor: NSColor {
        NSColor(srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255,
                blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
    }

    static func stored(_ slot: Slot = .charger, in defaults: UserDefaults = .standard) -> LeafColor {
        defaults.string(forKey: slot.storageKey).flatMap { LeafColor(hex: $0) } ?? slot.fallback
    }

    func store(_ slot: Slot = .charger, in defaults: UserDefaults = .standard) {
        defaults.set(hex, forKey: slot.storageKey)
    }
}
