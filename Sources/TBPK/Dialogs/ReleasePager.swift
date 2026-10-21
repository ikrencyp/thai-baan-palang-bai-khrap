import Foundation

// What's new shows a few versions at a time, newest first, so a long list is read page by page instead of scrolled.
struct ReleasePager: Equatable {
    static let pageSize = 3

    let releases: [Release]
    private(set) var page = 0

    init(releases: [Release]) { self.releases = releases }

    var pageCount: Int { max(1, (releases.count + Self.pageSize - 1) / Self.pageSize) }

    var current: [Release] {
        let start = page * Self.pageSize
        return Array(releases.dropFirst(start).prefix(Self.pageSize))
    }

    var hasNewer: Bool { page > 0 }
    var hasOlder: Bool { page < pageCount - 1 }

    var caption: String { "Page \(page + 1) of \(pageCount)" }

    mutating func showNewer() { if hasNewer { page -= 1 } }
    mutating func showOlder() { if hasOlder { page += 1 } }
}
