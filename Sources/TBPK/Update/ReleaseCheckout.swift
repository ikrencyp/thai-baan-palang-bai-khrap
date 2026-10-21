import Foundation

// A finished download: `install.sh` next to `dist/TBPK-<version>.dmg`, the layout install.sh already understands.
struct ReleaseCheckout {
    let root: URL

    func remove() { try? FileManager.default.removeItem(at: root) }

    static func existing(at root: URL) -> ReleaseCheckout { ReleaseCheckout(root: root) }

    func installer(for version: AppVersion) -> URL? {
        let script = root.appendingPathComponent("install.sh")
        let dmg = root.appendingPathComponent("dist/TBPK-\(version.text).dmg")
        let fm = FileManager.default
        return fm.fileExists(atPath: script.path) && fm.fileExists(atPath: dmg.path) ? script : nil
    }
}
