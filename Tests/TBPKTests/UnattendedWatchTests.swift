import Combine
import XCTest
@testable import TBPK

@MainActor
final class UnattendedWatchTests: XCTestCase {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    private func preserveWatchDefaults() {
        let defaults = UserDefaults.standard
        let savedMode = defaults.object(forKey: LidWarningMode.storageKey)
        let savedCondition = defaults.object(forKey: PowerCondition.storageKey)
        let savedEvent = UnattendedEvent.stored
        addTeardownBlock {
            if let savedMode { defaults.set(savedMode, forKey: LidWarningMode.storageKey) }
            else { defaults.removeObject(forKey: LidWarningMode.storageKey) }
            if let savedCondition { defaults.set(savedCondition, forKey: PowerCondition.storageKey) }
            else { defaults.removeObject(forKey: PowerCondition.storageKey) }
            if let savedEvent { savedEvent.store() } else { UnattendedEvent.clearStored() }
        }
    }

    func testShouldWatchStopsWhenTurnedOffDisablingOrExpired() {
        XCTAssertFalse(UnattendedWatch.shouldWatch(
            mode: .off, hasBattery: true, isSleepDisabled: true, pendingValue: nil, expiresAt: nil, now: epoch))
        XCTAssertFalse(UnattendedWatch.shouldWatch(
            mode: .everyFiveMinutes, hasBattery: false, isSleepDisabled: true, pendingValue: nil, expiresAt: nil, now: epoch))
        XCTAssertFalse(UnattendedWatch.shouldWatch(
            mode: .everyFiveMinutes, hasBattery: true, isSleepDisabled: false, pendingValue: nil, expiresAt: nil, now: epoch))
        XCTAssertFalse(UnattendedWatch.shouldWatch(
            mode: .everyFiveMinutes, hasBattery: true, isSleepDisabled: true, pendingValue: false, expiresAt: nil, now: epoch))
        XCTAssertFalse(UnattendedWatch.shouldWatch(
            mode: .everyFiveMinutes, hasBattery: true, isSleepDisabled: true, pendingValue: nil, expiresAt: epoch, now: epoch))
        XCTAssertFalse(UnattendedWatch.shouldWatch(
            mode: .everyFiveMinutes, hasBattery: true, isSleepDisabled: true, pendingValue: nil,
            expiresAt: epoch.addingTimeInterval(-1), now: epoch))

        XCTAssertTrue(UnattendedWatch.shouldWatch(
            mode: .everyFiveMinutes, hasBattery: true, isSleepDisabled: true, pendingValue: nil,
            expiresAt: epoch.addingTimeInterval(1), now: epoch))
        XCTAssertTrue(UnattendedWatch.shouldWatch(
            mode: .everyFiveMinutes, hasBattery: true, isSleepDisabled: true, pendingValue: nil, expiresAt: nil, now: epoch))
        XCTAssertTrue(UnattendedWatch.shouldWatch(
            mode: .everyFiveMinutes, hasBattery: true, isSleepDisabled: true, pendingValue: true, expiresAt: nil, now: epoch))
    }

    func testTickNeverPlaysWhenDisablingOrExpiredOrSystemAlreadySlept() {
        preserveWatchDefaults()
        UserDefaults.standard.set(LidWarningMode.everyFiveMinutes.rawValue, forKey: LidWarningMode.storageKey)
        UserDefaults.standard.set(PowerCondition.batteryOnly.rawValue, forKey: PowerCondition.storageKey)

        var currentNow = epoch
        var state = UnattendedWatch.PowerState(isSleepDisabled: true, pendingValue: nil, expiresAt: nil)
        var systemAwake = true
        var expireCalls = 0
        var refreshCalls = 0
        var playCount = 0
        var stopCount = 0
        let changes = PassthroughSubject<Void, Never>()

        let watch = UnattendedWatch(
            powerChanges: changes.eraseToAnyPublisher(),
            powerState: { state },
            expireIfDue: { _ in expireCalls += 1 },
            refreshPower: { refreshCalls += 1; state = .init(isSleepDisabled: false, pendingValue: nil, expiresAt: nil) },
            systemSleepDisabled: { systemAwake },
            hasBattery: { true },
            readSnapshot: { UnattendedSnapshot(lidClosed: true, screenLocked: false, onBattery: true, buzzing: true) },
            now: { currentNow },
            playAlert: { playCount += 1 },
            stopAlert: { stopCount += 1 }
        )

        // Turning off in progress (pendingValue == false) must stop watching even while isSleepDisabled is still true.
        state = .init(isSleepDisabled: true, pendingValue: false, expiresAt: nil)
        changes.send(())
        let stopsAtDisable = stopCount
        XCTAssertGreaterThan(stopsAtDisable, 0)
        currentNow = epoch.addingTimeInterval(UnattendedDecision.holdTime)
        watch.tick()
        XCTAssertEqual(playCount, 0)
        XCTAssertFalse(watch.isAlerting)

        // Re-arm with a countdown that is now due: expireIfDue + expiry boundary must settle without playing.
        currentNow = epoch
        state = .init(isSleepDisabled: true, pendingValue: nil, expiresAt: epoch.addingTimeInterval(10))
        changes.send(())
        currentNow = epoch.addingTimeInterval(10)
        watch.tick()
        XCTAssertGreaterThan(expireCalls, 0)
        XCTAssertEqual(playCount, 0)
        XCTAssertFalse(watch.isAlerting)

        // Cached awake state when macOS sleep is already back on externally must refresh and settle before playing.
        currentNow = epoch
        state = .init(isSleepDisabled: true, pendingValue: nil, expiresAt: nil)
        systemAwake = false
        changes.send(())
        watch.tick()
        currentNow = epoch.addingTimeInterval(UnattendedDecision.holdTime)
        watch.tick()
        XCTAssertEqual(refreshCalls, 1)
        XCTAssertEqual(playCount, 0)
        XCTAssertFalse(watch.isAlerting)
    }

    func testTickPlaysWhenAwakeAndStopsPromptlyWhenTurnedOff() {
        preserveWatchDefaults()
        UserDefaults.standard.set(LidWarningMode.everyFiveMinutes.rawValue, forKey: LidWarningMode.storageKey)
        UserDefaults.standard.set(PowerCondition.batteryOnly.rawValue, forKey: PowerCondition.storageKey)

        var currentNow = epoch
        var state = UnattendedWatch.PowerState(isSleepDisabled: true, pendingValue: nil, expiresAt: epoch.addingTimeInterval(60))
        var playCount = 0
        var stopCount = 0
        let changes = PassthroughSubject<Void, Never>()

        let watch = UnattendedWatch(
            powerChanges: changes.eraseToAnyPublisher(),
            powerState: { state },
            systemSleepDisabled: { true },
            hasBattery: { true },
            readSnapshot: { UnattendedSnapshot(lidClosed: true, screenLocked: false, onBattery: true, buzzing: true) },
            now: { currentNow },
            playAlert: { playCount += 1 },
            stopAlert: { stopCount += 1 }
        )

        watch.tick()
        currentNow = epoch.addingTimeInterval(UnattendedDecision.holdTime)
        watch.tick()
        XCTAssertEqual(playCount, 1)
        XCTAssertTrue(watch.isAlerting)

        let stopsBeforeTurnOff = stopCount
        state = .init(isSleepDisabled: false, pendingValue: nil, expiresAt: nil)
        changes.send(())
        XCTAssertEqual(stopCount, stopsBeforeTurnOff + 1)
        XCTAssertFalse(watch.isAlerting)

        // Changing alert mode or power condition while alerting also stops the active alert immediately.
        state = .init(isSleepDisabled: true, pendingValue: nil, expiresAt: epoch.addingTimeInterval(60))
        changes.send(())
        watch.tick()
        currentNow = epoch.addingTimeInterval(UnattendedDecision.holdTime)
        watch.tick()
        XCTAssertTrue(watch.isAlerting)

        let stopsBeforeCondition = stopCount
        watch.setPowerCondition(.anyPower)
        XCTAssertEqual(stopCount, stopsBeforeCondition + 1)
        XCTAssertFalse(watch.isAlerting)

        let stopsBeforeModeOff = stopCount
        watch.setMode(.off)
        XCTAssertEqual(stopCount, stopsBeforeModeOff + 1)
        XCTAssertFalse(watch.isAlerting)
    }

    func testStopForRuleReturnsFalseWhenSleepIsNotDisabled() {
        XCTAssertFalse(PowerManager.shared.stopForRule(reason: "Battery limit reached"))
    }
}
