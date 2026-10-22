import Foundation
import XCTest

// A throwaway signing key made with the real `ssh-keygen`, so the tests prove the app reads what the maintainer's tool writes.
struct SigningFixture {
    let keyFile: URL
    let publicKey: Data

    init(in folder: URL) throws {
        keyFile = folder.appendingPathComponent("signing-\(UUID().uuidString)")
        try Self.run(["-q", "-t", "ed25519", "-N", "", "-f", keyFile.path])
        let text = try String(contentsOf: keyFile.appendingPathExtension("pub"), encoding: .utf8)
        let blob = try XCTUnwrap(Data(base64Encoded: String(text.split(separator: " ")[1])))
        publicKey = Data(blob.suffix(32))
    }

    // Writes <file>.sig next to the file, the way scripts/sign-release.sh does.
    func sign(_ file: URL, namespace: String) throws {
        try Self.run(["-Y", "sign", "-f", keyFile.path, "-n", namespace, file.path])
    }

    static func run(_ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keygen")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        try XCTSkipIf(process.terminationStatus != 0, "ssh-keygen is not available here")
    }
}
