import AppKit

@MainActor
enum QuitGuard {
    static func reply(for app: NSApplication, power: PowerManager) -> NSApplication.TerminateReply {
        power.refresh()
        switch QuitPlan.decide(sleepDisabled: power.isSleepDisabled, ownsOverride: SleepOwnership.isOwned) {
        case .quitNow:
            BatterySaver.restoreNow()
            return .terminateNow
        case .restoreThenQuit:
            Task { @MainActor in
                let outcome = await power.restoreBeforeQuit()
                BatterySaver.restoreNow()
                app.reply(toApplicationShouldTerminate: shouldQuit(after: outcome))
            }
            return .terminateLater
        }
    }

    private static func shouldQuit(after outcome: RestoreOutcome) -> Bool {
        switch outcome {
        case .restored: return true
        case .cancelled: return false
        case .failed(let reason): return AlertPresenter.run(failure(reason)) == .alertSecondButtonReturn
        }
    }

    private static func failure(_ reason: String) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "The previous sleep setting could not be restored"
        alert.informativeText = "\(reason)\n\nIf you quit now, this Mac will keep running until you turn sleep back on."
        alert.addButton(withTitle: "Stay Open")
        alert.addButton(withTitle: "Quit Anyway")
        return alert
    }
}
