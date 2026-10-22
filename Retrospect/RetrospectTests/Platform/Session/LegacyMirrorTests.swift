import Foundation
@testable import Retrospect
import Security
import Testing

@Suite(.timeLimit(.minutes(1)))
struct LegacyMirrorTests {
    private let keychain = Session.MemoryKeychain()
    private let published = Platform.Box([String?]())

    private func mirror() -> Session.LegacyMirror {
        let published = published
        return Session.LegacyMirror(keychain: keychain, stateChanged: { published.value.append($0) })
    }

    private func settle() async {
        await Task.yield()
        await MainActor.run {}
    }

    @Test("the mirror writes jwt_token, user_id and apple_user_id, and never the refresh token")
    func theMirrorWritesTheOldItems() async throws {
        try mirror().write(accessToken: "invented.access.token", userID: "u1", appleUserID: "001234.invented")
        await settle()

        #expect(keychain.contents.compactMapValues { String(bytes: $0, encoding: .utf8) } == [
            "jwt_token": "invented.access.token", "user_id": "u1", "apple_user_id": "001234.invented",
        ])
        #expect(!keychain.contents.values.contains { String(bytes: $0, encoding: .utf8)?.contains("refresh") == true })
        #expect(published.value == ["u1"])
    }

    @Test("every mirror write requests AfterFirstUnlockThisDeviceOnly, through the system Keychain's one write path")
    func theMirrorUsesTheSystemKeychainsWrite() {
        let add = Session.SystemKeychain.addQuery(service: Session.Store.legacyService, account: "jwt_token", data: Data())
        #expect(add[kSecAttrAccessible as String] as? String == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
        #expect(add[kSecAttrService as String] as? String == "com.retrospect.api")
    }

    @Test("a session without an Apple id removes the old apple_user_id")
    func noAppleIDRemovesTheOldOne() async throws {
        try keychain.write(Data("stale".utf8), account: "apple_user_id")

        try mirror().write(accessToken: "t", userID: "u", appleUserID: nil)
        await settle()

        #expect(keychain.contents["apple_user_id"] == nil)
        #expect(keychain.contents["jwt_token"] == Data("t".utf8))
    }

    @Test("clear removes the three items and publishes signed out")
    func clearRemovesTheItems() async throws {
        try mirror().write(accessToken: "t", userID: "u", appleUserID: "a")

        try mirror().clear()
        await settle()

        #expect(keychain.contents.isEmpty)
        #expect(published.value.last == .some(nil))
    }

    @Test("a Keychain failure surfaces its status and publishes nothing")
    func aFailureSurfacesItsStatus() async {
        keychain.failEveryCall(with: errSecIO)

        #expect(throws: Session.KeychainError(status: errSecIO)) { try mirror().write(accessToken: "t", userID: "u", appleUserID: nil) }
        await settle()

        #expect(published.value.isEmpty)
    }
}
