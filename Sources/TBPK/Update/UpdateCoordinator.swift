import AppKit

@MainActor
final class UpdateCoordinator {
    static let shared = UpdateCoordinator()

    enum Phase { case idle, checking, downloading }

    private(set) var phase: Phase = .idle { didSet { onChange?() } }
    var onChange: (() -> Void)?

    var pending: AppVersion? {
        AppVersion(AppInfo.version).flatMap { UpdateStore.pending(current: $0) }
    }

    private var scheduleTimer: Timer?

    // A quiet check 15 seconds after launch, then every half hour the app asks whether one is due (every 6 hours),
    // so an app left running for days still finds new versions.
    func startSchedule() {
        discardStaleDownload()
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in self?.checkQuietlyIfDue() }
        let timer = Timer(timeInterval: 1800, repeats: true) { [weak self] _ in
            AppLeftovers.sweepInBackground()
            Task { @MainActor [weak self] in self?.checkQuietlyIfDue() }
        }
        timer.tolerance = 300
        RunLoop.main.add(timer, forMode: .common)
        scheduleTimer = timer
    }

    // Like macOS Software Update, in three steps that each have a switch: look, download, install.
    // Quiet means no window. Installing by itself only goes ahead while Keep awake is off, so a running session is
    // never cut short; otherwise the update waits, downloaded, in the menu. Without that switch a new version is
    // offered once in a dialog, then it waits in the menu.
    func checkQuietlyIfDue(canRestartNow: @MainActor @escaping () -> Bool = { !PowerManager.shared.isSleepDisabled }) {
        guard phase == .idle, UpdateStore.isDue() else { return }
        Task {
            guard case .available(let text) = await check(), let version = AppVersion(text) else { return }
            let wantsDownload = UpdateStore.downloadsAutomatically()
            let downloaded = wantsDownload ? await download(version) : false
            if UpdateStore.installsAutomatically() {
                if downloaded, canRestartNow() { install(version) }
            } else if downloaded || !wantsDownload {
                // A release whose download failed (or did not match its checksum) is not announced: the dialog would
                // promise an install that cannot happen.
                offerOnce(text)
            }
        }
    }

    private func offerOnce(_ version: String) {
        guard UpdateStore.shouldAnnounce(version) else { return }
        confirmInstall(of: version)
    }

    private func discardStaleDownload() {
        guard let current = AppVersion(AppInfo.version), UpdateStore.pending(current: current) == nil else { return }
        UpdateStore.clearDownload().map { try? FileManager.default.removeItem(at: $0) }
    }

    func checkAndReport() {
        guard phase == .idle else { return }
        Task {
            UpdateProgressPanel.show("Checking for updates…", detail: "Looking for the newest version. This usually takes a few seconds.")
            let outcome = await check()
            UpdateProgressPanel.hide()
            switch outcome {
            case .upToDate: report("You are up to date", "\(AppInfo.versionLine) is the newest version.")
            case .unreachable where UpdateStore.hasReachedRepository():
                report("Could not check for updates", "GitHub is not reachable right now. Try again later.")
            case .unreachable:
                report("Updates are not available on this Mac",
                       "This Mac cannot reach GitHub, so it cannot check or install updates. The update items are hidden from now on. New versions are on the project's GitHub Releases page.")
            case .available(let version): confirmInstall(of: version)
            }
        }
    }

    func installPending() {
        guard phase == .idle, let version = pending else { return checkAndReport() }
        confirmInstall(of: version.text)
    }

    // One small request to the GitHub releases API; the dmg is downloaded only when a newer version exists.
    private func check() async -> UpdateOutcome {
        phase = .checking
        defer { phase = .idle }
        let current = AppVersion(AppInfo.version)
        switch await UpdateSource.lookUp() {
        case .unreachable:
            UpdateStore.recordFailure()
            return .unreachable
        case .noRelease:
            UpdateStore.record(found: nil)
            return .upToDate
        case .found(let latest):
            let newer = current.map { latest.version > $0 } ?? false
            UpdateStore.record(found: newer ? latest.version : nil, notes: latest.notes, assets: (latest.dmg, latest.checksum))
            return newer ? .available(latest.version.text) : .upToDate
        }
    }

    private func confirmInstall(of version: String) {
        UpdateStore.markAnnounced(version)
        let ready = AppVersion(version).flatMap { UpdateStore.downloadedRoot(for: $0) } != nil
        let alert = NSAlert()
        alert.messageText = ready ? "Version \(version) is ready to install" : "Version \(version) is available"
        let notes = UpdateStore.pendingNotes().map { "What is new:\n\($0)\n\n" } ?? ""
        let steps = ready ? "TBPK will quit, install it and open again." : "TBPK will download the update, quit, install it and open again."
        alert.informativeText = "\(notes)You have \(AppInfo.version). \(steps) Keep awake turns off while it restarts."
        alert.addButton(withTitle: ready ? "Restart and Install" : "Install and Restart")
        alert.addButton(withTitle: "Not now")
        guard AlertPresenter.run(alert) == .alertFirstButtonReturn else { return }
        install(AppVersion(version))
    }

    // Quiet download into the app's data folder; the finished copy is remembered so installing is instant.
    private func download(_ version: AppVersion, progress: (@Sendable (Double) -> Void)? = nil) async -> Bool {
        if UpdateStore.downloadedRoot(for: version) != nil { return true }
        phase = .downloading
        defer { phase = .idle }
        let base = UpdateInstaller.downloadFolder
        guard let assets = UpdateStore.availableAssets() else { return false }
        let latest = UpdateSource.Latest(version: version, tag: "v\(version.text)", notes: nil, dmg: assets.dmg, checksum: assets.checksum)
        let checkout = await UpdateSource.fetch(latest, in: base, progress: progress)
        guard let checkout, checkout.installer(for: version) != nil else {
            checkout?.remove()
            return false
        }
        UpdateStore.clearDownload().map { try? FileManager.default.removeItem(at: $0) }
        UpdateStore.recordDownload(version, at: checkout.root)
        return true
    }

    private func install(_ version: AppVersion?) {
        guard let version else { return }
        Task {
            if UpdateStore.downloadedRoot(for: version) == nil {
                UpdateProgressPanel.show("Downloading version \(version.text)…",
                                         detail: "The app restarts by itself when the update is installed.", step: .download)
                let ok = await download(version) { fraction in
                    Task { @MainActor in UpdateProgressPanel.setProgress(fraction) }
                }
                guard ok else {
                    UpdateProgressPanel.hide()
                    return report("The update could not be downloaded",
                                  "Version \(version.text) is not ready to install yet, or GitHub was not reachable. Try again later.")
                }
            }
            guard let root = UpdateStore.downloadedRoot(for: version) else { return UpdateProgressPanel.hide() }
            let checkout = ReleaseCheckout.existing(at: root)
            guard let script = checkout.installer(for: version) else {
                UpdateProgressPanel.hide()
                UpdateStore.clearDownload()
                checkout.remove()
                return report("The update could not be installed", "The downloaded copy is incomplete. Check for updates again.")
            }
            // Keep awake is turned off here, where a failure can be shown, not inside the quit: a quit that is
            // refused or waits for a password would leave the app open and the install waiting for nothing.
            UpdateProgressPanel.show("Preparing to install…", detail: "Keep awake is turned off first.", step: .prepare)
            switch await PowerManager.shared.restoreBeforeQuit() {
            case .restored: break
            case .cancelled:
                return UpdateProgressPanel.hide()
            case .failed(let reason):
                UpdateProgressPanel.hide()
                return report("The update was not installed",
                              "Keep awake could not be turned off, so the app was not closed.\n\n\(reason)")
            }
            do {
                UpdateProgressPanel.show("Installing version \(version.text)…", detail: "The app closes now and opens again in a moment.", step: .install)
                try UpdateInstaller.installAfterQuit(checkout, script: script)
                UpdateStore.clearDownload()
                NSApp.terminate(nil)
            } catch {
                UpdateProgressPanel.hide()
                report("The update could not be started", error.localizedDescription)
            }
        }
    }

    private func report(_ title: String, _ detail: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.addButton(withTitle: "OK")
        AlertPresenter.run(alert)
    }
}
