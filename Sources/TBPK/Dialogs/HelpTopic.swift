import Foundation

struct HelpTopic: Identifiable, Equatable {
    let id: String
    let symbol: String
    let title: String
    let summary: String
    let detail: String

    static let leafSymbol = "tbpk.leaf"

    static let steps: [String] = [
        "Click the leaf in the menu bar.",
        "Choose Keep this Mac awake, then Stay awake for to pick when sleep returns.",
        "Close the lid. Open it again or choose Back to normal sleep when you are done.",
    ]

    static let menu: [HelpTopic] = [
        HelpTopic(id: "awake", symbol: HelpTopic.leafSymbol, title: "Keep this Mac awake",
                  summary: "One click turns sleep off, one click turns it back on.",
                  detail: "Right click the leaf to do the same without opening the menu."),
        HelpTopic(id: "duration", symbol: "clock", title: "Stay awake for",
                  summary: "30 minutes to 12 hours, until you turn it off, or at a date and time.",
                  detail: "The date form has quick chips and clock presets. The 3 lengths or clock times you pick most there appear under Often used, one click each."),
        HelpTopic(id: "alerts", symbol: "bell.badge", title: "Alerts",
                  summary: "Beeps when the lid is shut or the screen is locked while the Mac stays awake. One menu holds when it fires and what it sounds like.",
                  detail: "When: once or repeating, on battery only or on the charger too. Sound: one of your own files (add several at once, up to 30 seconds each: AIFF, WAV, MP3, M4A, AAC, CAF, and remove them again) or a Mac sound. How many times is remembered per sound, or the same for all. Press play next to the volume to hear it. It plays on the Mac speaker, not on Bluetooth headphones."),
        HelpTopic(id: "power", symbol: "battery.75", title: "Power rules",
                  summary: "Go back to normal sleep when the battery is low or the charger is unplugged, keep the screen on, look present.",
                  detail: "The screen can also switch off when the Mac is locked or the lid is closed, to save power."),
        HelpTopic(id: "present", symbol: "display", title: "Look present at the screen",
                  summary: "Keeps the Mac from looking idle while Keep awake is on, so you do not show as away when you step out.",
                  detail: "Power rules > Screen. Off by default. While it is on and the Mac is held awake, a tiny no-move input goes out every minute; macOS asks once for the Accessibility permission to allow that. Switch it off and the Mac goes back to counting idle time as before."),
        HelpTopic(id: "energy", symbol: "bolt", title: "Energy use",
                  summary: "Automatic, Full performance or Power saver, in Settings.",
                  detail: "Automatic follows macOS: a calm heartbeat on the charger, a still leaf on battery, in Low Power Mode or with Reduce Motion on. Nothing is drawn while the display is asleep."),
        HelpTopic(id: "settings", symbol: "gearshape", title: "Settings",
                  summary: "Countdown in the menu bar, animation, leaf colour, energy use, Start at Login.",
                  detail: "Leaf colour: two colours, On the charger and On battery, each one of nine named colours or a colour code you type such as #FF8800; the leaf shows them while Keep awake is on, and an alert shows the battery colour. Quitting the app always gives the Mac back its previous sleep setting."),
        HelpTopic(id: "whatsnew", symbol: "sparkles", title: "What\u{2019}s new",
                  summary: "What changed in each version of the app.",
                  detail: "It opens by itself once after an update, and any time from the menu or the About window."),
    ]
}
