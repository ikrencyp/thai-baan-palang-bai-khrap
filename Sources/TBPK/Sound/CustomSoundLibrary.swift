import AppKit
import Foundation

enum CustomSoundLibrary {
    static let allowedExtensions = SoundFolder.allowedExtensions
    static let maxSeconds: TimeInterval = 30

    nonisolated(unsafe) static var folder = defaultFolder

    static var defaultFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Thai Baan Palang Bai Khrap/Sounds", isDirectory: true)
    }

    static var sounds: [AlertSound] { SoundFolder.sounds(in: folder, prefix: AlertSound.customPrefix) }

    static func add(_ source: URL) throws -> AlertSound {
        let ext = source.pathExtension.lowercased()
        guard allowedExtensions.contains(ext) else { throw CustomSoundError.unsupportedType(ext) }
        guard let sound = NSSound(contentsOf: source, byReference: true), sound.duration > 0 else {
            throw CustomSoundError.unreadable
        }
        guard sound.duration <= maxSeconds else { throw CustomSoundError.tooLong(Int(sound.duration.rounded())) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let target = folder.appendingPathComponent(source.lastPathComponent)
        if source.standardizedFileURL != target.standardizedFileURL {
            try? FileManager.default.removeItem(at: target)
            try FileManager.default.copyItem(at: source, to: target)
        }
        return AlertSound(name: AlertSound.customPrefix + source.lastPathComponent)
    }

    static func remove(_ sound: AlertSound) {
        guard sound.isCustom else { return }
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(String(sound.name.dropFirst(AlertSound.customPrefix.count))))
        AlertBeepCount.forget(sound)
    }

    static func removeAll() {
        sounds.forEach(remove)
        try? FileManager.default.removeItem(at: folder)
    }
}
