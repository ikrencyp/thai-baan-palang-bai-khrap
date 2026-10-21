import AppKit

// The small blue dot on the menu bar icon that says a new version is waiting (the way VS Code marks its gear).
final class UpdateBadgeView: NSView {
    static let size: CGFloat = 8

    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityLabel("Update available")
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        let ring = bounds.insetBy(dx: 0.5, dy: 0.5)
        NSColor.systemBlue.setFill()
        NSBezierPath(ovalIn: ring).fill()
        NSColor.white.withAlphaComponent(0.9).setStroke()
        let edge = NSBezierPath(ovalIn: ring)
        edge.lineWidth = 1
        edge.stroke()
    }
}
