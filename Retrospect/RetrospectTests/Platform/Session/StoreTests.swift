import Foundation
@testable import Retrospect
import Security
import Testing

@Suite(.timeLimit(.minutes(1)))
struct StoreTests {
    private let keychain = Session.MemoryKeychain()
    private let legacy = Session.MemoryKeychain()
    private let defaults: UserDefaults
    private let suite = "platform.tests.\(UUID().uuidString)"

    private let credentials = Session.Credentials(
        accessToken: "access-invented",
        accessTokenExpiresAt: Date(timeIntervalSince1970: 1_792_570_500),
        refreshToken: "refresh-invented",
        userID: "6f1c2a8e-0000-4000-8000-000000000001"
    )

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suite))
    }

    private func store() -> Session.Store {
        Session.Store(keychain: keychain, legacyKeychain: legacy, defaults: defaults)
    }

    @Test("credentials round-trip")
    func credentialsRoundTrip() async throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = store()

        try await store.save(credentials)

        #expect(try await store.credentials() == credentials)
    }

    @Test("an expiry with milliseconds survives to the millisecond")
    func anExpiryWithMillisecondsSurvives() async throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = store()
        let expiring = Session.Credentials(
            accessToken: "a", accessTokenExpiresAt: Date(timeIntervalSince1970: 1_792_570_500.25), refreshToken: "r", userID: "u"
        )

        try await store.save(expiring)

        let read = try #require(try await store.credentials())
        #expect(abs(read.accessTokenExpiresAt.timeIntervalSince(expiring.accessTokenExpiresAt)) < 0.002)
    }

    @Test("nothing saved reads as signed out")
    func nothingSavedReadsAsSignedOut() async throws {
        #expect(try await store().credentials() == nil)
    }

    @Test("a half-written session reads as signed out")
    func aHalfWrittenSessionReadsAsSignedOut() async throws {
        let store = store()
        try await store.save(credentials)
        try keychain.delete("refresh_token")

        #expect(try await store.credentials() == nil)
    }

    @Test("a save that fails partway never leaves a newer access token beside an older refresh token")
    func aSaveThatFailsPartwayLeavesNoMixedSession() async throws {
        let store = store()
        keychain.failNext(with: errSecInteractionNotAllowed)

        await #expect(throws: Session.KeychainError(status: errSecInteractionNotAllowed)) { try await store.save(credentials) }

        keychain.failNext(with: nil)
        #expect(keychain.contents["access_token"] == nil)
    }

    @Test("clearCredentials keeps hasSignedInBefore and a pending invite")
    func clearCredentialsKeepsHasSignedInBefore() async throws {
        let store = store()
        try await store.save(credentials)
        try await store.markSignedInBefore()
        try await store.setPendingInviteCode("7KQ2-M9XD-4RTA-B")

        try await store.clearCredentials()

        #expect(try await store.credentials() == nil)
        #expect(try await store.hasSignedInBefore)
        #expect(try await store.pendingInviteCode() == "7KQ2-M9XD-4RTA-B")
    }

    @Test("a pending invite code can be set and cleared")
    func aPendingInviteCodeCanBeSetAndCleared() async throws {
        let store = store()
        #expect(try await store.pendingInviteCode() == nil)

        try await store.setPendingInviteCode("7KQ2-M9XD-4RTA-B")
        try await store.setPendingInviteCode(nil)

        #expect(try await store.pendingInviteCode() == nil)
    }

    @Test("a fresh install wipes both services and writes the sentinel")
    func aFreshInstallWipesBothServices() async throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        try keychain.write(Data("left".utf8), account: "access_token")
        try keychain.write(Data("1".utf8), account: "has_signed_in_before")
        try legacy.write(Data("left".utf8), account: "jwt_token")

        try await store().applyInstallSentinel()

        #expect(keychain.contents.isEmpty)
        #expect(legacy.contents.isEmpty)
        #expect(defaults.object(forKey: Session.Store.installSentinelKey) != nil)
    }

    @Test("an update from the old app wipes nothing", arguments: Session.Store.legacyDefaultsKeys)
    func anUpdateFromTheOldAppWipesNothing(_ key: String) async throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: key)
        try legacy.write(Data("kept".utf8), account: "jwt_token")
        try keychain.write(Data("kept".utf8), account: "access_token")

        try await store().applyInstallSentinel()

        #expect(legacy.contents["jwt_token"] == Data("kept".utf8))
        #expect(keychain.contents["access_token"] == Data("kept".utf8))
        #expect(defaults.object(forKey: Session.Store.installSentinelKey) != nil)
    }

    @Test("once the sentinel is written, later launches wipe nothing")
    func laterLaunchesWipeNothing() async throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = store()
        try await store.applyInstallSentinel()
        try await store.save(credentials)

        try await store.applyInstallSentinel()

        #expect(try await store.credentials() == credentials)
    }

    @Test("a Keychain error surfaces its status, never a crash")
    func aKeychainErrorSurfacesItsStatus() async {
        let store = store()
        keychain.failNext(with: errSecInteractionNotAllowed)

        await #expect(throws: Session.KeychainError(status: errSecInteractionNotAllowed)) { try await store.credentials() }
        await #expect(throws: Session.KeychainError(status: errSecInteractionNotAllowed)) { try await store.hasSignedInBefore }
        await #expect(throws: Session.KeychainError(status: errSecInteractionNotAllowed)) { try await store.clearCredentials() }
    }

    @Test("a failed wipe leaves the sentinel unwritten, so the next launch tries again")
    func aFailedWipeLeavesTheSentinelUnwritten() async throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        legacy.failNext(with: errSecInteractionNotAllowed)

        await #expect(throws: Session.KeychainError.self) { try await store().applyInstallSentinel() }

        #expect(defaults.object(forKey: Session.Store.installSentinelKey) == nil)
    }
}
