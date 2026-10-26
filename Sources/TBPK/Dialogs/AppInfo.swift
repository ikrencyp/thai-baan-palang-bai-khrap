import AppKit
import SwiftUI

enum AppInfo {
    static let name = "Thai Baan Palang Bai Khrap"
    static let shortName = "TBPK"
    static let fallbackVersion = "1.2.0"

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? fallbackVersion
    }

    static var versionLine: String { "\(shortName) \(version)" }
}
