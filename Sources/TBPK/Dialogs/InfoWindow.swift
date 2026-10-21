import AppKit
import SwiftUI

@MainActor
enum InfoWindow {
    private static var open: [String: NSWindow] = [:]

    static func show<Content: View>(id: String, title: String, size: NSSize, @ViewBuilder content: () -> Content) {
        NSApp.activate(ignoringOtherApps: true)
        if let existing = open[id] {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: content())
        window.setContentSize(size)
        window.center()
        window.level = .floating
        open[id] = window
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
            MainActor.assumeIsolated { open[id] = nil }
        }
        window.makeKeyAndOrderFront(nil)
    }
}
