import Foundation

enum SoundFolder {
    static let allowedExtensions: Set<String> = ["aiff", "aif", "wav", "mp3", "m4a", "caf", "aac"]

    static func sounds(in folder: URL, prefix: String) -> [AlertSound] {
        let items = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        return items
            .filter { allowedExtensions.contains($0.pathExtension.lowercased()) }
            .map { AlertSound(name: prefix + $0.lastPathComponent) }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }
}
