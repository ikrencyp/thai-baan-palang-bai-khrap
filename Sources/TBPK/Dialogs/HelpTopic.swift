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
        HelpTopic(id: "alerts", symbol: "bell.badge", title: "Lid & lock alerts",
                  summary: "Beeps when the lid is shut or the screen is locked while the Mac stays awake.",
                  detail: "Choose once or repeating, and whether it counts on battery only or on the charger too."),
        HelpTopic(id: "sound", symbol: "speaker.wave.2", title: "Alert sound",
                  summary: "Pick one of your own files or a Mac sound. Press play to hear it. It plays on the Mac speaker, not on Bluetooth headphones.",
                  detail: "Add several files at once (up to 30 seconds each: AIFF, WAV, MP3, M4A, AAC, CAF) and remove them again. How many times is remembered per sound, or the same for all. Volume and a play button are here."),
        HelpTopic(id: "power", symbol: "battery.75", title: "Power rules",
                  summary: "Go back to normal sleep when the battery is low or the charger is unplugged.",
                  detail: "The screen can also switch off when the Mac is locked or the lid is closed, to save power."),
        HelpTopic(id: "energy", symbol: "bolt", title: "Energy use",
                  summary: "Automatic, Full performance or Power saver, in Settings.",
                  detail: "Automatic follows macOS: a calm heartbeat on the charger, a still leaf on battery, in Low Power Mode or with Reduce Motion on. Nothing is drawn while the display is asleep."),
        HelpTopic(id: "settings", symbol: "gearshape", title: "Settings",
                  summary: "Countdown in the menu bar, animation, energy use, Start at Login.",
                  detail: "Quitting the app always gives the Mac back its previous sleep setting."),
        HelpTopic(id: "whatsnew", symbol: "sparkles", title: "What\u{2019}s new",
                  summary: "What changed in each version of the app.",
                  detail: "It opens by itself once after an update, and any time from the menu or the About window."),
    ]
}
