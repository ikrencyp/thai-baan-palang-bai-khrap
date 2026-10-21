import AppKit
import Combine

@MainActor
final class StatusItemController: NSObject, StatusMenuTarget {
    private let power: PowerManager
    private let watch: UnattendedWatch
    private let energy = EnergyMonitor.shared
    weak var governor: AwakeGovernor?
    // Variable length: a square item clips the countdown text.
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var subscriptions: [AnyCancellable] = []
    private var countdownTimer: Timer?
    private lazy var powerObserver = SystemChangeObserver { [weak self] in self?.render() }
    private lazy var animator = StatusIconAnimator { [weak self] image in
        self?.statusItem.button?.image = image
    }

    init(power: PowerManager, watch: UnattendedWatch) {
        self.power = power
        self.watch = watch
        super.init()
        statusItem.button?.target = self
        statusItem.button?.action = #selector(buttonClicked(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        subscriptions = [
            power.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.render() },
            watch.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.render() },
            energy.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.render() },
        ]
        powerObserver.start()
        UpdateCoordinator.shared.onChange = { [weak self] in self?.render() }
        render()
    }

    private lazy var updateBadge: UpdateBadgeView = {
        let badge = UpdateBadgeView(frame: NSRect(x: 0, y: 0, width: UpdateBadgeView.size, height: UpdateBadgeView.size))
        badge.translatesAutoresizingMaskIntoConstraints = false
        guard let button = statusItem.button else { return badge }
        button.addSubview(badge)
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: UpdateBadgeView.size),
            badge.heightAnchor.constraint(equalToConstant: UpdateBadgeView.size),
            badge.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 1),
            badge.topAnchor.constraint(equalTo: button.topAnchor, constant: 1),
        ])
        return badge
    }()

    private var pendingUpdate: AppVersion? { UpdateStore.isOfferedHere() ? UpdateCoordinator.shared.pending : nil }

    @objc private func buttonClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            toggle()
        } else {
            popMenu()
        }
    }

    private func toggle() {
        if power.isSleepDisabled {
            power.disable()
        } else {
            power.enable(for: SleepDuration.stored)
        }
    }

    private func popMenu() {
        let menu = StatusMenuBuilder.build(power: power, watch: watch, target: self)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: statusItem.button?.bounds.maxY ?? 0), in: statusItem.button)
    }

    private func render() {
        updateBadge.isHidden = pendingUpdate == nil
        statusItem.button?.toolTip = toolTip()
        let plan = energy.plan
        animator.retarget(iconTarget(plan), animated: StatusPreferences.showAnimation && plan.animatesTransitions)
        setCountdownTitle(countdownTitle())
        syncCountdownTicker()
    }

    private var runsOnBattery: Bool {
        power.isSleepDisabled && UnattendedSnapshot.isOnBattery
    }

    private func iconTarget(_ plan: EnergyPlan) -> IconTarget {
        let icon = currentIcon()
        return IconTarget(
            awake: power.pendingValue ?? icon.isAwake,
            busy: icon == .busy || power.pendingValue != nil,
            failed: icon == .failed,
            alerting: watch.isAlerting || runsOnBattery,
            beating: icon.isPulsing && plan.beatEvery != nil,
            beatEvery: plan.beatEvery ?? Heartbeat.period
        )
    }

    private func toolTip() -> String {
        let label = currentIcon().accessibilityLabel + (pendingUpdate.map { ", update \($0.text) available" } ?? "")
        guard watch.isAlerting || runsOnBattery else { return label }
        return label + ", running on battery"
    }

    // One wake-up per change of the text: every second, or once a minute when the plan shows whole minutes.
    // Nothing runs while the display is asleep; waking it re-renders.
    private func syncCountdownTicker() {
        guard StatusPreferences.showCountdown, let expiresAt = power.expiresAt, energy.plan.isVisible else {
            countdownTimer?.invalidate()
            countdownTimer = nil
            return
        }
        let remaining = expiresAt.timeIntervalSinceNow
        let coarse = energy.plan.coarseCountdown
        let delay = coarse ? ClockText.untilCoarseChange(remaining) + 0.1 : 1
        // A render can come at any moment; a timer that is already due soon enough is left to run.
        if let running = countdownTimer, running.isValid, running.fireDate.timeIntervalSinceNow <= delay + 0.2 { return }
        countdownTimer?.invalidate()
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.setCountdownTitle(self.countdownTitle())
                self.syncCountdownTicker()
            }
        }
        timer.tolerance = coarse ? 1 : 0.1
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
    }

    private func countdownTitle() -> String {
        guard StatusPreferences.showCountdown, let expiresAt = power.expiresAt else { return "" }
        let remaining = expiresAt.timeIntervalSinceNow
        return " \(energy.plan.coarseCountdown ? ClockText.coarse(remaining) : ClockText.short(remaining))"
    }

    private func setCountdownTitle(_ text: String) {
        guard let button = statusItem.button else { return }
        // Plain title: the status bar picks the right colour for its own appearance.
        button.title = text
    }

    private func currentIcon() -> MenuBarIcon {
        MenuBarIcon.resolve(
            isSleepDisabled: power.isSleepDisabled,
            isWorking: power.isWorking,
            hasTimer: power.expiresAt != nil,
            hasFailure: power.hasFailure
        )
    }

    @objc func enableClicked() {
        power.enable(for: SleepDuration.stored)
    }

    @objc func disableClicked() {
        power.disable()
    }

    @objc func durationClicked(_ item: NSMenuItem) {
        guard let raw = item.representedObject as? String, let duration = SleepDuration(rawValue: raw) else { return }
        if duration == .untilDate {
            promptForEndDate()
            return
        }
        UserDefaults.standard.set(raw, forKey: SleepDuration.storageKey)
        power.reschedule(duration)
    }

    @objc func favoriteEndClicked(_ item: NSMenuItem) {
        guard let key = item.representedObject as? String, let pick = EndDatePick(key: key) else { return }
        EndDateFavorites.record(pick)
        power.stayAwake(until: pick.moment(now: Date()))
        render()
    }

    @objc func clearFavoritesClicked() {
        EndDateFavorites.clear()
    }

    @objc func countdownClicked(_ item: NSMenuItem) {
        StatusPreferences.toggleCountdown()
        render()
    }

    @objc func animationClicked(_ item: NSMenuItem) {
        StatusPreferences.toggleAnimation()
        render()
    }

    @objc func energyProfileClicked(_ item: NSMenuItem) {
        guard let raw = item.representedObject as? String, let profile = EnergyProfile(rawValue: raw) else { return }
        profile.store()
        energy.refresh()
        render()
    }

    @objc func batteryWarningClicked(_ item: NSMenuItem) {
        guard let raw = item.representedObject as? String, let mode = LidWarningMode(rawValue: raw) else { return }
        watch.setMode(mode)
        render()
    }

    @objc func warningPowerClicked(_ item: NSMenuItem) {
        guard let raw = item.representedObject as? String, let condition = PowerCondition(rawValue: raw) else { return }
        watch.setPowerCondition(condition)
        render()
    }

    @objc func testAlertClicked() {
        AttentionSound.playOnce()
    }

    @objc func alertSoundClicked(_ item: NSMenuItem) {
        guard let name = item.representedObject as? String else { return }
        AlertSound(name: name).store()
    }

    @objc func chooseSoundClicked() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.title = "Add sound files"
        panel.message = "AIFF, WAV, MP3, M4A, AAC or CAF, up to \(Int(CustomSoundLibrary.maxSeconds)) seconds each. Pick one or several."
        panel.prompt = "Add"
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.level = .floating
        guard panel.runModal() == .OK else { return }
        addSounds(from: panel.urls)
    }

    // Every file is tried; the last one that works is selected, and the ones that did not work are listed together.
    private func addSounds(from urls: [URL]) {
        var added: AlertSound?
        var refused: [String] = []
        for url in urls {
            do { added = try CustomSoundLibrary.add(url) } catch {
                refused.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        added?.store()
        guard !refused.isEmpty else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = refused.count == 1 ? "This sound cannot be used" : "\(refused.count) sounds cannot be used"
        alert.informativeText = refused.joined(separator: "\n")
        alert.addButton(withTitle: "OK")
        AlertPresenter.run(alert)
    }

    @objc func removeCustomSoundClicked(_ item: NSMenuItem) {
        guard let name = item.representedObject as? String else { return }
        let sound = AlertSound(name: name)
        let alert = NSAlert()
        alert.messageText = "Remove \u{201C}\(sound.displayName)\u{201D}?"
        alert.informativeText = "TBPK deletes its own copy of this sound. The file you added it from is not touched."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        guard AlertPresenter.run(alert) == .alertFirstButtonReturn else { return }
        if AlertSound.stored == sound { AlertSound.systemAlert.store() }
        CustomSoundLibrary.remove(sound)
    }

    @objc func sharedBeepCountClicked() {
        let sound = AlertSound.stored
        let current = AlertBeepCount.stored(for: sound)
        AlertBeepCount.setShared(!AlertBeepCount.isShared())
        AlertBeepCount.store(current, for: sound)
    }

    @objc func powerLimitClicked(_ item: NSMenuItem) {
        guard let raw = item.representedObject as? String, let limit = PowerLimit(rawValue: raw) else { return }
        UserDefaults.standard.set(limit.rawValue, forKey: PowerLimit.storageKey)
        governor?.evaluate()
    }

    @objc func keepScreenClicked() {
        StatusPreferences.toggleKeepScreenOn()
        governor?.evaluate()
    }

    @objc func darkenClicked() {
        StatusPreferences.toggleDarkenWhenClosed()
        governor?.evaluate()
    }

    @objc func batterySaverClicked() {
        guard !BatterySaver.isEnabled else {
            BatterySaver.setEnabled(false)
            governor?.evaluate()
            return
        }
        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    guard !PrivilegedShell.canSavePowerWithoutPassword() else { return }
                    try PrivilegedShell.installPasswordlessRule(for: NSUserName(), prompt: PowerMessages.batterySaverPrompt)
                }.value
                BatterySaver.setEnabled(true)
                governor?.evaluate()
            } catch SleepControlError.userCancelled {
                return
            } catch {
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = "Low Power Mode could not be set up"
                alert.informativeText = error.localizedDescription
                alert.addButton(withTitle: "OK")
                AlertPresenter.run(alert)
            }
        }
    }

    @objc func beepCountClicked(_ item: NSMenuItem) {
        guard let raw = item.representedObject as? Int, let count = AlertBeepCount(rawValue: raw) else { return }
        AlertBeepCount.store(count, for: AlertSound.stored)
    }

    @objc func alertVolumeChanged(_ sender: NSSlider) {
        AlertVolumeLift.storedLevel = Float32(sender.doubleValue)
        let label = sender.superview?.viewWithTag(SoundMenu.percentTag) as? NSTextField
        label?.stringValue = SoundMenu.percentText(AlertVolumeLift.storedLevel)
    }

    @objc func loginClicked() {
        do {
            try LoginItem.setEnabled(!LoginItem.isEnabled)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not change Start at Login"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK")
            AlertPresenter.run(alert)
        }
    }

    @objc func updateClicked() {
        UpdateCoordinator.shared.installPending()
    }

    @objc func updateOptionClicked(_ item: NSMenuItem) {
        guard let key = item.representedObject as? String else { return }
        let defaults = UserDefaults.standard
        let on: Bool
        switch key {
        case UpdateStore.checkAutomaticallyKey: on = UpdateStore.checksAutomatically()
        case UpdateStore.downloadAutomaticallyKey: on = defaults.object(forKey: key) as? Bool ?? true
        default: on = UpdateStore.installsAutomatically()
        }
        UpdateStore.set(key, !on)
    }

    @objc func quitClicked() {
        NSApp.terminate(nil)
    }

    @objc func helpClicked() {
        InfoWindow.show(id: "help", title: "How to use", size: NSSize(width: 480, height: 600)) { HelpView() }
    }

    @objc func whatsNewClicked() {
        WhatsNewWindow.show()
    }

    @objc func aboutClicked() {
        InfoWindow.show(id: "about", title: "About", size: NSSize(width: 340, height: 330)) {
            AboutView(showHelp: { [weak self] in self?.helpClicked() }, showWhatsNew: { [weak self] in self?.whatsNewClicked() })
        }
    }

    private func promptForEndDate() {
        EndDateWindow.present(defaultDate: power.savedEndDate) { [weak self] picked in
            guard let self else { return }
            self.power.stayAwake(until: picked)
            self.render()
        }
    }
}
