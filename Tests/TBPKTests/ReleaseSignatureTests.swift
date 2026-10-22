import XCTest
@testable import TBPK

final class ReleaseSignatureTests: XCTestCase {
    private var workspace: URL!
    private let version = AppVersion("1.2.0")!

    override func setUpWithError() throws {
        workspace = FileManager.default.temporaryDirectory.appendingPathComponent("tbpk-sig-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let workspace { try? FileManager.default.removeItem(at: workspace) }
    }

    private func signed(_ text: String, namespace: String, with fixture: SigningFixture) throws -> (data: Data, armored: String) {
        let file = workspace.appendingPathComponent("payload-\(UUID().uuidString).bin")
        try Data(text.utf8).write(to: file)
        try fixture.sign(file, namespace: namespace)
        return (Data(text.utf8), try String(contentsOf: file.appendingPathExtension("sig"), encoding: .utf8))
    }

    func testASignatureFromTheKeyHoldersToolIsAccepted() throws {
        let fixture = try SigningFixture(in: workspace)
        let made = try signed("the dmg", namespace: "tbpk-release-1.2.0", with: fixture)
        XCTAssertTrue(ReleaseSignature.isValid(made.armored, for: made.data, version: version, key: fixture.publicKey))
    }

    func testAnotherKeyAChangedFileAndAnotherVersionAreAllRefused() throws {
        let fixture = try SigningFixture(in: workspace)
        let stranger = try SigningFixture(in: workspace)
        let made = try signed("the dmg", namespace: "tbpk-release-1.2.0", with: fixture)
        XCTAssertFalse(ReleaseSignature.isValid(made.armored, for: made.data, version: version, key: stranger.publicKey), "signed by someone else")
        XCTAssertFalse(ReleaseSignature.isValid(made.armored, for: Data("the dmG".utf8), version: version, key: fixture.publicKey), "file changed")
        XCTAssertFalse(ReleaseSignature.isValid(made.armored, for: made.data, version: AppVersion("1.3.0")!, key: fixture.publicKey), "an old signed dmg passed off as a newer one")
        let other = try signed("the dmg", namespace: "tbpk-release-1.1.0", with: fixture)
        XCTAssertFalse(ReleaseSignature.isValid(other.armored, for: other.data, version: version, key: fixture.publicKey))
    }

    func testGarbageAndDamagedSignaturesAreRefused() throws {
        let fixture = try SigningFixture(in: workspace)
        let made = try signed("the dmg", namespace: "tbpk-release-1.2.0", with: fixture)
        for text in ["", "not a signature", "-----BEGIN SSH SIGNATURE-----\n-----END SSH SIGNATURE-----\n",
                     "-----BEGIN SSH SIGNATURE-----\nAAAA\n-----END SSH SIGNATURE-----\n"] {
            XCTAssertFalse(ReleaseSignature.isValid(text, for: made.data, version: version, key: fixture.publicKey), text)
        }
        let lines = made.armored.split(separator: "\n").map(String.init)
        let truncated = (lines.prefix(2) + [lines.last!]).joined(separator: "\n")
        XCTAssertFalse(ReleaseSignature.isValid(truncated, for: made.data, version: version, key: fixture.publicKey))
    }

    func testTheKeyInTheAppIsTheKeyInGetSh() throws {
        let script = try String(contentsOfFile: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("get.sh").path, encoding: .utf8)
        let line = try XCTUnwrap(script.split(separator: "\n").first { $0.hasPrefix("SIGNING_KEY=") })
        let field = try XCTUnwrap(line.split(separator: " ").last).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        let blob = try XCTUnwrap(Data(base64Encoded: field))
        XCTAssertEqual(Data(blob.suffix(32)), ReleaseSignature.trustedKey)
        XCTAssertEqual(ReleaseSignature.trustedKey.count, 32)
    }
}
