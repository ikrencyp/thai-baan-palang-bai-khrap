import CryptoKit
import XCTest
@testable import TBPK

final class UpdateSourceTests: XCTestCase {
    private var workspace: URL!

    override func setUpWithError() throws {
        workspace = FileManager.default.temporaryDirectory.appendingPathComponent("tbpk-src-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let workspace { try? FileManager.default.removeItem(at: workspace) }
    }

    private func release(tag: String = "v1.2.0", draft: Bool = false, prerelease: Bool = false, body: String = "- new thing",
                         assets: [String]? = nil) -> Data {
        let names = assets ?? ["TBPK-1.2.0.dmg", "TBPK-1.2.0.dmg.sha256"]
        let list = names.map { "{\"name\":\"\($0)\",\"browser_download_url\":\"https://github.com/ikrencyp/thai-baan-palang-bai-khrap/releases/download/\(tag)/\($0)\"}" }
        return Data("""
        {"tag_name":"\(tag)","body":"\(body)","draft":\(draft),"prerelease":\(prerelease),"assets":[\(list.joined(separator: ","))]}
        """.utf8)
    }

    func testAPublicReleaseWithTheDmgAndItsChecksumIsFound() throws {
        guard case .found(let latest) = UpdateSource.parse(release()) else { return XCTFail("not found") }
        XCTAssertEqual(latest.version.text, "1.2.0")
        XCTAssertEqual(latest.tag, "v1.2.0")
        XCTAssertEqual(latest.notes, "• new thing")
        XCTAssertEqual(latest.dmg.lastPathComponent, "TBPK-1.2.0.dmg")
        XCTAssertEqual(latest.checksum.lastPathComponent, "TBPK-1.2.0.dmg.sha256")
    }

    func testDraftsPreReleasesOddTagsAndMissingAssetsAreNotOffered() {
        XCTAssertEqual(UpdateSource.parse(release(draft: true)), .noRelease)
        XCTAssertEqual(UpdateSource.parse(release(prerelease: true)), .noRelease)
        XCTAssertEqual(UpdateSource.parse(release(tag: "tbpk-v1.2.0")), .noRelease)
        XCTAssertEqual(UpdateSource.parse(release(tag: "vnext")), .noRelease)
        XCTAssertEqual(UpdateSource.parse(release(assets: ["TBPK-1.2.0.dmg"])), .noRelease, "no checksum, no update")
        XCTAssertEqual(UpdateSource.parse(release(assets: ["TBPK-9.9.9.dmg", "TBPK-9.9.9.dmg.sha256"])), .noRelease)
        XCTAssertEqual(UpdateSource.parse(Data("not json".utf8)), .unreachable)
    }

    func testOnlyThisRepositorysReleaseAssetsOnGitHubOverHttpsAreTrusted() throws {
        let good = "https://github.com/ikrencyp/thai-baan-palang-bai-khrap/releases/download/v1.0.0/TBPK-1.0.0.dmg"
        XCTAssertTrue(UpdateSource.isTrusted(try XCTUnwrap(URL(string: good))))
        let refused = [
            "http://github.com/ikrencyp/thai-baan-palang-bai-khrap/releases/download/v1/x.dmg",
            "https://github.com/someone-else/other/releases/download/v1/x.dmg",
            "https://github.com/ikrencyp/thai-baan-palang-bai-khrap/archive/main.zip",
            "https://raw.githubusercontent.com/ikrencyp/thai-baan-palang-bai-khrap/main/x.dmg",
            "https://objects.githubusercontent.com/x",
            "https://api.github.com/ikrencyp/thai-baan-palang-bai-khrap/releases/download/v1/x.dmg",
            "https://github.com.evil.example/ikrencyp/thai-baan-palang-bai-khrap/releases/download/v1/x.dmg",
            "https://github.com@evil.example/ikrencyp/thai-baan-palang-bai-khrap/releases/download/v1/x.dmg",
            "https://user:pass@github.com/ikrencyp/thai-baan-palang-bai-khrap/releases/download/v1/x.dmg",
            "https://github.com:8443/ikrencyp/thai-baan-palang-bai-khrap/releases/download/v1/x.dmg",
        ]
        for text in refused { XCTAssertFalse(UpdateSource.isTrusted(try XCTUnwrap(URL(string: text))), text) }
        XCTAssertFalse(UpdateSource.isTrusted(URL(fileURLWithPath: "/tmp/x.dmg")))
    }

    func testAChecksumFileMustMatchTheBytesExactly() {
        let data = Data("hello".utf8)
        let digest = "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        XCTAssertTrue(UpdateSource.matches(data, checksumFile: "\(digest)  TBPK-1.0.0.dmg\n"))
        XCTAssertTrue(UpdateSource.matches(data, checksumFile: digest.uppercased()))
        XCTAssertFalse(UpdateSource.matches(Data("hellO".utf8), checksumFile: digest))
        XCTAssertFalse(UpdateSource.matches(data, checksumFile: "abc"))
        XCTAssertFalse(UpdateSource.matches(data, checksumFile: ""))
    }

    func testAnUnreachableApiIsReportedAsSuch() async {
        let missing = workspace.appendingPathComponent("nope.json")
        let lookup = await UpdateSource.lookUp(api: missing)
        XCTAssertEqual(lookup, .unreachable)
    }

    private func makeDmg(version: String) throws -> URL {
        let content = workspace.appendingPathComponent("content-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: content, withIntermediateDirectories: true)
        for name in ["install.sh", "uninstall.sh"] { try "#!/bin/bash\n".write(to: content.appendingPathComponent(name), atomically: true, encoding: .utf8) }
        let dmg = workspace.appendingPathComponent("TBPK-\(version).dmg")
        let made = Process()
        made.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        made.arguments = ["create", "-volname", "TBPK", "-srcfolder", content.path, "-ov", "-format", "UDZO", dmg.path]
        made.standardOutput = FileHandle.nullDevice
        try made.run(); made.waitUntilExit()
        try XCTSkipIf(made.terminationStatus != 0, "hdiutil is not available here")
        return dmg
    }

    private func checksum(of file: URL, name: String) throws -> URL {
        let hex = SHA256.hash(data: try Data(contentsOf: file)).map { String(format: "%02x", $0) }.joined()
        let sum = workspace.appendingPathComponent("\(name).sha256")
        try "\(hex)  \(name)\n".write(to: sum, atomically: true, encoding: .utf8)
        return sum
    }

    private func latest(dmg: URL, checksum: URL) -> UpdateSource.Latest {
        UpdateSource.Latest(version: AppVersion("1.2.0")!, tag: "v1.2.0", notes: nil, dmg: dmg, checksum: checksum)
    }

    func testAVerifiedDownloadHoldsTheDmgAndTheScriptsLiftedOutOfIt() async throws {
        let dmg = try makeDmg(version: "1.2.0")
        let found = await UpdateSource.fetch(latest(dmg: dmg, checksum: try checksum(of: dmg, name: "TBPK-1.2.0.dmg")), in: workspace)
        let checkout = try XCTUnwrap(found)
        defer { checkout.remove() }
        XCTAssertNotNil(checkout.installer(for: AppVersion("1.2.0")!))
        XCTAssertNil(checkout.installer(for: AppVersion("9.9.9")!))
        XCTAssertTrue(FileManager.default.fileExists(atPath: checkout.root.appendingPathComponent("uninstall.sh").path))
    }

    func testADmgThatDoesNotMatchItsChecksumIsRefusedAndNothingIsLeftBehind() async throws {
        let dmg = try makeDmg(version: "1.2.0")
        let wrong = workspace.appendingPathComponent("wrong.sha256")
        try String(repeating: "0", count: 64).write(to: wrong, atomically: true, encoding: .utf8)
        let base = workspace.appendingPathComponent("downloads")
        let found = await UpdateSource.fetch(latest(dmg: dmg, checksum: wrong), in: base)
        XCTAssertNil(found)
        XCTAssertEqual((try? FileManager.default.contentsOfDirectory(atPath: base.path))?.count ?? 0, 0)
    }

    func testAMissingDmgIsAFailedDownload() async throws {
        let sum = workspace.appendingPathComponent("x.sha256")
        try String(repeating: "0", count: 64).write(to: sum, atomically: true, encoding: .utf8)
        let found = await UpdateSource.fetch(latest(dmg: workspace.appendingPathComponent("gone.dmg"), checksum: sum), in: workspace)
        XCTAssertNil(found)
    }
}
