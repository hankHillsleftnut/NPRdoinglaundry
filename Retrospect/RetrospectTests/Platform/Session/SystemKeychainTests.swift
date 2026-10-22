import Foundation
@testable import Retrospect
import Security
import Testing

/// Against the simulator's real Keychain, in a service of its own that each
/// test empties. The Keychain needs a signed test host: an unsigned build
/// (`CODE_SIGNING_ALLOWED=NO`) gets errSecMissingEntitlement on every call, so
/// these run only when the host is signed (ad hoc is enough:
/// `CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO`). The query test above them
/// always runs.
@Suite(.serialized, .timeLimit(.minutes(1)))
struct SystemKeychainTests {
    static var isKeychainAvailable: Bool {
        let probe: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.retrospect.tests.probe"]
        return SecItemCopyMatching(probe as CFDictionary, nil) != errSecMissingEntitlement
    }

    private let keychain = Session.SystemKeychain(service: "com.retrospect.tests.\(UUID().uuidString)")

    @Test("every write requests AfterFirstUnlockThisDeviceOnly")
    func everyWriteRequestsAfterFirstUnlockThisDeviceOnly() {
        let add = Session.SystemKeychain.addQuery(service: "s", account: "a", data: Data())
        let update = Session.SystemKeychain.attributes(Data())

        #expect(add[kSecAttrAccessible as String] as? String == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
        #expect(update[kSecAttrAccessible as String] as? String == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
    }

    @Test("an item round-trips through the real Keychain with the right accessibility", .enabled(if: isKeychainAvailable, "the test host isn't signed"))
    func anItemRoundTripsWithTheRightAccessibility() throws {
        defer { try? keychain.deleteAll() }

        try keychain.write(Data("one".utf8), account: "item")
        try keychain.write(Data("two".utf8), account: "item")

        #expect(try keychain.read("item") == Data("two".utf8))
        #expect(try accessibility(of: "item") == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
    }

    @Test("an item the old app wrote WhenUnlocked moves to AfterFirstUnlock on its next write", .enabled(if: isKeychainAvailable, "the test host isn't signed"))
    func anOldItemMovesOnItsNextWrite() throws {
        defer { try? keychain.deleteAll() }
        let old: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychain.service, kSecAttrAccount as String: "old",
            kSecValueData as String: Data("x".utf8), kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]
        try #require(SecItemAdd(old as CFDictionary, nil) == errSecSuccess)

        try keychain.write(Data("y".utf8), account: "old")

        #expect(try accessibility(of: "old") == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
    }

    @Test("a missing item reads as nil and deletes cleanly", .enabled(if: isKeychainAvailable, "the test host isn't signed"))
    func aMissingItemReadsAsNil() throws {
        #expect(try keychain.read("missing") == nil)
        try keychain.delete("missing")
        try keychain.deleteAll()
    }

    @Test("deleteAll empties the service", .enabled(if: isKeychainAvailable, "the test host isn't signed"))
    func deleteAllEmptiesTheService() throws {
        try keychain.write(Data("1".utf8), account: "a")
        try keychain.write(Data("2".utf8), account: "b")

        try keychain.deleteAll()

        #expect(try keychain.read("a") == nil)
        #expect(try keychain.read("b") == nil)
    }

    @Test(
        "an unlocked phone reads as unlocked since boot, and the probe leaves nothing behind",
        .enabled(if: isKeychainAvailable, "the test host isn't signed")
    )
    func theUnlockProbeLeavesNothing() throws {
        defer { try? keychain.deleteAll() }

        #expect(keychain.isUnlockedSinceBoot())
        #expect(try keychain.read("unlock_probe") == nil)
    }

    private func accessibility(of account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychain.service, kSecAttrAccount as String: account,
            kSecReturnAttributes as String: true, kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { throw Session.KeychainError(status: status) }
        return (result as? [String: Any])?[kSecAttrAccessible as String] as? String
    }
}
