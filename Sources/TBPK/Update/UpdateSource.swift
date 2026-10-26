import CryptoKit
import Foundation

// The newest GitHub Release of the project: one small request to the releases API. Installing downloads the
// dmg of that release, checks it against the SHA-256 file published beside it (a damaged download) and against the
// maintainer's signature file (a release nobody but the maintainer made).
enum UpdateSource {
    static let repository = "ikrencyp/thai-baan-palang-bai-khrap"

    // TBPK_UPDATE_API points a test copy at a local JSON file (file://...) instead of GitHub.
    static var apiURL: URL {
        ProcessInfo.processInfo.environment["TBPK_UPDATE_API"].flatMap(URL.init(string:))
            ?? URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
    }

    struct Latest: Equatable {
        let version: AppVersion
        let tag: String
        let notes: String?
        let dmg: URL
        let checksum: URL

        // Published beside the dmg as TBPK-<x.y.z>.dmg.sig; parse only offers a release that has it.
        var signature: URL { dmg.appendingPathExtension("sig") }
    }

    enum Lookup: Equatable {
        case unreachable
        case noRelease
        case found(Latest)
    }

    private struct Payload: Decodable {
        struct Asset: Decodable {
            let name: String
            let browser_download_url: String
        }
        let tag_name: String
        let body: String?
        let draft: Bool?
        let prerelease: Bool?
        let assets: [Asset]
    }

    static func lookUp(api: URL = apiURL) async -> Lookup {
        var request = URLRequest(url: api, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request) else { return .unreachable }
        if let http = response as? HTTPURLResponse, http.statusCode == 404 { return .noRelease }
        if let http = response as? HTTPURLResponse, http.statusCode != 200 { return .unreachable }
        return parse(data)
    }

    // A release counts only when it is public, its tag is `v<x.y.z>` and it carries the dmg and its checksum.
    static func parse(_ data: Data) -> Lookup {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return .unreachable }
        guard payload.draft != true, payload.prerelease != true,
              payload.tag_name.hasPrefix("v"), let version = AppVersion(String(payload.tag_name.dropFirst())) else { return .noRelease }
        let urls = Dictionary(payload.assets.compactMap { asset in URL(string: asset.browser_download_url).map { (asset.name, $0) } },
                              uniquingKeysWith: { first, _ in first })
        guard let dmg = urls["TBPK-\(version.text).dmg"], let checksum = urls["TBPK-\(version.text).dmg.sha256"],
              let signature = urls["TBPK-\(version.text).dmg.sig"],
              isTrusted(dmg), isTrusted(checksum), isTrusted(signature) else { return .noRelease }
        return .found(Latest(version: version, tag: payload.tag_name, notes: payload.body.flatMap { ReleaseNotes.summary(ofReleaseBody: $0) },
                             dmg: dmg, checksum: checksum))
    }

    // Downloads come from this repository's release assets on github.com, over HTTPS, and nowhere else. A test copy that
    // overrides the API may use local files.
    static func isTrusted(_ url: URL) -> Bool {
        if ProcessInfo.processInfo.environment["TBPK_UPDATE_API"] != nil, url.isFileURL { return true }
        guard url.scheme == "https", url.host?.lowercased() == "github.com", url.port == nil,
              url.user == nil, url.password == nil else { return false }
        return url.path.hasPrefix("/\(repository)/releases/download/")
    }

    // Downloads the dmg, its checksum and its signature, refuses a dmg that does not match either, and lifts `install.sh` out of the dmg
    // so the finished folder looks like the one install.sh expects.
    // `progress` goes from 0 to 1 and never back: the dmg is nearly all of the work, so its share is what is reported.
    static func fetch(_ latest: Latest, in base: URL = FileManager.default.temporaryDirectory,
                      key: Data = ReleaseSignature.trustedKey, progress: (@Sendable (Double) -> Void)? = nil) async -> ReleaseCheckout? {
        let root = base.appendingPathComponent("tbpk-update-\(UUID().uuidString)")
        let dist = root.appendingPathComponent("dist")
        let dmgFile = dist.appendingPathComponent("TBPK-\(latest.version.text).dmg")
        do {
            try FileManager.default.createDirectory(at: dist, withIntermediateDirectories: true)
            try await download(latest.dmg, to: dmgFile, progress: progress)
            let (sum, sumResponse) = try await URLSession.shared.data(from: latest.checksum)
            if let http = sumResponse as? HTTPURLResponse, http.statusCode != 200 { throw URLError(.badServerResponse) }
            let bytes = try Data(contentsOf: dmgFile)
            guard matches(bytes, checksumFile: String(decoding: sum, as: UTF8.self)) else { throw CocoaError(.fileReadCorruptFile) }
            let (signature, signatureResponse) = try await URLSession.shared.data(from: latest.signature)
            if let http = signatureResponse as? HTTPURLResponse, http.statusCode != 200 { throw URLError(.badServerResponse) }
            guard ReleaseSignature.isValid(String(decoding: signature, as: UTF8.self), for: bytes, version: latest.version, key: key) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            try liftScripts(from: dmgFile, to: root)
            progress?(1)
            return ReleaseCheckout(root: root)
        } catch {
            try? FileManager.default.removeItem(at: root)
            return nil
        }
    }

    private static func download(_ url: URL, to file: URL, progress: (@Sendable (Double) -> Void)?) async throws {
        let (temp, response) = try await URLSession.shared.download(from: url, delegate: progress.map(DownloadShare.init))
        if let http = response as? HTTPURLResponse, http.statusCode != 200 { throw URLError(.badServerResponse) }
        try? FileManager.default.removeItem(at: file)
        try FileManager.default.moveItem(at: temp, to: file)
    }

    // The checksum file is the output of `shasum -a 256`: the hex digest first, then the file name.
    static func matches(_ data: Data, checksumFile: String) -> Bool {
        guard let expected = checksumFile.split(whereSeparator: \.isWhitespace).first?.lowercased(), expected.count == 64 else { return false }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() == expected
    }

    private static func liftScripts(from dmg: URL, to root: URL) throws {
        let mount = FileManager.default.temporaryDirectory.appendingPathComponent("tbpk-mount-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: mount) }
        guard run("/usr/bin/hdiutil", ["attach", "-nobrowse", "-readonly", "-mountpoint", mount.path, dmg.path]) == 0 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        defer { _ = run("/usr/bin/hdiutil", ["detach", "-force", mount.path]) }
        for name in ["install.sh", "uninstall.sh"] {
            try FileManager.default.copyItem(at: mount.appendingPathComponent(name), to: root.appendingPathComponent(name))
        }
    }

    private static func run(_ tool: String, _ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return 127 }
        process.waitUntilExit()
        return process.terminationStatus
    }
}

// Reports how much of a download is in. It keeps the highest value, so a late report never moves the bar back,
// and stops at 0.95: the rest is the checksum and signature checks, which end with the 1 from `fetch`.
private final class DownloadShare: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let report: @Sendable (Double) -> Void
    private let lock = NSLock()
    private var highest = 0.0

    init(_ report: @escaping @Sendable (Double) -> Void) {
        self.report = report
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let share = min(0.95, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) * 0.95)
        lock.lock()
        let isNew = share > highest + 0.004
        if isNew { highest = share }
        lock.unlock()
        if isNew { report(share) }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
}
