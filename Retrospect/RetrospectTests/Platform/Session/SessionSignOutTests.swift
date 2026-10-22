import Foundation
@testable import Retrospect
import Security
import Testing

/// The manager's sign-in, sign-out, bridges and active-scene behaviour. The
/// refresh and 401 behaviour is in `SessionManagerTests`.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct SessionSignOutTests {
    private func failure(_ body: () async throws -> Void) async -> Backend.Failure? {
        do {
            try await body()
            Issue.record("expected a failure")
            return nil
        } catch let failure as Backend.Failure {
            return failure
        } catch {
            Issue.record("threw \(type(of: error)), not Backend.Failure")
            return nil
        }
    }

    private func fetchMeta(_ h: SessionHarness) async throws -> Backend.Meta {
        try await h.client.send(SessionDoor())
    }

    private func metaHandler(_ tokens: [String]) -> @Sendable (Int, URLRequest) throws -> (Int, Data) {
        let meta = try? Fixtures.data("00", "meta")
        let unauthenticated = try? Fixtures.data("00", "error.unauthenticated")
        return { _, request in
            let bearer = request.value(forHTTPHeaderField: "Authorization") ?? ""
            if tokens.contains(where: { bearer == "Bearer \($0)" }) {
                return (200, meta ?? Data())
            }
            return (401, unauthenticated ?? Data())
        }
    }

    // MARK: Sign-in

    @Test("a sign-in saves credentials, mirrors them, marks signed-in-before, and publishes signedIn to a watcher")
    func aSignInSavesMirrorsMarksAndPublishes() async throws {
        let h = try SessionHarness(stored: nil)
        let watcher = Task { await h.manager.states().prefix(2).reduce(into: [Session.State]()) { $0.append($1) } }
        #expect(await h.manager.state == .signedOut(hasSignedInBefore: false, reason: .none))

        try await h.manager.install(SessionHarness.signedIn)

        #expect(h.stored() == SessionHarness.signedIn)
        #expect(h.mirror() == ["jwt_token": "invented.access.token", "user_id": SessionHarness.signedIn.userID, "apple_user_id": "001234.invented"])
        #expect(h.keychain.contents["has_signed_in_before"] == Data("1".utf8))
        #expect(h.legacyState.value.last == SessionHarness.signedIn.userID)
        #expect(await watcher.value == [
            .signedOut(hasSignedInBefore: false, reason: .none), .signedIn(userID: SessionHarness.signedIn.userID, access: .member),
        ])
        #expect(try await h.manager.accessToken() == "invented.access.token")
    }

    @Test("the order of a sign-in's writes is session, mirror, flag")
    func theOrderOfASignInsWrites() async throws {
        final class Ordered: Session.KeychainBackend, @unchecked Sendable {
            let log: Platform.Box<[String]>
            let name: String
            init(_ name: String, log: Platform.Box<[String]>) {
                self.name = name
                self.log = log
            }

            func read(_: String) throws -> Data? { nil }
            func write(_: Data, account: String) throws { log.value.append("\(name).\(account)") }
            func delete(_ account: String) throws { log.value.append("\(name).delete.\(account)") }
            func deleteAll() throws {}
        }
        let writes = Platform.Box([String]())
        let store = Session.Store(keychain: Ordered("session", log: writes), legacyKeychain: Session.MemoryKeychain(), defaults: UserDefaults())
        let manager = Session.Manager(
            store: store, mirror: Session.LegacyMirror(keychain: Ordered("mirror", log: writes), stateChanged: { _ in }),
            log: Platform.Log.Recorder(), launchCheck: .alreadyDone, probeUnlock: { .unlocked }, clearGate: {}, appleCredentialState: { _ in .unknown }
        )

        try await manager.install(SessionHarness.signedIn)

        #expect(writes.value == ["session.session", "mirror.jwt_token", "mirror.user_id", "mirror.apple_user_id", "session.has_signed_in_before"])
    }

    @Test("a failed mirror doesn't fail the sign-in and is logged by status")
    func aFailedMirrorDoesntFailTheSignIn() async throws {
        let h = try SessionHarness(stored: nil)
        h.legacy.failEveryCall(with: errSecIO)

        try await h.manager.install(SessionHarness.signedIn)

        #expect(h.stored() == SessionHarness.signedIn)
        #expect(h.mirror().isEmpty)
        #expect(h.recorder.events.contains(.keychainWriteFailed(.mirror, status: errSecIO)))
        #expect(await h.manager.state == .signedIn(userID: SessionHarness.signedIn.userID, access: .member))
    }

    @Test("a save that fails at sign-in throws, mirrors nothing and marks nothing")
    func aFailedSaveAtSignInThrows() async throws {
        let h = try SessionHarness(stored: nil)
        _ = await h.manager.state
        h.keychain.failCall(1, with: errSecInteractionNotAllowed)

        await #expect(throws: Session.KeychainError(status: errSecInteractionNotAllowed)) { try await h.manager.install(SessionHarness.signedIn) }

        #expect(h.mirror().isEmpty)
        #expect(h.keychain.contents.isEmpty)
        #expect(await h.manager.state == .signedOut(hasSignedInBefore: false, reason: .none))
    }

    @Test("signing in while already signed in tells the server to end the old family first, best effort, then saves the new one")
    func signingInWhileSignedInEndsTheOldFamily() async throws {
        let h = try SessionHarness()
        let signedOut = try h.errorBody("signout.response")
        h.serve(["/v2/auth/signout": { _, _ in (200, signedOut) }])
        let newer = Session.Credentials(
            accessToken: "b1", accessTokenExpiresAt: Date(timeIntervalSince1970: 1_792_570_500), refreshToken: "rb", userID: "u2",
            access: .approved, firstName: nil, provider: .apple, appleUserID: "009"
        )

        try await h.manager.install(newer)

        #expect(h.bodies(to: "/v2/auth/signout").first?["refreshToken"] as? String == "invented-refresh-token")
        #expect(h.requests(to: "/v2/auth/signout").first?.value(forHTTPHeaderField: "Authorization") == "Bearer invented.access.token")
        #expect(h.requests(to: "/v2/auth/refresh").isEmpty, "signing out never refreshes")
        #expect(h.stored() == newer)
        #expect(await h.manager.state == .signedIn(userID: "u2", access: .approved))
    }

    @Test("a changed access state is kept with the session")
    func aChangedAccessStateIsKept() async throws {
        let h = try SessionHarness()

        await h.manager.setAccess(.approved)

        #expect(h.stored()?.access == .approved)
        #expect(await h.manager.state == .signedIn(userID: SessionHarness.signedIn.userID, access: .approved))
    }

    // MARK: Sign-out

    @Test("sign-out posts the stored refresh token, clears credentials, keeps hasSignedInBefore and the pending invite")
    func signOutPostsTheTokenAndKeepsTheFlags() async throws {
        let h = try SessionHarness()
        try h.keychain.write(Data("7KQ2".utf8), account: "pending_invite_code")
        try h.legacy.write(Data("x".utf8), account: "jwt_token")
        let signedOut = try h.errorBody("signout.response")
        h.serve(["/v2/auth/signout": { _, _ in (200, signedOut) }])

        let result = await h.manager.signOut(force: false)

        #expect(result == .signedOut)
        #expect(h.bodies(to: "/v2/auth/signout").count == 1)
        #expect(h.bodies(to: "/v2/auth/signout").first?["refreshToken"] as? String == "invented-refresh-token")
        #expect(h.requests(to: "/v2/auth/signout").first?.value(forHTTPHeaderField: "Authorization") == "Bearer invented.access.token")
        #expect(h.stored() == nil)
        #expect(Set(h.keychain.contents.keys) == ["has_signed_in_before", "pending_invite_code"])
        #expect(h.mirror().isEmpty)
        #expect(h.gateCleared.value == 1)
        #expect(h.legacyState.value.last == .some(nil))
        #expect(await h.manager.state == .signedOut(hasSignedInBefore: true, reason: .signedOut))
        #expect(h.recorder.events.contains(.signedOut(reason: .signedOut, serverNotified: true)))
        await #expect(throws: Backend.Failure(.unauthenticated)) { _ = try await h.manager.accessToken() }
    }

    @Test("an offline sign-out still signs out locally, and nothing is queued")
    func anOfflineSignOutSignsOutLocally() async throws {
        let h = try SessionHarness()
        h.reachability.set(online: false)

        let result = await h.manager.signOut(force: true)

        #expect(result == .signedOut)
        #expect(h.requests(to: "/v2/auth/signout").isEmpty)
        #expect(h.stored() == nil)
        #expect(h.mirror().isEmpty)
        #expect(await h.manager.state == .signedOut(hasSignedInBefore: true, reason: .signedOut))
        #expect(h.recorder.events.contains(.signedOut(reason: .signedOut, serverNotified: false)))
        h.reachability.set(online: true)
        #expect(await h.manager.signOut(force: true) == .signedOut, "signing out twice is still signed out")
        #expect(h.requests(to: "/v2/auth/signout").isEmpty)
    }

    @Test("sign-out with two unsent entries returns hasUnsent(2) and changes nothing; forced, it signs out")
    func signOutWithUnsentEntries() async throws {
        let h = try SessionHarness()
        h.unsent.value = 2
        let signedOut = try h.errorBody("signout.response")
        h.serve(["/v2/auth/signout": { _, _ in (200, signedOut) }])

        #expect(await h.manager.signOut(force: false) == .hasUnsent(count: 2))
        #expect(h.stored() == SessionHarness.signedIn)
        #expect(h.requests(to: "/v2/auth/signout").isEmpty)
        #expect(await h.manager.state == .signedIn(userID: SessionHarness.signedIn.userID, access: .member))

        #expect(await h.manager.signOut(force: true) == .signedOut)
        #expect(h.stored() == nil)
    }

    @Test("a sign-out whose server call gets 401 never refreshes: the old pair is simply dropped")
    func aSignOutNeverRefreshes() async throws {
        let h = try SessionHarness()
        let unauthenticated = try h.errorBody("error.unauthenticated")
        h.serve([
            "/v2/auth/signout": { _, _ in (401, unauthenticated) },
            "/v2/auth/refresh": { _, _ in (200, SessionHarness.refreshAnswer()) },
        ])
        h.advance(15 * 60) // expired too

        _ = await h.manager.signOut(force: true)

        #expect(h.requests(to: "/v2/auth/refresh").isEmpty)
        #expect(h.requests(to: "/v2/auth/signout").count == 1)
        #expect(h.stored() == nil)
    }

    // MARK: The old client's bridges

    @Test("the old client's 401 refreshes and re-mirrors once; after a revoked session it says signed out; offline it says unavailable and signs nothing out")
    func theOldClients401GoesThroughTheBridge() async throws {
        let h = try SessionHarness()
        h.serve(["/v2/auth/refresh": { _, _ in (200, SessionHarness.refreshAnswer()) }])

        #expect(await h.manager.refreshForLegacy() == .refreshed)
        #expect(h.mirror()["jwt_token"] == "a2")
        #expect(h.legacyState.value.last == SessionHarness.signedIn.userID)

        h.reachability.set(online: false)
        #expect(await h.manager.refreshForLegacy() == .unavailable)
        #expect(h.stored()?.accessToken == "a2")
        #expect(h.mirror()["jwt_token"] == "a2")
        h.reachability.set(online: true)

        let revoked = try h.errorBody("error.session_revoked")
        h.serve(["/v2/auth/refresh": { _, _ in (401, revoked) }])
        #expect(await h.manager.refreshForLegacy() == .signedOut)
        #expect(h.stored() == nil)
        #expect(h.mirror().isEmpty)
        #expect(await h.manager.refreshForLegacy() == .signedOut, "already signed out stays signed out, with no request")
        #expect(h.requests(to: "/v2/auth/refresh").count == 2)
        #expect(h.recorder.events.filter {
            if case .legacyRefresh = $0 {
                true
            } else {
                false
            }
        }.count == 4)
    }

    // MARK: Apple revocation and the active scene

    @Test("on an active scene an Apple session asks Apple; revoked signs out, authorized or unknown changes nothing")
    func theActiveSceneChecksApple() async throws {
        let h = try SessionHarness()
        h.appleState.value = .unknown
        await h.manager.becameActive()
        #expect(h.appleAsked.value == 1)
        #expect(h.stored() == SessionHarness.signedIn)

        h.appleState.value = .revoked
        await h.manager.becameActive()

        #expect(h.stored() == nil)
        #expect(h.mirror().isEmpty)
        #expect(h.recorder.events.contains(.appleCredentialRevoked))
        #expect(await h.manager.state == .signedOut(hasSignedInBefore: true, reason: .signedOut))
    }

    @Test("a session from another provider never asks Apple")
    func anotherProviderNeverAsksApple() async throws {
        let google = Session.Credentials(
            accessToken: "g", accessTokenExpiresAt: Date(timeIntervalSince1970: 1_792_570_500), refreshToken: "rg", userID: "u",
            access: .member, firstName: nil, provider: .google, appleUserID: nil
        )
        let h = try SessionHarness(stored: google)
        h.appleState.value = .revoked

        await h.manager.becameActive()

        #expect(h.appleAsked.value == 0)
        #expect(h.stored() == google)
    }

    @Test("an active scene renews a token about to expire, and leaves a fresh one alone")
    func theActiveSceneRefreshesIfNeeded() async throws {
        let h = try SessionHarness()
        h.serve(["/v2/auth/refresh": { _, _ in (200, SessionHarness.refreshAnswer()) }])

        await h.manager.becameActive()
        #expect(h.requests(to: "/v2/auth/refresh").isEmpty)

        h.advance(14 * 60 + 30)
        await h.manager.becameActive()
        #expect(h.requests(to: "/v2/auth/refresh").count == 1)
        #expect(h.stored()?.accessToken == "a2")
    }

    // MARK: The sign-out rule, from the fixtures

    @Test(
        "error.session_revoked and error.invalid_request on refresh sign out; every other error fixture keeps the credentials",
        arguments: FailureTests.errorFixtures.filter { $0.hasPrefix("00/") }
    )
    func theSignOutRuleFromTheFixtures(_ fixture: String) async throws {
        let parts = fixture.split(separator: "/").map(String.init)
        let h = try SessionHarness()
        let body = try Fixtures.data(parts[0], parts[1])
        let status = parts[1] == "error.unauthenticated" ? 401 : 400
        h.serve(["/v2/auth/refresh": { _, _ in (status, body) }])

        _ = await failure { _ = try await h.manager.refreshAfterUnauthorized(failedToken: "invented.access.token") }

        let signsOut = ["error.session_revoked", "error.invalid_request"].contains(parts[1])
        #expect((h.stored() == nil) == signsOut, "\(fixture)")
    }
}
