import AppKit
import IOKit
import IOKit.ps

@MainActor
final class SystemChangeObserver {
    private let handler: () -> Void
    private var tokens: [(center: NotificationCenter, token: NSObjectProtocol)] = []
    private var powerSource: CFRunLoopSource?
    private var lidPort: IONotificationPortRef?
    private var lidNotifier: io_object_t = 0

    init(onChange handler: @escaping () -> Void) {
        self.handler = handler
    }

    func start() {
        guard tokens.isEmpty else { return }
        observeLockAndDisplay()
        observePowerSource()
        observeLid()
    }

    func stop() {
        tokens.forEach { $0.center.removeObserver($0.token) }
        tokens = []
        if let powerSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSource, .commonModes) }
        powerSource = nil
        if lidNotifier != 0 { IOObjectRelease(lidNotifier) }
        lidNotifier = 0
        if let lidPort { IONotificationPortDestroy(lidPort) }
        lidPort = nil
    }

    fileprivate func fire() {
        handler()
    }

    private func observeLockAndDisplay() {
        let distributed = DistributedNotificationCenter.default()
        let workspace = NSWorkspace.shared.notificationCenter
        let names: [(NotificationCenter, Notification.Name)] = [
            (distributed, Notification.Name("com.apple.screenIsLocked")),
            (distributed, Notification.Name("com.apple.screenIsUnlocked")),
            (workspace, NSWorkspace.screensDidSleepNotification),
            (workspace, NSWorkspace.screensDidWakeNotification),
        ]
        for (center, name) in names {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.fire() }
            }
            tokens.append((center, token))
        }
    }

    private func observePowerSource() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            let observer = Unmanaged<SystemChangeObserver>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { observer.fire() }
        }
        guard let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        powerSource = source
    }

    // The root domain announces clamshell changes to general-interest clients.
    private func observeLid() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOServiceInterestCallback = { context, _, _, _ in
            guard let context else { return }
            let observer = Unmanaged<SystemChangeObserver>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { observer.fire() }
        }
        var notifier: io_object_t = 0
        guard IOServiceAddInterestNotification(port, service, kIOGeneralInterest, callback, context, &notifier)
            == KERN_SUCCESS else {
            IONotificationPortDestroy(port)
            return
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), IONotificationPortGetRunLoopSource(port).takeUnretainedValue(), .commonModes)
        lidPort = port
        lidNotifier = notifier
    }
}
