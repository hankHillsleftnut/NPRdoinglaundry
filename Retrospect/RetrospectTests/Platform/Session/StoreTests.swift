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

    private let newer = Session.Credentials(
        accessToken: "access-newer",
        accessTokenExpiresAt: Date(timeIntervalSince1970: 1_792_574_100),
        refreshToken: "refresh-newer",
        userID: "6f1c2a8e-0000-4000-8000-000000000001"
    )

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suite))
    }

    private func store() -> Session.Store {
        Session.Store(keychain: keychain, legacyKeychain: legacy, defaults: defaults)
    }

    private func json(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object)
    }

    // MARK: Credentials

    @Test("credentials round-trip")
    func credentialsRoundTrip() async throws {
        let store = store()

        try await store.save(credentials)

        #expect(try await store.credentials() == credentials)
    }

    @Test("the access state, name, provider and Apple id are kept in the one item and read back")
    func theAddedFieldsRoundTrip() async throws {
        let store = store()
        let full = Session.Credentials(
            accessToken: "a", accessTokenExpiresAt: Date(timeIntervalSince1970: 1_792_570_500), refreshToken: "r", userID: "u",
            access: .waitlisted, firstName: "sam", provider: .apple, appleUserID: "001234.invented"
        )

        try await store.save(full)

        #expect(try await store.credentials() == full)
        #expect(Array(keychain.contents.keys) == ["session"])
    }

    @Test("an item saved before the added fields existed reads as unknown and nil, keeping its tokens")
    func anOlderItemReadsLeniently() async throws {
        try keychain.write(
            json(["accessToken": "a", "accessTokenExpiresAt": "2026-10-21T08:00:04.000Z", "refreshToken": "r", "userID": "u"]),
            account: "session"
        )

        let read = try #require(try await store().credentials())

        #expect(read.access == .unknown)
        #expect(read.provider == .unknown)
        #expect(read.firstName == nil)
        #expect(read.appleUserID == nil)
        #expect(read.refreshToken == "r")
    }

    @Test("an added field with a bad value reads as unknown, never costing the tokens", arguments: [
        ["access": 7, "provider": true], ["access": "brand_new", "provider": "other"], ["firstName": 3, "appleUserID": ["x"]],
    ] as [[String: Any]])
    func aBadAddedFieldReadsAsUnknown(_ extra: [String: Any]) async throws {
        let item = ["accessToken": "a", "refreshToken": "r", "userID": "u"].merging(extra) { old, _ in old }
        try keychain.write(json(item), account: "session")

        let read = try #require(try await store().credentials())

        #expect(read.accessToken == "a")
        #expect(read.access == .unknown)
        #expect(read.provider == .unknown)
    }

    @Test("install saves the session, then marks signed in before; a failed save marks nothing")
    func installSavesThenMarks() async throws {
        let store = store()

        try await store.install(credentials)
        #expect(try await store.credentials() == credentials)
        #expect(try await store.hasSignedInBefore)

        let second = Session.MemoryKeychain()
        second.failCall(1, with: errSecInteractionNotAllowed)
        let failing = Session.Store(keychain: second, legacyKeychain: legacy, defaults: defaults)
        await #expect(throws: Session.KeychainError(status: errSecInteractionNotAllowed)) { try await failing.install(credentials) }
        #expect(second.contents.isEmpty)
    }

    @Test("the whole session is one Keychain item")
    func theWholeSessionIsOneItem() async throws {
        try await store().save(credentials)

        #expect(Array(keychain.contents.keys) == ["session"])
    }

    @Test("an expiry with milliseconds survives to the millisecond")
    func anExpiryWithMillisecondsSurvives() async throws {
        let store = store()
        let expiring = Session.Credentials(
            accessToken: "a", accessTokenExpiresAt: Date(timeIntervalSince1970: 1_792_570_500.123), refreshToken: "r", userID: "u"
        )

        try await store.save(expiring)

        let read = try #require(try await store.credentials())
        #expect(abs(read.accessTokenExpiresAt.timeIntervalSince(expiring.accessTokenExpiresAt)) <= 0.001)
    }

    @Test("nothing saved reads as signed out")
    func nothingSavedReadsAsSignedOut() async throws {
        #expect(try await store().credentials() == nil)
    }

    @Test("a save that fails on any Keychain call leaves the previous session exactly as it was", arguments: 1 ... 4)
    func aFailedSaveLeavesThePreviousSession(_ failingCall: Int) async throws {
        let store = store()
        try await store.save(credentials)
        let before = keychain.contents
        keychain.failCall(failingCall, with: errSecInteractionNotAllowed)

        let saved: Bool
        do {
            try await store.save(newer)
            saved = true
        } catch {
            #expect(error as? Session.KeychainError == Session.KeychainError(status: errSecInteractionNotAllowed))
            saved = false
        }

        // Read the item directly: a store read would count as a Keychain call.
        let stored = keychain.contents["session"].flatMap(Session.Store.decode)
        if saved {
            #expect(stored == newer)
        } else {
            #expect(keychain.contents == before)
            #expect(stored == credentials)
        }
    }

    @Test("a later save replaces the whole session")
    func aLaterSaveReplacesTheWholeSession() async throws {
        let store = store()
        try await store.save(credentials)

        try await store.save(newer)

        #expect(try await store.credentials() == newer)
        #expect(keychain.contents.count == 1)
    }

    @Test(
        "an unreadable expiry reads as long past and keeps the tokens",
        arguments: [["accessTokenExpiresAt": "not a date"], ["accessTokenExpiresAt": 42], [:]] as [[String: Any]]
    )
    func anUnreadableExpiryKeepsTheTokens(_ expiry: [String: Any]) async throws {
        let item = ["accessToken": "a", "refreshToken": "r", "userID": "u"].merging(expiry) { old, _ in old }
        try keychain.write(json(item), account: "session")

        let read = try #require(try await store().credentials())

        #expect(read == Session.Credentials(accessToken: "a", accessTokenExpiresAt: .distantPast, refreshToken: "r", userID: "u"))
    }

    @Test("an expiry without milliseconds is read")
    func anExpiryWithoutMillisecondsIsRead() async throws {
        try keychain.write(
            json(["accessToken": "a", "accessTokenExpiresAt": "2026-10-21T08:00:04Z", "refreshToken": "r", "userID": "u"]),
            account: "session"
        )

        let read = try #require(try await store().credentials())

        #expect(read.accessTokenExpiresAt == Date(timeIntervalSince1970: 1_792_569_604))
    }

    @Test(
        "an item that isn't a whole session reads as signed out",
        arguments: [
            Data("not json".utf8),
            Data(#"{"accessToken":"a","accessTokenExpiresAt":"2026-10-21T08:00:04.000Z","userID":"u"}"#.utf8),
            Data(#"{"accessToken":"a","accessTokenExpiresAt":"2026-10-21T08:00:04.000Z","refreshToken":7,"userID":"u"}"#.utf8),
        ]
    )
    func anItemThatIsNotASessionReadsAsSignedOut(_ item: Data) async throws {
        try keychain.write(item, account: "session")

        #expect(try await store().credentials() == nil)
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
        #expect(Set(keychain.contents.keys) == ["has_signed_in_before", "pending_invite_code"])
    }

    @Test("a pending invite code can be set and cleared")
    func aPendingInviteCodeCanBeSetAndCleared() async throws {
        let store = store()
        #expect(try await store.pendingInviteCode() == nil)

        try await store.setPendingInviteCode("7KQ2-M9XD-4RTA-B")
        try await store.setPendingInviteCode(nil)

        #expect(try await store.pendingInviteCode() == nil)
    }

    @Test("a Keychain error surfaces its status, never a crash")
    func aKeychainErrorSurfacesItsStatus() async {
        let store = store()
        keychain.failEveryCall(with: errSecInteractionNotAllowed)

        await #expect(throws: Session.KeychainError(status: errSecInteractionNotAllowed)) { try await store.credentials() }
        await #expect(throws: Session.KeychainError(status: errSecInteractionNotAllowed)) { try await store.save(credentials) }
        await #expect(throws: Session.KeychainError(status: errSecInteractionNotAllowed)) { try await store.hasSignedInBefore }
        await #expect(throws: Session.KeychainError(status: errSecInteractionNotAllowed)) { try await store.clearCredentials() }
    }

    // MARK: Install sentinel

    @Test("a fresh install wipes both services and writes the sentinel")
    func aFreshInstallWipesBothServices() async throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        try keychain.write(Data("left".utf8), account: "session")
        try keychain.write(Data("1".utf8), account: "has_signed_in_before")
        try legacy.write(Data("left".utf8), account: "jwt_token")

        let check = try await store().applyInstallSentinel()

        #expect(check == .wipedLeftovers)
        #expect(keychain.contents.isEmpty)
        #expect(legacy.contents.isEmpty)
        #expect(defaults.object(forKey: Session.Store.installSentinelKey) != nil)
    }

    @Test("an update from the old app wipes nothing", arguments: Session.Store.legacyDefaultsKeys)
    func anUpdateFromTheOldAppWipesNothing(_ key: String) async throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: key)
        try legacy.write(Data("kept".utf8), account: "jwt_token")
        try keychain.write(Data("kept".utf8), account: "session")

        let check = try await store().applyInstallSentinel()

        #expect(check == .keptUpdate)
        #expect(legacy.contents["jwt_token"] == Data("kept".utf8))
        #expect(keychain.contents["session"] == Data("kept".utf8))
        #expect(defaults.object(forKey: Session.Store.installSentinelKey) != nil)
    }

    @Test("once the sentinel is written, later launches wipe nothing")
    func laterLaunchesWipeNothing() async throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = store()
        try await store.applyInstallSentinel()
        try await store.save(credentials)

        let check = try await store.applyInstallSentinel()

        #expect(check == .alreadyDone)
        #expect(try await store.credentials() == credentials)
    }

    @Test("a failed wipe leaves the sentinel unwritten, so the next launch tries again")
    func aFailedWipeLeavesTheSentinelUnwritten() async throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        legacy.failEveryCall(with: errSecInteractionNotAllowed)

        await #expect(throws: Session.KeychainError.self) { try await store().applyInstallSentinel() }

        #expect(defaults.object(forKey: Session.Store.installSentinelKey) == nil)
    }

    // MARK: The launch bridge

    @Test("at launch, the check logs what it did")
    func theLaunchCheckLogsWhatItDid() throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        let log = Platform.Log.Recorder()
        try legacy.write(Data("left".utf8), account: "jwt_token")

        let check = Session.Store.checkInstallAtLaunch(
            isUnlockedSinceBoot: true, log: log, keychain: keychain, legacyKeychain: legacy, defaults: defaults
        )

        #expect(check == .wipedLeftovers)
        #expect(legacy.contents.isEmpty)
        #expect(log.events == [.installChecked(.wipedLeftovers)])
    }

    @Test("before the first unlock, the launch check touches nothing and waits")
    func beforeTheFirstUnlockTheLaunchCheckWaits() throws {
        defer { defaults.removePersistentDomain(forName: suite) }
        let log = Platform.Log.Recorder()
        try keychain.write(Data("kept".utf8), account: "session")
        try legacy.write(Data("kept".utf8), account: "jwt_token")

        let check = Session.Store.checkInstallAtLaunch(
            isUnlockedSinceBoot: false, log: log, keychain: keychain, legacyKeychain: legacy, defaults: defaults
        )

        #expect(check == .deferredUntilUnlock)
        #expect(keychain.contents["session"] == Data("kept".utf8))
        #expect(legacy.contents["jwt_token"] == Data("kept".utf8))
        #expect(defaults.object(forKey: Session.Store.installSentinelKey) == nil)
        #expect(log.events == [.installChecked(.deferredUntilUnlock)])
    }

    @Test("a launch check that fails logs the Keychain status and doesn't throw")
    func aFailedLaunchCheckLogsTheStatus() {
        defer { defaults.removePersistentDomain(forName: suite) }
        let log = Platform.Log.Recorder()
        keychain.failEveryCall(with: errSecInteractionNotAllowed)

        let check = Session.Store.checkInstallAtLaunch(
            isUnlockedSinceBoot: true, log: log, keychain: keychain, legacyKeychain: legacy, defaults: defaults
        )

        #expect(check == nil)
        #expect(log.events == [.installCheckFailed(status: errSecInteractionNotAllowed)])
        #expect(defaults.object(forKey: Session.Store.installSentinelKey) == nil)
    }
}

@Suite(.timeLimit(.minutes(1)))
struct MemoryKeychainTests {
    @Test("failCall fails only the numbered call, once")
    func failCallFailsOnlyTheNumberedCall() throws {
        let keychain = Session.MemoryKeychain()
        keychain.failCall(2, with: errSecIO)

        try keychain.write(Data("1".utf8), account: "a")
        #expect(throws: Session.KeychainError(status: errSecIO)) { try keychain.write(Data("2".utf8), account: "a") }
        try keychain.write(Data("3".utf8), account: "b")

        #expect(keychain.contents == ["a": Data("1".utf8), "b": Data("3".utf8)])
    }

    @Test("failEveryCall fails every call until it's cleared")
    func failEveryCallFailsUntilCleared() throws {
        let keychain = Session.MemoryKeychain()
        keychain.failEveryCall(with: errSecIO)

        #expect(throws: Session.KeychainError(status: errSecIO)) { try keychain.read("a") }
        #expect(throws: Session.KeychainError(status: errSecIO)) { try keychain.deleteAll() }
        keychain.failEveryCall(with: nil)

        #expect(try keychain.read("a") == nil)
    }
}
