import Foundation

struct Release: Equatable {
    let version: String
    let lines: [String]
    // Where in the menu the new things live, one path per `- Find it: ...` line of the CHANGELOG.
    var findIt: [String] = []
}
