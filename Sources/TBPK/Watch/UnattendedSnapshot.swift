import CoreGraphics
import Foundation
import IOKit
import IOKit.ps

struct UnattendedSnapshot {
    let lidClosed: Bool
    let screenLocked: Bool
    let onBattery: Bool
    let buzzing: Bool
    var hasExternalDisplay: Bool = false
    var batteryPercent: Int?

    // A lid closed on an external display is clamshell mode, not a Mac left in a bag.
    private var isLeftClosedUnattended: Bool { lidClosed && !hasExternalDisplay }

    var triggers: Set<UnattendedKind> {
        var found: Set<UnattendedKind> = []
        if isLeftClosedUnattended { found.insert(.lidClosed) }
        if screenLocked { found.insert(.screenLocked) }
        return found
    }

    func isUnattended(under condition: PowerCondition = .batteryOnly) -> Bool {
        buzzing && condition.covers(onBattery: onBattery) && !triggers.isEmpty
    }

    var alertKind: UnattendedKind { triggers.contains(.lidClosed) ? .lidClosed : .screenLocked }

    var summary: String {
        let lid = lidClosed ? (hasExternalDisplay ? "Lid closed, external display" : "Lid closed") : "Lid open"
        let lock = screenLocked ? "screen locked" : "unlocked"
        let power = onBattery ? "on battery" : "plugged in"
        return [lid, lock, power].joined(separator: ", ")
    }

    static func read(buzzing: Bool) -> UnattendedSnapshot {
        let power = powerReading()
        return Self(
            lidClosed: isLidClosed(),
            screenLocked: isScreenLocked(),
            onBattery: power.onBattery,
            buzzing: buzzing,
            hasExternalDisplay: isExternalDisplayAttached(),
            batteryPercent: power.percent
        )
    }

    static var hasBattery: Bool { powerReading().hasBattery }

    static var isOnBattery: Bool {
        let reading = powerReading()
        return reading.hasBattery && reading.onBattery
    }

    private static func isLidClosed() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        let property = IORegistryEntryCreateCFProperty(
            service, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)
        return property?.takeRetainedValue() as? Bool ?? false
    }

    // The key is absent while the screen is unlocked, so a missing key reads as unlocked.
    private static func isScreenLocked() -> Bool {
        guard let dictionary = CGSessionCopyCurrentDictionary() as? [String: Any] else {
            return false
        }
        return dictionary["CGSSessionScreenIsLocked"] as? Bool ?? false
    }

    private static func isExternalDisplayAttached() -> Bool {
        var count: UInt32 = 0
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)
        guard CGGetActiveDisplayList(UInt32(displays.count), &displays, &count) == .success else {
            return false
        }
        for index in 0..<Int(count) where CGDisplayIsBuiltin(displays[index]) == 0 {
            return true
        }
        return false
    }

    // Power source, never IsCharging: a full battery on AC reports IsCharging false.
    private static func powerReading() -> (hasBattery: Bool, onBattery: Bool, percent: Int?) {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return (false, false, nil) }
        let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] ?? []
        var hasBattery = false
        var percent: Int?
        var onBattery = false
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue()
                as? [String: Any] else { continue }
            guard (description[kIOPSTypeKey as String] as? String) == (kIOPSInternalBatteryType as String) else {
                continue
            }
            hasBattery = true
            percent = description[kIOPSCurrentCapacityKey as String] as? Int
            let state = description[kIOPSPowerSourceStateKey as String] as? String
            onBattery = state == (kIOPSBatteryPowerValue as String)
        }
        return (hasBattery, onBattery, percent)
    }
}
