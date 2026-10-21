import AppKit
import Combine

@main
final class TBPKMain: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?
    private var displayGuard: DisplaySleepGuard?
    private var unattended: UnattendedWatch?
    private var governor: AwakeGovernor?
    private var signalSources: [DispatchSourceSignal] = []
    private var energySubscription: AnyCancellable?

    static func main() {
        if runLoginItemCommand() { return }
        if SingleInstance.isAnotherRunning() { return }
        let app = NSApplication.shared
        let delegate = TBPKMain()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    private static func runLoginItemCommand() -> Bool {
        guard let index = CommandLine.arguments.firstIndex(of: "--set-login"),
              index + 1 < CommandLine.arguments.count else { return false }
        let value = CommandLine.arguments[index + 1].lowercased()
        guard value == "on" || value == "off" else {
            FileHandle.standardError.write(Data("usage: --set-login on|off\n".utf8))
            exit(2)
        }
        do {
            try LoginItem.setEnabled(value == "on")
            print(LoginItem.isEnabled ? "login item: on" : "login item: off")
        } catch {
            FileHandle.standardError.write(Data("login item: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
        exit(0)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AlertVolumeLift.restorePending()
        BatterySaver.restoreNow()
        AppLeftovers.sweepInBackground()
        followEnergyPlan()
        PowerManager.shared.start()
        let watch = UnattendedWatch(power: PowerManager.shared)
        unattended = watch
        statusItem = StatusItemController(power: PowerManager.shared, watch: watch)
        let guardian = DisplaySleepGuard()
        displayGuard = guardian
        governor = AwakeGovernor(power: PowerManager.shared, displayGuard: guardian)
        statusItem?.governor = governor
        routeTerminationSignalsThroughQuit()
        UpdateCoordinator.shared.startSchedule()
        if WhatsNewWindow.shouldShowAtLaunch(current: AppInfo.version) { statusItem?.whatsNewClicked() }
    }

    // Every timer asks the energy plan how often to wake up; the power sync is told here, the others subscribe themselves.
    @MainActor private func followEnergyPlan() {
        let energy = EnergyMonitor.shared
        energy.start()
        PowerManager.shared.setSyncInterval(energy.plan.syncTick)
        energySubscription = energy.objectWillChange
            .receive(on: RunLoop.main)
            .sink { PowerManager.shared.setSyncInterval(EnergyMonitor.shared.plan.syncTick) }
    }

    private func routeTerminationSignalsThroughQuit() {
        for number in [SIGTERM, SIGHUP, SIGINT] {
            signal(number, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
            source.setEventHandler { Self.terminateFromSignal() }
            source.resume()
            signalSources.append(source)
        }
    }

    // Not NSApp.terminate: a nested run loop inside this main-queue handler would starve the main queue
    // and the restore could never report back.
    private static func terminateFromSignal() {
        Task.detached {
            if SleepOwnership.isOwned, PrivilegedShell.restoreSleepWithoutPassword() { SleepOwnership.isOwned = false }
            BatterySaver.restoreNow()
            await MainActor.run { AlertVolumeLift.restorePending() }
            exit(0)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        QuitGuard.reply(for: sender, power: PowerManager.shared)
    }

    func applicationWillTerminate(_ notification: Notification) {
        AlertVolumeLift.restorePending()
        BatterySaver.restoreNow()
        guard SleepOwnership.isOwned, PrivilegedShell.isSleepDisabled() else { return }
        if PrivilegedShell.restoreSleepWithoutPassword() { SleepOwnership.isOwned = false }
    }
}
