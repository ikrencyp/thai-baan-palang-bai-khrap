import XCTest

extension XCTestCase {
    // A throw-away UserDefaults suite kept in its own temporary folder (a suite name that is a path stores its plist
    // there), so nothing lands in ~/Library/Preferences: a plist deleted from there is written again a moment later.
    func scratchDefaults(_ prefix: String) -> UserDefaults {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("\(prefix)-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = folder.appendingPathComponent("defaults").path
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock {
            defaults.removePersistentDomain(forName: name)
            try? FileManager.default.removeItem(at: folder)
        }
        return defaults
    }
}
