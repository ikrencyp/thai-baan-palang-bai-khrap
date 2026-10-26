import AppKit

// A small floating panel with a spinner, so a check or a download never looks like the app did nothing.
// An install also shows its three steps, the finished ones ticked, so the person sees how far it is.
@MainActor
enum UpdateProgressPanel {
    enum Step: Int, CaseIterable {
        case download, prepare, install

        var title: String {
            switch self {
            case .download: return "Download"
            case .prepare: return "Prepare"
            case .install: return "Install and restart"
            }
        }
    }

    private static let textWidth: CGFloat = 270
    private static let spinnerSize: CGFloat = 32
    private static let margin: CGFloat = 22
    private static var panel: NSPanel?
    private static var title: NSTextField?
    private static var detail: NSTextField?
    private static var steps: NSStackView?
    private static var progressRow: NSStackView?
    private static var bar: NSProgressIndicator?
    private static var percent: NSTextField?

    static var isShowing: Bool { panel?.isVisible == true }

    static var staysUpWhenInactive: Bool { panel?.hidesOnDeactivate == false }

    static var contentSize: NSSize? { panel?.contentView?.frame.size }

    static func show(_ message: String, detail text: String, step: Step? = nil) {
        if panel == nil { build() }
        title?.stringValue = message
        detail?.stringValue = text
        showSteps(step)
        showProgress(step == .download)
        guard let panel else { return }
        fit(panel)
        guard !panel.isVisible else { return }
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    static func hide() {
        panel?.orderOut(nil)
    }

    // The share of the download that is really in, as text; nil while the size is not known yet.
    static var percentLabel: String? { progressRow?.isHidden == false ? percent?.stringValue : nil }

    static func percentText(_ fraction: Double) -> String {
        "\(Int((min(1, max(0, fraction)) * 100).rounded()))%"
    }

    // Only goes up: a late report from an earlier moment never moves the bar back.
    static func setProgress(_ fraction: Double) {
        guard let bar, let percent, progressRow?.isHidden == false else { return }
        let value = max(min(1, fraction), bar.isIndeterminate ? 0 : bar.doubleValue / 100)
        bar.stopAnimation(nil)
        bar.isIndeterminate = false
        bar.doubleValue = value * 100
        percent.stringValue = percentText(value)
    }

    private static func showProgress(_ visible: Bool) {
        guard let row = progressRow, let bar, let percent else { return }
        row.isHidden = !visible
        guard visible else { return bar.stopAnimation(nil) }
        bar.isIndeterminate = true
        bar.startAnimation(nil)
        percent.stringValue = percentText(0)
    }

    static func stepText(_ step: Step, current: Step) -> NSAttributedString {
        let mark = step.rawValue < current.rawValue ? "\u{2713}" : step == current ? "\u{25CF}" : "\u{25CB}"
        let color: NSColor = step.rawValue < current.rawValue ? .systemGreen : step == current ? .labelColor : .tertiaryLabelColor
        let weight: NSFont.Weight = step == current ? .semibold : .regular
        return NSAttributedString(string: "\(mark) \(step.title)",
                                  attributes: [.foregroundColor: color, .font: NSFont.systemFont(ofSize: 11, weight: weight)])
    }

    private static func showSteps(_ current: Step?) {
        guard let row = steps else { return }
        row.isHidden = current == nil
        guard let current else { return }
        for (label, step) in zip(row.arrangedSubviews.compactMap { $0 as? NSTextField }, Step.allCases) {
            label.attributedStringValue = stepText(step, current: current)
        }
    }

    // The text wraps inside a fixed column, so the window is sized after the words are in, never before.
    private static func fit(_ panel: NSPanel) {
        guard let heading = title, let body = detail else { return }
        let bodyHeight = body.cell?.cellSize(forBounds: NSRect(x: 0, y: 0, width: textWidth, height: .greatestFiniteMagnitude)).height ?? 0
        let progressHeight = progressRow.map { $0.isHidden ? 0 : 10 + $0.fittingSize.height } ?? 0
        let stepsHeight = steps.map { $0.isHidden ? 0 : 10 + $0.fittingSize.height } ?? 0
        let column = heading.intrinsicContentSize.height + 4 + ceil(bodyHeight) + progressHeight + stepsHeight
        panel.setContentSize(NSSize(width: textWidth + spinnerSize + 14 + 2 * margin, height: max(column, spinnerSize) + 2 * margin))
    }

    private static func build() {
        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .regular
        spinner.isIndeterminate = true
        spinner.widthAnchor.constraint(equalToConstant: spinnerSize).isActive = true
        spinner.heightAnchor.constraint(equalToConstant: spinnerSize).isActive = true
        spinner.startAnimation(nil)
        let heading = NSTextField(labelWithString: "")
        heading.font = .systemFont(ofSize: 14, weight: .semibold)
        let body = NSTextField(wrappingLabelWithString: "")
        body.font = .systemFont(ofSize: 12)
        body.textColor = .secondaryLabelColor
        body.preferredMaxLayoutWidth = textWidth
        let tracker = NSStackView(views: Step.allCases.map { _ in NSTextField(labelWithString: "") })
        tracker.orientation = .horizontal
        tracker.spacing = 12
        tracker.isHidden = true
        let meter = NSProgressIndicator()
        meter.style = .bar
        meter.controlSize = .small
        meter.minValue = 0
        meter.maxValue = 100
        meter.isIndeterminate = true
        meter.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let share = NSTextField(labelWithString: "")
        share.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        share.textColor = .secondaryLabelColor
        share.alignment = .right
        share.widthAnchor.constraint(equalToConstant: 36).isActive = true
        let meterRow = NSStackView(views: [meter, share])
        meterRow.orientation = .horizontal
        meterRow.alignment = .centerY
        meterRow.spacing = 8
        meterRow.widthAnchor.constraint(equalToConstant: textWidth).isActive = true
        meterRow.isHidden = true
        let column = NSStackView(views: [heading, body, meterRow, tracker])
        column.setCustomSpacing(10, after: body)
        column.setCustomSpacing(10, after: meterRow)
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 4
        column.widthAnchor.constraint(equalToConstant: textWidth).isActive = true
        let row = NSStackView(views: [spinner, column])
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 14
        row.edgeInsets = NSEdgeInsets(top: margin, left: margin, bottom: margin, right: margin)
        let window = NSPanel(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Thai Baan Palang Bai Khrap"
        window.contentView = row
        window.isReleasedWhenClosed = false
        window.level = .floating
        // A panel hides itself while its app is not active, and a menu bar app often is not at the moment of the
        // first click: the window must stay up on its own.
        window.hidesOnDeactivate = false
        panel = window
        title = heading
        detail = body
        steps = tracker
        progressRow = meterRow
        bar = meter
        percent = share
    }
}
