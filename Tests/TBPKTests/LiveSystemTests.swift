import AppKit
import CoreAudio
import XCTest
@testable import TBPK

// Runs against this very Mac: real pmset, real power assertion, real speaker. Skipped unless TBPK_LIVE=1.
// It needs the sudoers rule TBPK installs (sudo -n must work for pmset), puts back every setting it changes, and is
// not part of CI. Run it with:  TBPK_LIVE=1 swift test --filter LiveSystemTests
@MainActor
final class LiveSystemTests: XCTestCase {
    private var armed = false
    private var savedKeys: [String: Any?] = [:]

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["TBPK_LIVE"] == "1", "set TBPK_LIVE=1 to run against this Mac")
        try XCTSkipIf(PrivilegedShell.isSleepDisabled(), "sleep is already disabled here, so this test will not touch it")
        try XCTSkipUnless(PrivilegedShell.canToggleWithoutPassword(), "no passwordless sudo rule for pmset on this Mac")
        for key in [SleepOwnership.storageKey, AlertVolumeLift.storageKey, "savedExpiry"] {
            savedKeys[key] = UserDefaults.standard.object(forKey: key)
        }
        armed = true
    }

    override func tearDown() {
        guard armed else { return }
        _ = PrivilegedShell.restoreSleepWithoutPassword()
        AlertVolumeLift.restorePending()
        for (key, value) in savedKeys { UserDefaults.standard.set(value, forKey: key) }
    }

    private func waitUntil(_ seconds: TimeInterval, _ condition: () -> Bool) async -> Bool {
        let end = Date().addingTimeInterval(seconds)
        while Date() < end {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return condition()
    }

    func testPmsetRoundTripChangesTheRealSystemSetting() throws {
        XCTAssertTrue(try PrivilegedShell.setSleepDisabled(true, prompt: "live test"), "the passwordless path is used")
        XCTAssertTrue(PrivilegedShell.isSleepDisabled(), "pmset -g reports SleepDisabled 1")
        XCTAssertTrue(try PrivilegedShell.setSleepDisabled(false, prompt: "live test"))
        XCTAssertFalse(PrivilegedShell.isSleepDisabled(), "and 0 again")
    }

    func testSwitchingOnAndOffThroughThePowerManager() async {
        let manager = PowerManager.shared
        PowerManager.silentModeChooser = { .cancel }
        manager.refresh()
        manager.enable(for: .thirtyMinutes)
        let on = await waitUntil(8) { manager.isSleepDisabled && !manager.isWorking }
        XCTAssertTrue(on, "the manager reports sleep disabled")
        XCTAssertTrue(PrivilegedShell.isSleepDisabled(), "and the system agrees")
        XCTAssertTrue(SleepOwnership.isOwned, "the app remembers it was the one that switched it on")
        let left = (manager.expiresAt ?? .distantPast).timeIntervalSinceNow
        XCTAssertEqual(left, 1800, accuracy: 10, "the 30 minute timer is running")

        manager.disable()
        let off = await waitUntil(8) { !manager.isSleepDisabled && !manager.isWorking }
        XCTAssertTrue(off, "the manager reports normal sleep again")
        XCTAssertFalse(PrivilegedShell.isSleepDisabled())
        XCTAssertFalse(SleepOwnership.isOwned)
        XCTAssertNil(manager.expiresAt, "the timer is gone")
    }

    func testTheTimerPutsNormalSleepBackByItself() async {
        let manager = PowerManager.shared
        PowerManager.silentModeChooser = { .cancel }
        manager.refresh()
        manager.stayAwake(until: Date().addingTimeInterval(4))
        let started = await waitUntil(8) { manager.isSleepDisabled && !manager.isWorking }
        XCTAssertTrue(started, "switched on")
        let ended = await waitUntil(20) { !manager.isSleepDisabled && !manager.isWorking }
        XCTAssertTrue(ended, "when the time is up the app restores normal sleep")
        XCTAssertFalse(PrivilegedShell.isSleepDisabled(), "the system agrees")
    }

    func testTheDisplayAssertionIsReallyHeldAndReleased() throws {
        let guardian = DisplaySleepGuard()
        func assertions() throws -> String {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            process.arguments = ["-g", "assertions"]
            let pipe = Pipe()
            process.standardOutput = pipe
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(decoding: data, as: UTF8.self)
        }
        XCTAssertFalse(try assertions().contains("Thai Baan Palang Bai Khrap is holding"))
        guardian.setHolding(true)
        XCTAssertTrue(try assertions().contains("Thai Baan Palang Bai Khrap is holding"), "pmset lists the assertion")
        guardian.setHolding(false)
        XCTAssertFalse(try assertions().contains("Thai Baan Palang Bai Khrap is holding"), "and it is gone after release")
    }

    func testTheSnapshotReadsThisMacsRealState() {
        let snapshot = UnattendedSnapshot.read(buzzing: false)
        print("LIVE snapshot:", snapshot.summary, "| battery:", UnattendedSnapshot.hasBattery, "| on battery:", UnattendedSnapshot.isOnBattery)
        XCTAssertFalse(snapshot.lidClosed, "the lid is open while this test runs")
        XCTAssertFalse(snapshot.screenLocked, "the screen is unlocked while this test runs")
        XCTAssertFalse(snapshot.isUnattended(under: .anyPower), "so nothing counts as unattended")
    }

    func testTheSpeakerIsLiftedAndPutBackExactly() async throws {
        let speaker = try XCTUnwrap(AlertRoute.speaker(), "the Mac has a built-in output")
        let sources = AudioOutput.dataSources(of: speaker.device)
        XCTAssertTrue(sources.isEmpty || sources.contains(AlertRoute.speakerSource), "the chosen output can play on the speakers, not only the headphone jack: \(speaker.uid) \(sources)")
        let elements = AudioOutput.volumeElements(of: speaker.device)
        XCTAssertFalse(elements.isEmpty, "the speaker has a volume control")
        func volumes() -> [AudioObjectPropertyElement: Float32] {
            Dictionary(uniqueKeysWithValues: elements.compactMap { element in AudioOutput.readVolume(speaker.device, element).map { (element, $0) } })
        }
        let before = volumes()
        let mutedBefore = AudioOutput.readMute(speaker.device)
        AlertVolumeLift.storedLevel = 0.2
        print("LIVE speaker uid:", speaker.uid, "volumes before:", before, "muted:", String(describing: mutedBefore), "plan:", AlertRoute.plan(for: speaker))

        XCTAssertTrue(AlertVolumeLift.lift(speaker), "lifting is allowed on this output")
        let lifted = volumes()
        for (element, original) in before { XCTAssertGreaterThanOrEqual(lifted[element] ?? 0, original, "never turned down") }
        AlertVolumeLift.restorePending()
        let after = volumes()
        for (element, original) in before { XCTAssertEqual(after[element] ?? -1, original, accuracy: 0.001, "put back exactly") }
        XCTAssertEqual(AudioOutput.readMute(speaker.device), mutedBefore, "mute is put back too")
    }

    func testTheAlertPlaysOnTheBuiltInSpeakerAndLeavesTheVolumeAlone() async throws {
        let speaker = try XCTUnwrap(AlertRoute.speaker())
        let elements = AudioOutput.volumeElements(of: speaker.device)
        let before = elements.compactMap { AudioOutput.readVolume(speaker.device, $0) }
        AlertVolumeLift.storedLevel = 0.2
        AttentionSound.playOnce()
        try await Task.sleep(nanoseconds: UInt64((AttentionSound.alertSoundLength + 1.5) * 1_000_000_000))
        let after = elements.compactMap { AudioOutput.readVolume(speaker.device, $0) }
        XCTAssertEqual(after.count, before.count)
        for (old, new) in zip(before, after) { XCTAssertEqual(new, old, accuracy: 0.001, "volume restored after the alert") }
    }
}
