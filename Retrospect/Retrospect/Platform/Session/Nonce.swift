import CryptoKit
import Foundation
import Security

extension Session {
    /// The nonce that binds one Apple sign-in to one identity token. The raw
    /// value goes to the server with the credential; its hash goes to Apple,
    /// which puts it inside the token, and the server checks the two match.
    struct Nonce: Sendable, Equatable {
        /// 32 random bytes, base64url (43 characters): what the server gets.
        let raw: String
        /// SHA-256 of `raw`, lowercase hex: what Apple gets.
        let hashed: String

        /// The system couldn't make random bytes. Carries only the status.
        struct RandomUnavailable: Error, Equatable {
            let status: OSStatus
        }

        init(raw: String) {
            self.raw = raw
            hashed = Self.hash(raw)
        }

        /// A fresh nonce from `random` (the system's random bytes by default).
        static func make(random: (Int) throws -> [UInt8] = secureRandom) throws -> Nonce {
            try Nonce(raw: base64URL(random(32)))
        }

        /// The server's rule (`hashNonce`): `SHA-256(raw)` as lowercase hex.
        static func hash(_ raw: String) -> String {
            SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
        }

        /// `count` bytes from `SecRandomCopyBytes`.
        static func secureRandom(_ count: Int) throws -> [UInt8] {
            var bytes = [UInt8](repeating: 0, count: count)
            let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
            guard status == errSecSuccess else { throw RandomUnavailable(status: status) }
            return bytes
        }

        /// Base64 with the URL-safe alphabet and no padding (RFC 4648 §5).
        static func base64URL(_ bytes: [UInt8]) -> String {
            Data(bytes).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
    }
}
