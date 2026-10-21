import Foundation

struct AppVersion: Comparable, Equatable {
    let parts: [Int]

    init?(_ text: String) {
        let numbers = text.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !numbers.isEmpty, !numbers.contains(nil) else { return nil }
        let parsed = numbers.compactMap { $0 }
        guard parsed.allSatisfy({ $0 >= 0 }) else { return nil }
        parts = parsed
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let width = max(lhs.parts.count, rhs.parts.count)
        let pad = { (parts: [Int]) in parts + Array(repeating: 0, count: width - parts.count) }
        return pad(lhs.parts).lexicographicallyPrecedes(pad(rhs.parts))
    }

    var text: String { parts.map(String.init).joined(separator: ".") }
}
