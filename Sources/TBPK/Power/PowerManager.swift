import Foundation

@MainActor
final class PowerManager: ObservableObject {
    static let shared = PowerManager()

    @Published private(set) var isSleepDisabled = false
    @Published private(set) var isWorking = false
    @Published private(set) var hasFailure = false
    @Published private(set) var passwordlessAvailable = false
    @Published private(set) var statusMessage = PowerMessages.reading
    @Published private(set) var expiresAt: Date?
    @Published private(set) var pendingValue: Bool?
    @Published private(set) var stopNotice: String?

    // Asked before the first admin prompt; a test replaces it so no dialog opens.
    nonisolated(unsafe) static var silentModeChooser: @MainActor () -> SilentModeChoice = { SilentModeDialog.ask() }

    private var expiryTimer: Timer?
    private var syncTimer: Timer?
    private var syncInterval: TimeInterval = EnergyPlan.standard.syncTick
    private var isSyncing = false

    private init() {}

    func start() {
        refresh()
        restoreSavedSession()
        startSyncing()
    }

    private func restoreSavedSession() {
        let savedExpiry = UserDefaults.standard.double(forKey: StorageKey.savedExpiry)
        if isSleepDisabled, SleepDuration.stored.restoresAsCountdown, savedExpiry > Date().timeIntervalSince1970 {
            scheduleExpiry(at: Date(timeIntervalSince1970: savedExpiry))
            statusMessage = PowerMessages.restoredTimer
        }
    }

    func refresh() {
        hasFailure = false
        passwordlessAvailable = PrivilegedShell.canToggleWithoutPassword()
        setSleepDisabledState(PrivilegedShell.isSleepDisabled())
        if !isSleepDisabled { SleepOwnership.isOwned = false }
        guard !isSleepDisabled else {
            if expiresAt == nil { statusMessage = PowerMessages.externallyDisabled }
            return
        }
        clearExpiry()
        statusMessage = PowerMessages.idle
    }

    func enable(for duration: SleepDuration) {
        stopNotice = nil
        let wasAlreadyDisabled = isSleepDisabled
        apply(sleepDisabled: true, prompt: PowerMessages.enablePrompt) {
            if !wasAlreadyDisabled { SleepOwnership.isOwned = true }
            self.scheduleExpiry(duration)
            self.statusMessage = PowerMessages.active(for: duration)
        }
    }

    func disable() {
        apply(sleepDisabled: false, prompt: PowerMessages.disablePrompt) {
            SleepOwnership.isOwned = false
            self.clearExpiry()
            self.statusMessage = PowerMessages.idle
        }
    }

    func stopForRule(reason: String) {
        guard isSleepDisabled, !isWorking, SleepOwnership.isOwned else { return }
        stopNotice = reason
        disable()
    }

    func reschedule(_ duration: SleepDuration) {
        guard isSleepDisabled else { return }
        scheduleExpiry(duration)
        statusMessage = PowerMessages.active(for: duration)
    }

    func endAt(_ date: Date) {
        guard isSleepDisabled else { return }
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: StorageKey.customEndDate)
        scheduleExpiry(at: date)
        statusMessage = PowerMessages.untilWallClock(date)
    }

    // Stay awake until a moment: reschedules a running session, or starts one when sleep is not off yet.
    func stayAwake(until date: Date) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: StorageKey.customEndDate)
        UserDefaults.standard.set(SleepDuration.untilDate.rawValue, forKey: SleepDuration.storageKey)
        if isSleepDisabled { endAt(date) } else { enable(for: .untilDate) }
    }

    var savedEndDate: Date? {
        let seconds = UserDefaults.standard.double(forKey: StorageKey.customEndDate)
        guard seconds > Date().timeIntervalSince1970 else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    func restoreBeforeQuit() async -> RestoreOutcome {
        guard SleepOwnership.isOwned else {
            clearExpiry()
            return .restored
        }
        var failure: String?
        do {
            passwordlessAvailable = try await Self.change(
                sleepDisabled: false,
                prompt: PowerMessages.quitPrompt,
                firstTimeGrantUser: nil
            )
        } catch SleepControlError.userCancelled {
            return .cancelled
        } catch {
            failure = error.localizedDescription
            statusMessage = error.localizedDescription
        }
        setSleepDisabledState(PrivilegedShell.isSleepDisabled())
        guard !isSleepDisabled else { return .failed(failure ?? "Sleep is still disabled after the restore.") }
        SleepOwnership.isOwned = false
        clearExpiry()
        return .restored
    }

    var remainingTimeText: String? {
        guard let expiresAt else { return nil }
        return EndDateText.restoreLine(expiresAt, now: Date())
    }

    private func apply(sleepDisabled value: Bool, prompt: String, onSuccess: @escaping () -> Void) {
        guard !isWorking else { return }
        let defaults = UserDefaults.standard
        var granting = value && !passwordlessAvailable && !defaults.bool(forKey: StorageKey.silentModeDeclined)
        if granting {
            switch Self.silentModeChooser() {
            case .allow: break
            case .askEachTime:
                defaults.set(true, forKey: StorageKey.silentModeDeclined)
                granting = false
            case .cancel: return
            }
        }
        isWorking = true
        pendingValue = value
        hasFailure = false
        statusMessage = value ? PowerMessages.disabling : PowerMessages.restoring
        Task {
            do {
                let grantUser = granting ? NSUserName() : nil
                let effectivePrompt = granting ? PowerMessages.firstTimePrompt : prompt
                passwordlessAvailable = try await Self.change(
                    sleepDisabled: value,
                    prompt: effectivePrompt,
                    firstTimeGrantUser: grantUser
                )
                setSleepDisabledState(PrivilegedShell.isSleepDisabled())
                onSuccess()
            } catch {
                setSleepDisabledState(PrivilegedShell.isSleepDisabled())
                hasFailure = true
                statusMessage = error.localizedDescription
            }
            pendingValue = nil
            isWorking = false
        }
    }

    nonisolated private static func change(
        sleepDisabled value: Bool,
        prompt: String,
        firstTimeGrantUser: String?
    ) async throws -> Bool {
        try await Task.detached(priority: .userInitiated) {
            try PrivilegedShell.setSleepDisabled(value, prompt: prompt, firstTimeGrantUser: firstTimeGrantUser)
        }.value
    }

    private func scheduleExpiry(_ duration: SleepDuration) {
        if duration == .untilDate {
            if let saved = savedEndDate {
                scheduleExpiry(at: saved)
            } else {
                clearExpiry()
            }
            return
        }
        guard let seconds = duration.seconds else {
            clearExpiry()
            return
        }
        scheduleExpiry(at: Date().addingTimeInterval(seconds))
    }

    private func scheduleExpiry(at fireDate: Date) {
        expiryTimer?.invalidate()
        expiryTimer = nil
        expiresAt = fireDate
        UserDefaults.standard.set(fireDate.timeIntervalSince1970, forKey: StorageKey.savedExpiry)
        let timer = Timer(fire: fireDate, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.handleExpiry() }
        }
        RunLoop.main.add(timer, forMode: .common)
        expiryTimer = timer
    }

    private func clearExpiry() {
        expiryTimer?.invalidate()
        expiryTimer = nil
        expiresAt = nil
        UserDefaults.standard.set(0, forKey: StorageKey.savedExpiry)
    }

    private func handleExpiry() {
        clearExpiry()
        guard isSleepDisabled else { return }
        statusMessage = PowerMessages.timeIsUp
        disable()
    }

    // How often to ask the system whether sleep was switched back on elsewhere (the energy plan decides).
    func setSyncInterval(_ seconds: TimeInterval) {
        guard seconds != syncInterval else { return }
        syncInterval = seconds
        if syncTimer != nil { startSyncing() }
    }

    private func startSyncing() {
        syncTimer?.invalidate()
        let timer = Timer(timeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.syncWithSystem() }
        }
        timer.tolerance = syncInterval * 0.2
        RunLoop.main.add(timer, forMode: .common)
        syncTimer = timer
    }

    // pmset is a separate process: it is asked off the main thread so a slow answer never freezes the menu.
    private func syncWithSystem() {
        guard !isWorking, !isSyncing else { return }
        isSyncing = true
        Task {
            let current = await Task.detached(priority: .utility) { PrivilegedShell.isSleepDisabled() }.value
            isSyncing = false
            guard !isWorking, current != isSleepDisabled else { return }
            setSleepDisabledState(current)
            guard !current else { return }
            SleepOwnership.isOwned = false
            clearExpiry()
            statusMessage = PowerMessages.idle
        }
    }

    private func setSleepDisabledState(_ value: Bool) {
        guard value != isSleepDisabled else { return }
        isSleepDisabled = value
    }

    private enum StorageKey {
        static let savedExpiry = "savedExpiry"
        static let silentModeDeclined = "silentModeDeclined"
        static let customEndDate = "customEndDate"
    }

}
