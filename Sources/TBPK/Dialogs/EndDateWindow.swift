import AppKit
import SwiftUI

@MainActor
final class EndDateWindow: NSObject, NSWindowDelegate {
    private static var current: EndDateWindow?

    private let window: NSWindow
    private let model: EndDateModel
    private let onSet: (Date) -> Void

    static func present(defaultDate: Date?, onSet: @escaping (Date) -> Void) {
        if let current {
            current.window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let model = EndDateModel(start: defaultDate)
        model.tipsMinutes = MenuHighlight.endDateTip
        MenuHighlight.endDateTip = false
        let next = EndDateWindow(model: model, onSet: onSet)
        current = next
        next.show()
    }

    private init(model: EndDateModel, onSet: @escaping (Date) -> Void) {
        self.model = model
        self.onSet = onSet
        window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init()
        let view = EndDateView(
            model: model,
            onSet: { [weak self] date in self?.finish(with: date) },
            onCancel: { [weak self] in self?.window.close() }
        )
        let hosting = NSHostingController(rootView: view)
        hosting.sizingOptions = [.preferredContentSize]
        window.contentViewController = hosting
        window.title = "Stay awake until"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.level = .floating
    }

    private func show() {
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func finish(with date: Date) {
        model.pick(now: Date()).map { EndDateFavorites.record($0) }
        onSet(date)
        window.close()
    }

    func windowWillClose(_ notification: Notification) {
        Self.current = nil
    }
}
