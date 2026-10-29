import AppKit

// The card at the top of the menu while What’s new points at something: the whole way in one look, then the same way
// walked one step at a time (the step to take lights up, the ones before it stay lit, the ones after it wait), so the
// eye learns which menu to open first. With Reduce Motion on, the whole way stays lit and still.
@MainActor
enum MenuGuideRow {
    static let width: CGFloat = 300
    static let padding = NSSize(width: 14, height: 10)
    static let stepSeconds: TimeInterval = 1.2

    static func item(path: [String]) -> NSMenuItem {
        let text = NSTextField(labelWithAttributedString: title(path: path))
        text.maximumNumberOfLines = 0
        text.lineBreakMode = .byWordWrapping
        text.preferredMaxLayoutWidth = width - 2 * padding.width
        let textSize = text.sizeThatFits(NSSize(width: width - 2 * padding.width, height: .greatestFiniteMagnitude))
        let card = Card(frame: NSRect(x: 0, y: 0, width: width, height: textSize.height + 2 * padding.height), path: path, text: text)
        text.frame = NSRect(x: padding.width, y: padding.height, width: width - 2 * padding.width, height: textSize.height)
        card.addSubview(text)
        let wrapper = NSView(frame: NSRect(x: 0, y: 0, width: width, height: card.frame.height + 8))
        card.frame.origin = NSPoint(x: 0, y: 4)
        wrapper.addSubview(card)
        let item = NSMenuItem()
        item.view = wrapper
        return item
    }

    // One round is a beat per step and one more with the whole way lit, then it starts again.
    static func activeStep(tick: Int, count: Int) -> Int? {
        guard count > 0 else { return nil }
        let beat = tick % (count + 1)
        return beat < count ? beat : nil
    }

    static func title(path: [String], active: Int? = nil) -> NSAttributedString {
        let heading = active.map { "Step \($0 + 1) of \(path.count)" } ?? "Look here"
        let result = NSMutableAttributedString(string: "\(heading)\n", attributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold), .foregroundColor: NSColor.secondaryLabelColor,
        ])
        for (index, step) in path.enumerated() {
            let last = index == path.count - 1
            if index > 0 {
                result.append(NSAttributedString(string: "  \u{203A}  ", attributes: [
                    .font: NSFont.menuFont(ofSize: 0), .foregroundColor: NSColor.tertiaryLabelColor,
                ]))
            }
            let waiting = active.map { index > $0 } ?? false
            var attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: last ? .bold : .semibold),
                .foregroundColor: waiting ? NSColor.tertiaryLabelColor : (last ? MenuHighlight.hereColor : MenuHighlight.wayColor),
            ]
            if index == active { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
            result.append(NSAttributedString(string: step, attributes: attributes))
        }
        return result
    }

    private final class Card: NSView {
        private let path: [String]
        private let text: NSTextField
        private var timer: Timer?
        private var tick = 0

        init(frame: NSRect, path: [String], text: NSTextField) {
            self.path = path
            self.text = text
            super.init(frame: frame)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        // The menu puts the card in a window when it opens and takes it out when it closes: the walk lives in between.
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stop()
            guard window != nil, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
            tick = 0
            showStep()
            let next = Timer(timeInterval: MenuGuideRow.stepSeconds, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.advance() }
            }
            RunLoop.main.add(next, forMode: .common)
            timer = next
        }

        private func advance() {
            guard window != nil else { return stop() }
            tick += 1
            showStep()
        }

        private func showStep() {
            text.attributedStringValue = MenuGuideRow.title(path: path, active: MenuGuideRow.activeStep(tick: tick, count: path.count))
        }

        private func stop() {
            timer?.invalidate()
            timer = nil
        }

        override func draw(_ dirtyRect: NSRect) {
            let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 6, dy: 0), xRadius: 8, yRadius: 8)
            MenuHighlight.hereColor.withAlphaComponent(0.12).setFill()
            shape.fill()
            MenuHighlight.hereColor.withAlphaComponent(0.35).setStroke()
            shape.lineWidth = 1
            shape.stroke()
        }
    }
}
