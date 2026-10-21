import CoreAudio
import Foundation

enum AlertVolumeLift {
    static let storageKey = "alertVolumeLevel"

    static let defaultLevel: Float32 = 1

    static var storedLevel: Float32 {
        get {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: storageKey) != nil else { return defaultLevel }
            return clamped(Float32(defaults.double(forKey: storageKey)))
        }
        set {
            UserDefaults.standard.set(Double(clamped(newValue)), forKey: storageKey)
        }
    }

    private enum UndoKey {
        static let device = "alertVolumeDevice"
        static let mute = "alertMuteWasOn"
        static let original = "alertVolumeOriginal"
        static let written = "alertVolumeWritten"
        static let sourceDevice = "alertSourceDevice"
        static let sourceOriginal = "alertSourceOriginal"
        static let all = [device, mute, original, written, sourceDevice, sourceOriginal]
    }

    static func level(for current: Float32?) -> Float32? {
        level(for: current, target: storedLevel)
    }

    static func level(for current: Float32?, target: Float32) -> Float32? {
        guard let current, current < target else { return nil }
        return target
    }

    private static func clamped(_ value: Float32) -> Float32 {
        min(max(value, 0), 1)
    }

    // Brings the Mac's own speaker up to the alert level and returns whether it is safe to play there at that level.
    // With wired headphones in the jack the speaker is switched on for the alert and switched back by restorePending;
    // if the Mac will not switch, nothing is raised, so the alert never gets louder than the person set it.
    @discardableResult
    static func lift(_ speaker: AlertRoute.Speaker) -> Bool {
        switch AlertRoute.plan(for: speaker) {
        case .alreadySpeaker:
            break
        case .switchToSpeaker(let original):
            guard AudioOutput.writeDataSource(speaker.device, AlertRoute.speakerSource) else { return false }
            let defaults = UserDefaults.standard
            defaults.set(Int(speaker.device), forKey: UndoKey.sourceDevice)
            defaults.set(Int(original), forKey: UndoKey.sourceOriginal)
        case .headphonesLocked:
            return false
        }
        raise(speaker.device)
        return true
    }

    // Runs at launch too: a process killed mid-alert would leave the Mac unmuted.
    static func restorePending() {
        let defaults = UserDefaults.standard
        restoreDataSource(in: defaults)
        guard defaults.object(forKey: UndoKey.device) != nil else { return }
        let device = AudioDeviceID(UInt32(defaults.integer(forKey: UndoKey.device)))
        if defaults.bool(forKey: UndoKey.mute), AudioOutput.readMute(device) == false {
            AudioOutput.writeMute(device, true)
        }
        let originals = levels(forKey: UndoKey.original, in: defaults)
        let written = levels(forKey: UndoKey.written, in: defaults)
        for (element, original) in originals {
            guard let current = AudioOutput.readVolume(device, element),
                  let echo = written[element],
                  abs(current - echo) < 0.001 else { continue }
            AudioOutput.writeVolume(device, element, original)
        }
        for key in UndoKey.all {
            defaults.removeObject(forKey: key)
        }
    }

    private static func restoreDataSource(in defaults: UserDefaults) {
        guard defaults.object(forKey: UndoKey.sourceDevice) != nil else { return }
        let device = AudioDeviceID(UInt32(defaults.integer(forKey: UndoKey.sourceDevice)))
        let original = UInt32(defaults.integer(forKey: UndoKey.sourceOriginal))
        if AudioOutput.dataSource(of: device) == AlertRoute.speakerSource { AudioOutput.writeDataSource(device, original) }
        defaults.removeObject(forKey: UndoKey.sourceDevice)
        defaults.removeObject(forKey: UndoKey.sourceOriginal)
    }

    private static func raise(_ device: AudioDeviceID) {
        let defaults = UserDefaults.standard
        var originals: [AudioObjectPropertyElement: Float32] = [:]
        var written: [AudioObjectPropertyElement: Float32] = [:]
        for element in AudioOutput.volumeElements(of: device) {
            guard let current = AudioOutput.readVolume(device, element),
                  let target = level(for: current),
                  AudioOutput.isSettable(device, kAudioDevicePropertyVolumeScalar, element) else { continue }
            AudioOutput.writeVolume(device, element, target)
            guard let echo = AudioOutput.readVolume(device, element) else { continue }
            originals[element] = current
            written[element] = echo
        }
        var unmuted = false
        if AudioOutput.readMute(device) == true,
           AudioOutput.isSettable(device, kAudioDevicePropertyMute, kAudioObjectPropertyElementMain) {
            AudioOutput.writeMute(device, false)
            unmuted = true
        }
        guard !originals.isEmpty || unmuted else { return }
        defaults.set(Int(device), forKey: UndoKey.device)
        defaults.set(unmuted, forKey: UndoKey.mute)
        save(originals, forKey: UndoKey.original, in: defaults)
        save(written, forKey: UndoKey.written, in: defaults)
    }

    private static func save(
        _ values: [AudioObjectPropertyElement: Float32],
        forKey key: String,
        in defaults: UserDefaults
    ) {
        guard !values.isEmpty else { return }
        let pairs = values.reduce(into: [String: Double]()) { acc, entry in
            acc["\(entry.key)"] = Double(entry.value)
        }
        defaults.set(pairs, forKey: key)
    }

    private static func levels(
        forKey key: String,
        in defaults: UserDefaults
    ) -> [AudioObjectPropertyElement: Float32] {
        let pairs = defaults.dictionary(forKey: key) as? [String: Double] ?? [:]
        return pairs.reduce(into: [:]) { acc, entry in
            guard let raw = UInt32(entry.key) else { return }
            acc[AudioObjectPropertyElement(raw)] = Float32(entry.value)
        }
    }
}
