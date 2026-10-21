import Foundation

enum ReleaseNotes {
    // The first lines of a GitHub release body that are bullets, shown in the update dialog.
    static func summary(ofReleaseBody body: String, maxLines: Int = 4) -> String? {
        let lines = body.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("- ") || $0.hasPrefix("* ") }.map { String($0.dropFirst(2)) }
        return lines.isEmpty ? nil : lines.prefix(maxLines).map { "• " + $0 }.joined(separator: "\n")
    }

    // Every `## x.y.z` section with its `- ` lines, in file order (newest first in this project's CHANGELOG.md).
    static func all(in changelog: String) -> [Release] {
        var releases: [Release] = []
        var version: String?
        var lines: [String] = []
        func close() {
            if let version, !lines.isEmpty { releases.append(Release(version: version, lines: lines)) }
            lines = []
        }
        for line in changelog.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if line.hasPrefix("## ") {
                close()
                version = line.dropFirst(3).split(separator: " ").first.map(String.init)
            } else if version != nil, line.hasPrefix("- ") {
                lines.append(String(line.dropFirst(2)))
            }
        }
        close()
        return releases
    }

    // The CHANGELOG.md that build.sh puts inside the app.
    static func bundledText(in bundle: Bundle = .main) -> String? {
        bundle.url(forResource: "CHANGELOG", withExtension: "md").flatMap { try? String(contentsOf: $0, encoding: .utf8) }
    }
}
