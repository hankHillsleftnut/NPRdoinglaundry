import Foundation
@testable import Retrospect
import Security
import Testing

/// The session manager with everything around it in memory: a Keychain for
/// the session, one for the old client's mirror, a stubbed server, a log,
/// and clocks the test moves by hand.
@MainActor
final class SessionHarness {
    /// A door that only needs a token: used to drive 401s through the client.
    struct Door: Backend.Endpoint {
        typealias Response = Backend.Meta
        var method: Backend.Method {
            .get
        }

        var path: Backend.PathTemplate {
            .meta
        }
    }

    let keychain = Session.MemoryKeychain()
    let legacy = Session.MemoryKeychain()
    let recorder = Platform.Log.Recorder()
    let session = URLSession.stubbed()
    let reachability = ManualReachability()
    let suite = "platform.tests.\(UUID().uuidString)"
    let defaults: UserDefaults
    let now = Platform.Box(Date(timeIntervalSince1970: 1_792_569_600)) // 2026-10-21T08:00:00Z
    let uptime = Platform.Box(TimeInterval(1000))
    let unsent = Platform.Box(0)
    let gateCleared = Platform.Box(0)
    let appleState = Platform.Box(Session.AppleCredentialState.authorized)
    let appleAsked = Platform.Box(0)
    let legacyState = Platform.Box([String?]())
    let probe = Platform.Box(Session.UnlockProbe.unlocked)
    let store: Session.Store
    let manager: Session.Manager
    let client: Backend.Client

    /// Saved by sign-in at 08:00:00; the token ends 08:15:00 server time.
    static let signedIn = Session.Credentials(
        accessToken: "invented.access.token", accessTokenExpiresAt: Date(timeIntervalSince1970: 1_792_570_500),
        refreshToken: "invented-refresh-token", userID: "00000000-0000-4000-8000-000000000001",
        access: .member, firstName: "sam", provider: .apple, appleUserID: "001234.invented"
    )

    init(launchCheck: Session.InstallCheck? = .alreadyDone, stored: Session.Credentials? = SessionHarness.signedIn) throws {
        if let stored {
            try keychain.write(Session.Store.encode(stored), account: "session")
            try keychain.write(Data("1".utf8), account: "has_signed_in_before")
        }
        defaults = try #require(UserDefaults(suiteName: suite))
        store = Session.Store(keychain: keychain, legacyKeychain: legacy, defaults: defaults)
        let gateCleared = gateCleared
        let appleState = appleState
        let appleAsked = appleAsked
        let legacyState = legacyState
        let now = now
        let uptime = uptime
        let unsent = unsent
        let probe = probe
        manager = Session.Manager(
            store: store,
            mirror: Session.LegacyMirror(keychain: legacy, stateChanged: { legacyState.value.append($0) }),
            log: recorder,
            launchCheck: launchCheck,
            probeUnlock: { probe.value },
            clearGate: { gateCleared.value += 1 },
            appleCredentialState: { _ in
                appleAsked.value += 1
                return appleState.value
            },
            unsentCount: { unsent.value },
            now: { now.value },
            uptime: { uptime.value }
        )
        client = Backend.Client(
            configuration: .resolve(.local, info: [:], isRelease: false),
            session: session,
            tokens: manager,
            reachability: reachability,
            clock: TestClock(),
            jitter: { _ in .zero },
            log: recorder
        )
        manager.connect(client)
    }

    deinit {
        StubProtocol.clear(session)
        defaults.removePersistentDomain(forName: suite)
    }

    /// A refresh answer: a new pair whose token ends 15 minutes after `at` (server time).
    static func refreshAnswer(access: String = "a2", refresh: String = "r2", expiresAt: Date = Date(timeIntervalSince1970: 1_792_570_500 + 900)) -> Data {
        let user = #"{"id":"00000000-0000-4000-8000-000000000001","firstName":"sam","isNew":false}"#
        let pair = #""accessToken":"\#(access)","refreshToken":"\#(refresh)","accessTokenExpiresAt":"\#(Backend.Coding.timestamp(expiresAt))""#
        return Data(#"{"success":true,"data":{\#(pair),"user":\#(user),"access":{"state":"member"}}}"#.utf8)
    }

    /// Answers each door in turn with `handlers[path]`, counting the calls.
    func serve(_ handlers: [String: @Sendable (Int, URLRequest) throws -> (Int, Data)]) {
        let counts = Platform.Box([String: Int]())
        StubProtocol.register(on: session) { request in
            let path = request.url?.path ?? ""
            let count = counts.value[path, default: 0]
            counts.value[path] = count + 1
            guard let handler = handlers[path] else { throw StubProtocol.Failure.noStub(method: request.httpMethod ?? "", url: path) }
            let (status, data) = try handler(count, request)
            return (HTTPURLResponse.stub(request, status: status), data)
        }
    }

    func requests(to path: String) -> [URLRequest] {
        StubProtocol.requests(on: session).filter { $0.url?.path == path }
    }

    func bodies(to path: String) -> [[String: Any]] {
        requests(to: path).compactMap { request in
            request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        }
    }

    func stored() -> Session.Credentials? {
        keychain.contents["session"].flatMap(Session.Store.decode)
    }

    func mirror() -> [String: String] {
        legacy.contents.compactMapValues { String(bytes: $0, encoding: .utf8) }
    }

    func errorBody(_ fixture: String) throws -> Data {
        try Fixtures.data("00", fixture)
    }

    /// Moves both clocks by `seconds`.
    func advance(_ seconds: TimeInterval) {
        now.value = now.value.addingTimeInterval(seconds)
        uptime.value += seconds
    }
}

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct SessionManagerTests {
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
        try await h.client.send(SessionHarness.Door())
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

    // MARK: Reading at start

    @Test("a stored session reads as signed in with its access state; nothing stored reads as signed out, with signed-in-before")
    func readsTheStoredSession() async throws {
        let signedIn = try SessionHarness()
        #expect(await signedIn.manager.state == .signedIn(userID: SessionHarness.signedIn.userID, access: .member))
        #expect(try await signedIn.manager.accessToken() == "invented.access.token")

        let fresh = try SessionHarness(stored: nil)
        #expect(await fresh.manager.state == .signedOut(hasSignedInBefore: false, reason: .none))
        await #expect(throws: Backend.Failure(.unauthenticated)) { _ = try await fresh.manager.accessToken() }
        #expect(fresh.requests(to: "/v2/auth/refresh").isEmpty)
    }

    @Test("a deferred launch check means locked: nothing is read, nothing refreshed, until the first active scene runs the check again")
    func aDeferredLaunchCheckRunsAgainOnTheFirstActive() async throws {
        let h = try SessionHarness(launchCheck: .deferredUntilUnlock)
        h.defaults.set(true, forKey: "hasCompletedOnboarding") // an update from the old app, launched prewarmed
        h.probe.value = .locked
        h.serve(["/v2/auth/refresh": { _, _ in (200, SessionHarness.refreshAnswer()) }])

        #expect(await h.manager.state == .locked)
        await #expect(throws: Backend.Failure(.unauthenticated)) { _ = try await h.manager.accessToken() }
        await h.manager.becameActive()
        #expect(await h.manager.state == .locked, "still locked: the probe still says locked")
        #expect(h.recorder.events == [.installChecked(.deferredUntilUnlock)])

        h.probe.value = .unlocked
        h.advance(14 * 60 + 30) // the token now ends within 60 s: the first active also refreshes
        await h.manager.becameActive()

        #expect(await h.manager.state == .signedIn(userID: SessionHarness.signedIn.userID, access: .member))
        #expect(h.recorder.events.prefix(2) == [.installChecked(.deferredUntilUnlock), .installChecked(.keptUpdate)])
        #expect(h.stored() == SessionHarness.signedIn || h.stored()?.accessToken == "a2", "nothing wiped")
        let activeIndex = h.recorder.events.firstIndex(of: .installChecked(.keptUpdate)) ?? 0
        let refreshIndex = h.recorder.events.firstIndex(of: .refreshed) ?? -1
        #expect(refreshIndex > activeIndex, "the check runs before any refresh")
    }

    @Test("a locked Keychain at read keeps the session locked, never signed out, and reads again when active")
    func aLockedKeychainReadsAgainWhenActive() async throws {
        let h = try SessionHarness()
        h.keychain.failEveryCall(with: errSecInteractionNotAllowed)

        #expect(await h.manager.state == .locked)
        #expect(h.recorder.events == [.sessionLocked(status: errSecInteractionNotAllowed)])

        h.keychain.failEveryCall(with: nil)
        await h.manager.becameActive()

        #expect(await h.manager.state == .signedIn(userID: SessionHarness.signedIn.userID, access: .member))
    }

    // MARK: The 401 replay

    @Test("a 401 on an authenticated door refreshes once and replays with the new token; a second 401 is unauthenticated")
    func a401RefreshesOnceAndReplays() async throws {
        let h = try SessionHarness()
        h.serve([
            "/v2/meta": metaHandler(["a2"]),
            "/v2/auth/refresh": { _, _ in (200, SessionHarness.refreshAnswer()) },
        ])

        let meta = try await fetchMeta(h)

        #expect(meta.latestVersion == "1.1 (55)")
        let sent = h.requests(to: "/v2/meta").map { $0.value(forHTTPHeaderField: "Authorization") }
        #expect(sent == ["Bearer invented.access.token", "Bearer a2"])
        #expect(h.requests(to: "/v2/auth/refresh").count == 1)
        #expect(h.bodies(to: "/v2/auth/refresh").first?["refreshToken"] as? String == "invented-refresh-token")
        #expect(h.recorder.events.contains(.requestReplayed(path: .meta)))

        // The new token is refused too: no third try.
        h.serve([
            "/v2/meta": metaHandler([]),
            "/v2/auth/refresh": { _, _ in (200, SessionHarness.refreshAnswer(access: "a3", refresh: "r3")) },
        ])
        let thrown = await failure { _ = try await fetchMeta(h) }
        #expect(thrown?.kind == .unauthenticated)
        #expect(h.requests(to: "/v2/meta").count == 4)
    }

    @Test("a public door never refreshes on 401")
    func aPublicDoorNeverRefreshes() async throws {
        let h = try SessionHarness()
        let unauthenticated = try h.errorBody("error.unauthenticated")
        h.serve([
            "/v2/meta": { _, _ in (401, unauthenticated) },
            "/v2/auth/refresh": { _, _ in (200, SessionHarness.refreshAnswer()) },
        ])

        let thrown = await failure { _ = try await h.client.send(Backend.Endpoints.Meta()) }

        #expect(thrown?.kind == .unauthenticated)
        #expect(h.requests(to: "/v2/meta").count == 1)
        #expect(h.requests(to: "/v2/auth/refresh").isEmpty)
    }

    @Test("ten concurrent 401s cause exactly one refresh and all ten replay")
    func tenConcurrent401sCauseOneRefresh() async throws {
        let h = try SessionHarness()
        h.serve([
            "/v2/meta": metaHandler(["a2"]),
            "/v2/auth/refresh": { _, _ in (200, SessionHarness.refreshAnswer()) },
        ])

        let versions = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0 ..< 10 {
                group.addTask { try await fetchMeta(h).latestVersion }
            }
            return try await group.reduce(into: [String]()) { $0.append($1) }
        }

        #expect(versions.count == 10)
        #expect(h.requests(to: "/v2/auth/refresh").count == 1)
        #expect(h.requests(to: "/v2/meta").count == 20)
        #expect(h.requests(to: "/v2/meta").filter { $0.value(forHTTPHeaderField: "Authorization") == "Bearer a2" }.count == 10)
    }

    @Test("a stale failed token returns the already-refreshed token without a second refresh")
    func aStaleFailedTokenReturnsTheRefreshedOne() async throws {
        let h = try SessionHarness()
        h.serve(["/v2/auth/refresh": { _, _ in (200, SessionHarness.refreshAnswer()) }])

        let fresh = try await h.manager.refreshAfterUnauthorized(failedToken: "invented.access.token")
        let again = try await h.manager.refreshAfterUnauthorized(failedToken: "invented.access.token")

        #expect(fresh == "a2")
        #expect(again == "a2")
        #expect(h.requests(to: "/v2/auth/refresh").count == 1)
    }

    // MARK: Proactive refresh and clocks

    @Test("a token expiring within 60 s is refreshed before the request; a token received 10 s ago is not, whatever the device clock says")
    func expiringTokensRefreshFirstUnlessJustReceived() async throws {
        let h = try SessionHarness()
        h.serve([
            "/v2/meta": metaHandler(["invented.access.token", "a2"]),
            "/v2/auth/refresh": { _, _ in (200, SessionHarness.refreshAnswer(expiresAt: Date(timeIntervalSince1970: 1_792_570_500 + 900))) },
        ])
        h.advance(14 * 60 + 10) // 08:14:10: 50 s left

        _ = try await fetchMeta(h)

        #expect(h.requests(to: "/v2/auth/refresh").count == 1, "refreshed before the request")
        #expect(h.requests(to: "/v2/meta").map { $0.value(forHTTPHeaderField: "Authorization") } == ["Bearer a2"])

        // Received 10 s ago on the monotonic clock, but the device clock leaps to past the expiry.
        h.uptime.value += 10
        h.now.value = h.now.value.addingTimeInterval(60 * 60)
        _ = try await fetchMeta(h)
        #expect(h.requests(to: "/v2/auth/refresh").count == 1, "not refreshed again")
    }

    @Test("a device clock 20 minutes ahead causes one refresh, not one per request")
    func aClockAheadCausesOneRefresh() async throws {
        let h = try SessionHarness()
        h.now.value = h.now.value.addingTimeInterval(20 * 60) // the phone thinks the token is already gone
        h.serve([
            "/v2/meta": metaHandler(["a2"]),
            "/v2/auth/refresh": { _, _ in (200, SessionHarness.refreshAnswer(expiresAt: Date(timeIntervalSince1970: 1_792_569_600 + 900))) },
        ])

        for _ in 0 ..< 5 {
            h.uptime.value += 120
            _ = try await fetchMeta(h)
        }

        #expect(h.requests(to: "/v2/auth/refresh").count == 1)
        #expect(h.requests(to: "/v2/meta").count == 5)
    }

    // MARK: Refresh failures

    @Test("a revoked or invalid-request refresh signs out once, clears the mirror and the gate, and publishes signedOut(revoked)", arguments: [
        "error.session_revoked", "error.invalid_request",
    ])
    func aRevokedRefreshSignsOut(_ fixture: String) async throws {
        let h = try SessionHarness()
        try h.legacy.write(Data("old".utf8), account: "jwt_token")
        let body = try h.errorBody(fixture)
        h.serve(["/v2/auth/refresh": { _, _ in (401, body) }])
        let watcher = Task { await h.manager.states().first { $0 != .signedIn(userID: SessionHarness.signedIn.userID, access: .member) } }

        let thrown = await failure { _ = try await h.manager.refreshAfterUnauthorized(failedToken: "invented.access.token") }

        #expect(thrown?.kind == .sessionRevoked)
        #expect(h.stored() == nil)
        #expect(h.mirror().isEmpty)
        #expect(h.gateCleared.value == 1)
        #expect(await h.manager.state == .signedOut(hasSignedInBefore: true, reason: .revoked))
        #expect(await watcher.value == .signedOut(hasSignedInBefore: true, reason: .revoked))
        #expect(h.recorder.events.filter { $0 == .sessionRevoked }.count == 1)
        #expect(h.requests(to: "/v2/auth/refresh").count == 1, "never retried")
        #expect(h.requests(to: "/v2/auth/signout").isEmpty)
        #expect(h.legacyState.value.last == .some(nil))
    }

    @Test("an offline, timed-out, rate-limited, internal or unreadable refresh keeps the credentials", arguments: [
        "offline", "timedOut", "rateLimited", "internal", "unreadable",
    ])
    func failedRefreshesKeepTheCredentials(_ failure: String) async throws {
        let h = try SessionHarness()
        let rateLimited = try h.errorBody("error.rate_limited")
        let internalError = try h.errorBody("error.internal")
        switch failure {
        case "offline": h.reachability.set(online: false)
        case "timedOut": StubProtocol.register(on: h.session) { _ in throw URLError(.timedOut) }
        case "rateLimited": h.serve(["/v2/auth/refresh": { _, _ in (429, rateLimited) }])
        case "internal": h.serve(["/v2/auth/refresh": { _, _ in (500, internalError) }])
        default: h.serve(["/v2/auth/refresh": { _, _ in (200, Data("<html>".utf8)) }])
        }

        let thrown = await self.failure { _ = try await h.manager.refreshAfterUnauthorized(failedToken: "invented.access.token") }

        #expect(thrown != nil)
        #expect(thrown?.kind != .sessionRevoked)
        #expect(h.stored() == SessionHarness.signedIn)
        #expect(await h.manager.state == .signedIn(userID: SessionHarness.signedIn.userID, access: .member))
        #expect(h.gateCleared.value == 0)
        #expect(h.recorder.events.contains {
            if case .refreshFailed = $0 {
                true
            } else {
                false
            }
        })
    }

    @Test("a timed-out refresh is retried once and the retry's pair is saved; a session_revoked refresh is never retried")
    func aTimedOutRefreshIsRetriedOnce() async throws {
        let h = try SessionHarness()
        h.serve([
            "/v2/auth/refresh": { count, _ in
                if count == 0 {
                    throw URLError(.timedOut)
                }
                return (200, SessionHarness.refreshAnswer())
            },
        ])

        let token = try await h.manager.refreshAfterUnauthorized(failedToken: "invented.access.token")

        #expect(token == "a2")
        #expect(h.requests(to: "/v2/auth/refresh").count == 2)
        #expect(h.bodies(to: "/v2/auth/refresh").map { $0["refreshToken"] as? String } == ["invented-refresh-token", "invented-refresh-token"])
        #expect(h.stored()?.refreshToken == "r2")
        #expect(h.stored()?.provider == .apple, "the provider and Apple id carry over")
        #expect(h.stored()?.appleUserID == "001234.invented")
        #expect(h.mirror()["jwt_token"] == "a2")
        #expect(h.recorder.events.contains(.refreshRetried))

        // Three timeouts in a row: two sends, then the failure.
        h.serve(["/v2/auth/refresh": { _, _ in throw URLError(.timedOut) }])
        _ = await failure { _ = try await h.manager.refreshAfterUnauthorized(failedToken: "a2") }
        #expect(h.requests(to: "/v2/auth/refresh").count == 4)
    }

    @Test("an unreadable 200 on refresh is sent again once; the server has rotated, so the retry lands inside the grace")
    func anUnreadableRefreshAnswerIsRetriedOnce() async throws {
        let h = try SessionHarness()
        h.serve([
            "/v2/auth/refresh": { count, _ in count == 0 ? (200, Data()) : (200, SessionHarness.refreshAnswer()) },
        ])

        let token = try await h.manager.refreshAfterUnauthorized(failedToken: "invented.access.token")

        #expect(token == "a2")
        #expect(h.requests(to: "/v2/auth/refresh").count == 2)
    }

    @Test("a save that fails after a refresh keeps the new pair in memory, logs the status, and saves on the next active scene")
    func aFailedSaveAfterRefreshIsRetriedWhenActive() async throws {
        let h = try SessionHarness()
        h.serve([
            "/v2/meta": metaHandler(["a2"]),
            "/v2/auth/refresh": { _, _ in (200, SessionHarness.refreshAnswer()) },
        ])
        h.keychain.failCall(1, with: errSecIO)

        let token = try await h.manager.refreshAfterUnauthorized(failedToken: "invented.access.token")

        #expect(token == "a2")
        #expect(h.stored() == SessionHarness.signedIn, "the old pair is still on disk")
        #expect(h.recorder.events.contains(.keychainWriteFailed(.session, status: errSecIO)))
        #expect(try await h.manager.accessToken() == "a2")

        await h.manager.becameActive()
        #expect(h.stored()?.accessToken == "a2")
        #expect(h.requests(to: "/v2/auth/refresh").count == 1)
    }

    @Test("without a connected client a refresh fails as transport and keeps the credentials")
    func withoutAClientARefreshFailsAsTransport() async throws {
        let h = try SessionHarness()
        let store = Session.Store(keychain: h.keychain, legacyKeychain: h.legacy, defaults: h.defaults)
        let lone = Session.Manager(
            store: store, mirror: Session.LegacyMirror(keychain: h.legacy, stateChanged: { _ in }), log: h.recorder, launchCheck: .alreadyDone,
            probeUnlock: { .unlocked }, clearGate: {}, appleCredentialState: { _ in .unknown }
        )

        let thrown = await failure { _ = try await lone.refreshAfterUnauthorized(failedToken: "invented.access.token") }

        #expect(thrown?.kind == .transport)
        #expect(h.recorder.events.contains(.sessionNotConnected))
        #expect(await lone.state == .signedIn(userID: SessionHarness.signedIn.userID, access: .member))
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
        #expect((h.stored() == nil) == signsOut, fixture)
    }
}
