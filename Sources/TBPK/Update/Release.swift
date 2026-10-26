import Foundation

struct Release: Equatable {
    let version: String
    let lines: [String]
    // Where in the menu the new thing lives, from a `- Find it: ...` line of the CHANGELOG.
    var findIt: String? = nil
}
