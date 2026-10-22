import Foundation
import IOKit

// How much power the whole Mac draws right now, read from the battery's own telemetry (a few microseconds, no process,
// no entitlement). Apple Silicon reports SystemLoad in milliwatts on the charger and on battery; a Mac without it falls
// back to the discharge current times the voltage, and a Mac with neither answers nil.
enum SystemPower {
    static func watts() -> Double? {
        batteryProperties().flatMap(watts(from:))
    }

    static func watts(from properties: [String: Any]) -> Double? {
        if let telemetry = properties["PowerTelemetryData"] as? [String: Any],
           let milliwatts = (telemetry["SystemLoad"] as? NSNumber)?.doubleValue, milliwatts > 0 {
            return milliwatts / 1000
        }
        guard let amperage = (properties["InstantAmperage"] as? NSNumber)?.int64Value, amperage < 0,
              let millivolts = (properties["Voltage"] as? NSNumber)?.doubleValue, millivolts > 0 else { return nil }
        return Double(-amperage) * millivolts / 1_000_000
    }

    private static func batteryProperties() -> [String: Any]? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS else { return nil }
        return properties?.takeRetainedValue() as? [String: Any]
    }
}
