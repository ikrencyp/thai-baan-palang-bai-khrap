import AppKit

// A small floating panel with a spinner, so a check or a download never looks like the app did nothing.
@MainActor
enum UpdateProgressPanel {
    private static let textWidth: CGFloat = 270
    private static let spinnerSize: CGFloat = 32
    private static let margin: CGFloat = 22
    private static var panel: NSPanel?
    private static var title: NSTextField?
    private static var detail: NSTextField?

    static var isShowing: Bool { panel?.isVisible == true }

    static var staysUpWhenInactive: Bool { panel?.hidesOnDeactivate == false }

    static var contentSize: NSSize? { panel?.contentView?.frame.size }

    static func show(_ message: String, detail text: String) {
        if panel == nil { build() }
        title?.stringValue = message
        detail?.stringValue = text
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

    // The text wraps inside a fixed column, so the window is sized after the words are in, never before.
    private static func fit(_ panel: NSPanel) {
        guard let heading = title, let body = detail else { return }
        let bodyHeight = body.cell?.cellSize(forBounds: NSRect(x: 0, y: 0, width: textWidth, height: .greatestFiniteMagnitude)).height ?? 0
        let column = heading.intrinsicContentSize.height + 4 + ceil(bodyHeight)
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
        let column = NSStackView(views: [heading, body])
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
    }
}
