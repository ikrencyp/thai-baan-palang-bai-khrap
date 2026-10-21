import AppKit

@MainActor
enum AlertPresenter {
    // LSUIElement apps start in the background: an alert run without this opens behind every
    // window, holds the keyboard hidden, and looks like the Mac ignoring typing.
    @discardableResult
    static func run(_ alert: NSAlert) -> NSApplication.ModalResponse {
        NSApp.activate(ignoringOtherApps: true)
        alert.window.level = .floating
        (alert.window as? NSPanel)?.hidesOnDeactivate = false
        alert.window.center()
        alert.window.makeKeyAndOrderFront(nil)
        return alert.runModal()
    }
}
