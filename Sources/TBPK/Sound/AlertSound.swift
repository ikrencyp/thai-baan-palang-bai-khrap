import AppKit
import Foundation

struct AlertSound: Hashable {
    static let storageKey = "alertSoundName"

    static let systemAlertName = "System alert"
    static let customPrefix = "custom:"

    let name: String

    var isCustom: Bool { name.hasPrefix(Self.customPrefix) }

    // The sound's file name inside its folder; nil for a sound macOS owns.
    private var fileName: String? {
        if isCustom { return String(name.dropFirst(Self.customPrefix.count)) }
        return nil
    }

    var displayName: String {
        fileName.map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent } ?? name
    }

    private var fileURL: URL? {
        guard let fileName else { return nil }
        return CustomSoundLibrary.folder.appendingPathComponent(fileName)
    }

    static let systemAlert = AlertSound(name: systemAlertName)

    var isSystemAlert: Bool { name == Self.systemAlertName }

    static var available: [AlertSound] {
        [systemAlert] + CustomSoundLibrary.sounds + installedNames().sorted().map(AlertSound.init)
    }

    static var stored: AlertSound {
        guard let raw = UserDefaults.standard.string(forKey: storageKey) else { return .systemAlert }
        return available.first(where: { $0.name == raw }) ?? .systemAlert
    }

    func store() {
        UserDefaults.standard.set(name, forKey: Self.storageKey)
    }

    var duration: TimeInterval {
        guard let sound = makeSound(), sound.duration > 0, sound.duration.isFinite else { return 1 }
        return sound.duration
    }

    // The system alert plays its configured file at output volume, so the Alert volume setting cannot silence it.
    // `deviceUID` sends the sound to that output; nil follows the system's chosen output.
    @discardableResult
    func play(volume: Float = 1, on deviceUID: String? = nil) -> NSSound? {
        guard let sound = makeSound() else {
            NSSound.beep()
            return nil
        }
        sound.volume = volume
        sound.playbackDeviceIdentifier = deviceUID
        sound.play()
        return sound
    }

    private func makeSound() -> NSSound? {
        if let fileURL { return NSSound(contentsOf: fileURL, byReference: true) }
        guard isSystemAlert else { return NSSound(named: name) }
        guard let path = UserDefaults.standard.string(forKey: "com.apple.sound.beep.sound") else { return nil }
        return NSSound(contentsOf: URL(fileURLWithPath: path), byReference: true)
    }

    private static func installedNames() -> [String] {
        let folders = [
            URL(fileURLWithPath: "/System/Library/Sounds"),
            URL(fileURLWithPath: "/Library/Sounds"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Sounds"),
        ]
        let extensions: Set<String> = ["aiff", "wav", "mp3", "m4a", "caf"]
        var names: [String] = []
        for folder in folders {
            guard let items = try? FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }
            for item in items where extensions.contains(item.pathExtension.lowercased()) {
                let name = item.deletingPathExtension().lastPathComponent
                if !names.contains(name) { names.append(name) }
            }
        }
        return names
    }
}
