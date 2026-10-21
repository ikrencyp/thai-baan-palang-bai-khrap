import Foundation

// What the app leaves behind when it is stopped half way: an update clone in the temporary folder,
// a download that never finished, a log that only grows. Swept at launch and every half hour. Every rule matches a
// name this app makes, and nothing younger than `staleAfter` is touched, so nothing in use is ever removed.
enum AppLeftovers {
    static let staleAfter: TimeInterval = 600
    static let logLimit = 200_000
    static let logKeep = 50_000

    private static let cloneName = "^tbpk-update-[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}$"

    static func sweepInBackground() {
        DispatchQueue.global(qos: .utility).async { sweep() }
    }

    // Returns how many folders and files were removed.
    @discardableResult
    static func sweep(
        temporary: URL = FileManager.default.temporaryDirectory,
        downloads: URL = UpdateInstaller.downloadFolder,
        keeping kept: URL? = UserDefaults.standard.string(forKey: UpdateStore.downloadedPathKey).map { URL(fileURLWithPath: $0) },
        log: URL = UpdateInstaller.logFile,
        now: Date = Date()
    ) -> Int {
        let stale = { (entry: Entry) in now.timeIntervalSince(entry.modified) >= staleAfter }
        let clones = entries(in: temporary).filter { matches($0.name, cloneName) && stale($0) }
        let unfinished = entries(in: downloads).filter { $0.url.standardizedFileURL.path != kept?.standardizedFileURL.path && stale($0) }
        let doomed = clones + unfinished
        doomed.forEach { try? FileManager.default.removeItem(at: $0.url) }
        trim(log)
        return doomed.count
    }

    private struct Entry {
        let url: URL
        let modified: Date
        var name: String { url.lastPathComponent }
    }

    private static func entries(in folder: URL) -> [Entry] {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys)) ?? []
        return urls.compactMap { url in
            (try? url.resourceValues(forKeys: Set(keys)).contentModificationDate).map { Entry(url: url, modified: $0) }
        }
    }

    private static func matches(_ name: String, _ pattern: String) -> Bool {
        name.range(of: pattern, options: .regularExpression) != nil
    }

    // Keeps the newest lines: the part of the log someone would read after a failed update.
    private static func trim(_ log: URL) {
        guard let data = try? Data(contentsOf: log), data.count > logLimit else { return }
        let tail = data.suffix(logKeep)
        let fromLine = tail.firstIndex(of: UInt8(ascii: "\n")).map { tail.index(after: $0) } ?? tail.startIndex
        try? Data(tail[fromLine...]).write(to: log, options: .atomic)
    }
}
