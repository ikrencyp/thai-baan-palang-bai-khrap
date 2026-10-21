import AppKit

@MainActor
enum MenuHeader {
    static let width: CGFloat = 280

    struct Content: Equatable {
        let title: String
        let detail: String
        let awake: Bool
        let failed: Bool
    }

    static func content(power: PowerManager, alerting: Bool, onBattery: Bool = false) -> Content {
        if power.hasFailure {
            return Content(title: "Something went wrong", detail: power.statusMessage, awake: false, failed: true)
        }
        guard power.isSleepDisabled else {
            return Content(title: "Normal sleep", detail: power.stopNotice ?? "This Mac sleeps as usual.",
                           awake: false, failed: false)
        }
        let detail = alerting ? "Left running on battery." : (onBattery ? batteryDetail(power) : (power.remainingTimeText ?? "Until you turn it off."))
        return Content(title: "Staying awake", detail: detail, awake: true, failed: false)
    }

    private static func batteryDetail(_ power: PowerManager) -> String {
        "Not charging. " + (power.remainingTimeText ?? "Until you turn it off.")
    }

    static func item(_ content: Content) -> NSMenuItem {
        let item = NSMenuItem()
        item.view = view(content)
        return item
    }

    private static func view(_ content: Content) -> NSView {
        let row = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 56))

        let glyph = NSImageView(frame: NSRect(x: 16, y: 13, width: 30, height: 30))
        glyph.image = content.failed
            ? LeafGlyph.failureImage()
            : LeafGlyph.image(fill: content.awake ? 1 : 0, scale: 1, alpha: 1,
                              tint: content.awake ? StatusIconAnimator.powerGold : nil, glow: content.awake ? 0.8 : 0)
        glyph.imageScaling = .scaleProportionallyUpOrDown
        glyph.contentTintColor = content.failed ? .systemOrange : (content.awake ? nil : .secondaryLabelColor)
        row.addSubview(glyph)

        let title = NSTextField(labelWithString: content.title)
        title.font = .systemFont(ofSize: 14, weight: .semibold)
        title.frame = NSRect(x: 56, y: 29, width: width - 70, height: 18)
        row.addSubview(title)

        let detail = NSTextField(labelWithString: content.detail)
        detail.font = .systemFont(ofSize: 12)
        detail.textColor = .secondaryLabelColor
        detail.lineBreakMode = .byTruncatingTail
        detail.frame = NSRect(x: 56, y: 10, width: width - 70, height: 16)
        row.addSubview(detail)
        return row
    }
}
