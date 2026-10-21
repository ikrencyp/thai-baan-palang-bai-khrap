import AppKit

// A menu row that does its work and leaves the menu open, so several choices can be tried one after another.
// The menu closes the usual ways: a click outside it, Escape, or a choice that is not one of these rows.
// Keyboard activation (Return) still goes through the item's own action and closes the menu, as any menu does.
@MainActor
final class StayOpenRow: NSView {
    static let width: CGFloat = 292
    static let height: CGFloat = 22
    private static let textInset: CGFloat = 28
    private static let rightInset: CGFloat = 16

    private let title: () -> String
    private let detail: () -> String?
    private let isOn: () -> Bool
    private let pick: () -> Void

    init(title: @escaping () -> String, detail: @escaping () -> String? = { nil }, isOn: @escaping () -> Bool, pick: @escaping () -> Void) {
        self.title = title
        self.detail = detail
        self.isOn = isOn
        self.pick = pick
        super.init(frame: NSRect(x: 0, y: 0, width: Self.width, height: Self.height))
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
        setAccessibilityRole(.radioButton)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("StayOpenRow is built in code") }

    var currentTitle: String { title() }
    var currentDetail: String? { detail() }
    var isChosen: Bool { isOn() }

    func performPick() {
        pick()
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) { performPick() }
    override func mouseEntered(with event: NSEvent) { needsDisplay = true }
    override func mouseExited(with event: NSEvent) { needsDisplay = true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func accessibilityLabel() -> String? { title() }
    override func accessibilityValue() -> Any? { isOn() ? 1 : 0 }
    override func accessibilityPerformPress() -> Bool {
        performPick()
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        let highlighted = enclosingMenuItem?.isHighlighted == true
        if highlighted {
            NSColor.selectedContentBackgroundColor.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 5, dy: 1), xRadius: 4, yRadius: 4).fill()
        }
        let font = NSFont.menuFont(ofSize: 0)
        let primary = highlighted ? NSColor.selectedMenuItemTextColor : NSColor.labelColor
        let secondary = highlighted ? NSColor.selectedMenuItemTextColor : NSColor.secondaryLabelColor
        let textHeight = ceil(font.ascender - font.descender)
        let baseline = (bounds.height - textHeight) / 2
        if isOn() { "\u{2713}".draw(at: NSPoint(x: 10, y: baseline), withAttributes: [.font: font, .foregroundColor: primary]) }
        let side = detail().map { text -> (NSAttributedString, CGFloat) in
            let styled = Self.styled(text, font, secondary, .right)
            return (styled, ceil(styled.size().width))
        }
        let titleWidth = bounds.width - Self.textInset - Self.rightInset - (side.map { $0.1 + 10 } ?? 0)
        Self.styled(title(), font, primary, .left)
            .draw(in: NSRect(x: Self.textInset, y: baseline, width: titleWidth, height: textHeight))
        side?.0.draw(in: NSRect(x: bounds.width - Self.rightInset - side!.1, y: baseline, width: side!.1, height: textHeight))
    }

    private static func styled(_ text: String, _ font: NSFont, _ color: NSColor, _ alignment: NSTextAlignment) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.alignment = alignment
        return NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph])
    }
}
