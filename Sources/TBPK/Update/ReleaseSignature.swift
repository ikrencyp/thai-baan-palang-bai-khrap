import CryptoKit
import Foundation

// Checks the signature the maintainer puts on every release dmg (`ssh-keygen -Y sign`, an OpenSSH signature file).
// The private key never leaves the maintainer's Mac, so a hijacked GitHub account or release cannot pass for the
// project: a swapped dmg and a swapped checksum still fail here. The version is part of the signed namespace, so an
// old signed dmg cannot be served as a newer release.
enum ReleaseSignature {
    // The public half of the release signing key: the 32 raw bytes, base64. scripts/sign-release.sh and get.sh use the
    // same key in OpenSSH form; a unit test keeps the two in step.
    static let trustedKey = Data(base64Encoded: "Qnpg4b3IGg9CUzaHKDm1d45zPN//PxyJQNz3P0h9kS0=")!

    static func namespace(for version: AppVersion) -> String { "tbpk-release-\(version.text)" }

    static func isValid(_ armored: String, for data: Data, version: AppVersion, key: Data = trustedKey) -> Bool {
        guard let blob = decode(armored), var reader = Reader(blob), reader.take(6) == Data("SSHSIG".utf8),
              reader.number() == 1,
              let keyBlob = reader.string(), let namespace = reader.string(), reader.string() != nil,
              let hashName = reader.string(), let signatureBlob = reader.string(), reader.isAtEnd,
              String(decoding: namespace, as: UTF8.self) == Self.namespace(for: version),
              let signer = rawKey(in: keyBlob), signer == key,
              let signature = rawSignature(in: signatureBlob),
              let digest = digest(of: data, named: String(decoding: hashName, as: UTF8.self)),
              let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: key) else { return false }
        var signed = Data("SSHSIG".utf8)
        for field in [namespace, Data(), hashName, digest] { signed.append(Writer.string(field)) }
        return publicKey.isValidSignature(signature, for: signed)
    }

    private static func decode(_ armored: String) -> Data? {
        let lines = armored.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        guard lines.first == "-----BEGIN SSH SIGNATURE-----", lines.last == "-----END SSH SIGNATURE-----" else { return nil }
        return Data(base64Encoded: lines.dropFirst().dropLast().joined())
    }

    // Both the public key and the signature are an "ssh-ed25519" label followed by the raw bytes.
    private static func rawKey(in blob: Data) -> Data? { raw(in: blob, length: 32) }
    private static func rawSignature(in blob: Data) -> Data? { raw(in: blob, length: 64) }

    private static func raw(in blob: Data, length: Int) -> Data? {
        guard var reader = Reader(blob), reader.string() == Data("ssh-ed25519".utf8),
              let bytes = reader.string(), bytes.count == length, reader.isAtEnd else { return nil }
        return bytes
    }

    private static func digest(of data: Data, named name: String) -> Data? {
        switch name {
        case "sha512": return Data(SHA512.hash(data: data))
        case "sha256": return Data(SHA256.hash(data: data))
        default: return nil
        }
    }

    private struct Reader {
        private let bytes: [UInt8]
        private var offset = 0

        init?(_ data: Data) { bytes = Array(data) }

        var isAtEnd: Bool { offset == bytes.count }

        mutating func take(_ count: Int) -> Data? {
            guard count >= 0, bytes.count - offset >= count else { return nil }
            defer { offset += count }
            return Data(bytes[offset..<offset + count])
        }

        mutating func number() -> UInt32? {
            take(4)?.reduce(0) { $0 << 8 | UInt32($1) }
        }

        mutating func string() -> Data? {
            number().flatMap { take(Int($0)) }
        }
    }

    private enum Writer {
        static func string(_ data: Data) -> Data {
            var length = UInt32(data.count).bigEndian
            return Data(bytes: &length, count: 4) + data
        }
    }
}
