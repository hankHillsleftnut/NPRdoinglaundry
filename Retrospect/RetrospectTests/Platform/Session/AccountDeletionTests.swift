import Foundation
import GRDB
@testable import Retrospect
import Testing

/// Apple's sheet, faked: answers with a code for an Apple account, or throws (closed, failed).
@MainActor
final class FakeApple: Session.AppleReauthorizing {
    var answer: Result<Session.AppleCode, any Error>
    private(set) var asked = 0

    init(_ answer: Result<Session.AppleCode, any Error>) {
        self.answer = answer
    }

    /// A code for the harness's signed-in Apple account.
    static func same() -> FakeApple {
        FakeApple(.success(Session.AppleCode(code: "c0de.invented.0001", user: "001234.invented")))
    }

    func freshCode() async throws -> Session.AppleCode {
        asked += 1
        return try answer.get()
    }
}

/// PL3.7g.min: deleting the account on the phone, end to end on the platform: the session harness's manager and
/// client against a stubbed server, and the person's store on disk (an in-memory database would erase nothing real).
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct AccountDeletionTests {
    private let folder = FileManager.default.temporaryDirectory.appendingPathComponent("delete-\(UUID().uuidString)", isDirectory: true)
    private let userID = SessionHarness.signedIn.userID

    private func environment(_ h: SessionHarness) -> Platform.AppEnvironment {
        let folder = folder
        let store = h.store
        return Platform.AppEnvironment(
            configuration: .resolve(.local, info: [:], isRelease: false), log: h.recorder, session: h.manager, client: h.client,
            reachability: h.reachability,
            invites: Session.InviteCenter(store: h.store, client: h.client, session: h.manager, log: h.recorder),
            floor: Platform.VersionFloor(runningVersion: "1.0", log: h.recorder),
            openDatabase: { try Store.LocalDatabase.onDisk(ownerUserID: $0, directory: folder) },
            firstAuthorization: h.store,
            pendingInviteCode: { try? await store.pendingInviteCode() }
        )
    }

    private func settle(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0 ..< 500 where !condition() {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(condition(), "the stack did not settle")
    }

    private func rows() throws -> Int {
        let database = try Store.LocalDatabase.onDisk(ownerUserID: userID, directory: folder)
        return try database.writer.read { try Store.OutboxRow.fetchCount($0) }
    }

    /// Signed in, the store open on disk with one unsent entry, a pending invite and Apple's kept first authorization.
    private func signedInWithWords(_ h: SessionHarness, _ env: Platform.AppEnvironment) async throws {
        try h.keychain.write(Data("7KQ2".utf8), account: "pending_invite_code")
        await h.store.keep(Session.KeptFirstAuthorization(appleUser: "001234.invented", givenName: "sam", familyName: nil, email: nil))
        env.startSession()
        try await settle { env.outbox != nil }
        let outbox = try #require(env.outbox)
        try await outbox.enqueueEntry(#require(Store.EntryDraft(kind: .typed, text: "unsent words", createdAt: Date())))
        #expect(try rows() == 1)
    }

    /// Whether the session ever read as ended by the server ("please sign in again").
    private static func flashedSignInAgain(_ states: [Session.State]) -> Bool {
        states.contains { state in
            if case .signedOut(_, .revoked) = state {
                return true
            }
            return false
        }
    }

    private func states(_ h: SessionHarness) -> Platform.Box<[Session.State]> {
        let seen = Platform.Box([Session.State]())
        let stream = h.manager.states()
        Task { for await state in stream {
            seen.value.append(state)
        } }
        return seen
    }

    // MARK: Nothing sent

    @Test("Apple's sheet closed: nothing is sent, the flag is never set, and the phone keeps everything")
    func appleCancelledSendsNothing() async throws {
        let h = try SessionHarness()
        let env = environment(h)
        try await signedInWithWords(h, env)

        let outcome = await env.deleteAccount(apple: FakeApple(.failure(Session.SignInError.cancelled)))

        #expect(outcome == .cancelledAtApple)
        #expect(h.requests(to: "/v2/account").isEmpty)
        #expect(h.keychain.contents["pending_deletion"] == nil)
        #expect(h.stored() == SessionHarness.signedIn)
        #expect(env.outbox != nil)
        #expect(try rows() == 1)
        #expect(h.recorder.events.contains(.accountDeletion(.cancelledAtApple)))
    }

    @Test("a different Apple account chosen: nothing is sent and nothing changes")
    func aDifferentAppleAccountSendsNothing() async throws {
        let h = try SessionHarness()
        let env = environment(h)
        try await signedInWithWords(h, env)

        let outcome = await env.deleteAccount(apple: FakeApple(.success(.init(code: "c0de.other", user: "009999.someone.else"))))

        #expect(outcome == .failed(.differentAppleAccount))
        #expect(h.requests(to: "/v2/account").isEmpty)
        #expect(h.keychain.contents["pending_deletion"] == nil)
        #expect(try rows() == 1)
    }

    @Test("offline: Apple isn't asked and nothing starts")
    func offlineStartsNothing() async throws {
        let h = try SessionHarness()
        let env = environment(h)
        h.reachability.set(online: false)
        let apple = FakeApple.same()

        #expect(await env.deleteAccount(apple: apple) == .offline)

        #expect(apple.asked == 0)
        #expect(StubProtocol.requests(on: h.session).isEmpty)
        #expect(h.keychain.contents["pending_deletion"] == nil)
    }

    // MARK: Under way

    @Test("202: the flag is set before sending, the body is the contract's, the phone is erased, and nothing more goes out")
    func acceptedErasesEverything() async throws {
        let h = try SessionHarness()
        let env = environment(h)
        try await signedInWithWords(h, env)
        let seen = states(h)
        let flagAtSend = Platform.Box<Data?>(nil)
        let keychain = h.keychain
        let accepted = try Fixtures.data("06", "account.delete.response")
        h.serve(["/v2/account": { _, _ in
            flagAtSend.value = keychain.contents["pending_deletion"]
            return (202, accepted)
        }])

        let outcome = await env.deleteAccount(apple: FakeApple.same())

        #expect(outcome == .deleted)
        #expect(flagAtSend.value != nil, "the flag is kept BEFORE the request goes out")
        let sent = try #require(h.requests(to: "/v2/account").first)
        #expect(sent.httpMethod == "DELETE")
        #expect(sent.value(forHTTPHeaderField: "Authorization") == "Bearer invented.access.token")
        #expect(h.bodies(to: "/v2/account").first?["confirm"] as? String == "delete")
        #expect(h.bodies(to: "/v2/account").first?["appleAuthorizationCode"] as? String == "c0de.invented.0001")
        #expect(env.outbox == nil && env.journalData == nil)
        #expect(try rows() == 0, "the unsent entry went with the account")

        // Between the 202 and the end: held. No token is handed out, so no request goes out, and nothing signs out.
        let afterSend = StubProtocol.requests(on: h.session).count
        await #expect(throws: Backend.Failure(.unauthenticated)) { _ = try await h.client.send(SessionDoor()) }
        await h.manager.becameActive()
        #expect(StubProtocol.requests(on: h.session).count == afterSend)
        #expect(await h.manager.state == .signedIn(userID: userID, access: .member), "the goodbye shows over a held session")

        await env.finishAccountDeletion()

        #expect(h.keychain.contents.isEmpty, "session, signed-in-before, pending invite, first authorization and the flag")
        #expect(h.mirror().isEmpty)
        #expect(await h.manager.state == .signedOut(hasSignedInBefore: false, reason: .none), "the splash, never welcome back")
        #expect(StubProtocol.requests(on: h.session).count == afterSend, "no sign-out or refresh with the dead tokens")
        #expect(h.recorder.events.contains(.accountDeletion(.finished)))
        try await settle { seen.value.last == .signedOut(hasSignedInBefore: false, reason: .none) }
        #expect(!Self.flashedSignInAgain(seen.value), "no 'please sign in again' flash")
        #expect(!String(describing: h.recorder.events).contains("c0de"), "the Apple code is never in a log line")
    }

    @Test("session_revoked after sending is the first request's own lock: deleted, with no refresh")
    func aRevokedSessionAfterSendingIsDone() async throws {
        let h = try SessionHarness()
        let env = environment(h)
        try await signedInWithWords(h, env)
        let revoked = try Fixtures.data("00", "error.session_revoked")
        h.serve([
            "/v2/account": { _, _ in (401, revoked) },
            "/v2/auth/refresh": { _, _ in (200, SessionHarness.refreshAnswer()) },
        ])

        #expect(await env.deleteAccount(apple: FakeApple.same()) == .deleted)

        #expect(h.requests(to: "/v2/account").count == 1)
        #expect(h.requests(to: "/v2/auth/refresh").isEmpty)
        #expect(try rows() == 0)
    }

    @Test("a 401 after sending is checked with one refresh: refused means the account is locked, so the phone is erased")
    func aPlain401ThenARefusedRefreshIsDone() async throws {
        let h = try SessionHarness()
        let env = environment(h)
        try await signedInWithWords(h, env)
        let seen = states(h)
        let unauthenticated = try Fixtures.data("00", "error.unauthenticated")
        let revoked = try Fixtures.data("00", "error.session_revoked")
        h.serve([
            "/v2/account": { _, _ in (401, unauthenticated) },
            "/v2/auth/refresh": { _, _ in (401, revoked) },
        ])

        #expect(await env.deleteAccount(apple: FakeApple.same()) == .deleted)

        #expect(h.requests(to: "/v2/account").count == 1, "the delete is never replayed")
        #expect(h.requests(to: "/v2/auth/refresh").count == 1)
        #expect(try rows() == 0)
        await env.finishAccountDeletion()
        try await settle { seen.value.last == .signedOut(hasSignedInBefore: false, reason: .none) }
        #expect(!Self.flashedSignInAgain(seen.value), "the refused refresh doesn't end the session under the goodbye")
    }

    @Test("a 401 that was only an expired token (the phone's clock behind): the refresh works, nothing is erased, the flag goes")
    func aPlain401ThenAWorkingRefreshKeepsEverything() async throws {
        let h = try SessionHarness()
        let env = environment(h)
        try await signedInWithWords(h, env)
        let unauthenticated = try Fixtures.data("00", "error.unauthenticated")
        h.serve([
            "/v2/account": { _, _ in (401, unauthenticated) },
            "/v2/auth/refresh": { _, _ in (200, SessionHarness.refreshAnswer()) },
        ])

        #expect(await env.deleteAccount(apple: FakeApple.same()) == .failed(.notNow))

        #expect(h.requests(to: "/v2/account").count == 1)
        #expect(h.requests(to: "/v2/auth/refresh").count == 1)
        #expect(try rows() == 1)
        #expect(env.outbox != nil)
        #expect(h.keychain.contents["pending_deletion"] == nil)
        #expect(h.stored()?.accessToken == "a2", "the refreshed session is kept")
        #expect(try await h.manager.accessToken() == "a2", "the hold is released")
    }

    @Test(
        "a 5xx after sending may come after the lock: nothing erased, the flag KEPT for the next launch's question",
        arguments: [("error.internal", 500), ("error.upstream_unavailable", 503), ("error.upstream_timeout", 504)]
    )
    func aServerErrorKeepsTheFlag(_ fixture: String, _ status: Int) async throws {
        let h = try SessionHarness()
        let env = environment(h)
        try await signedInWithWords(h, env)
        let body = try Fixtures.data("00", fixture)
        h.serve(["/v2/account": { _, _ in (status, body) }])

        #expect(await env.deleteAccount(apple: FakeApple.same()) == .failed(.noAnswer))

        #expect(h.requests(to: "/v2/account").count == 1, "sent once")
        #expect(h.keychain.contents["pending_deletion"] != nil)
        #expect(try rows() == 1)
        #expect(try await h.manager.accessToken() == "invented.access.token", "the hold is released")
    }

    // MARK: Refused or unanswered

    @Test(
        "a refusal shows the error line, erases nothing, clears the flag and leaves the session working; a retry can work",
        arguments: [("06", "error.apple_confirmation_required", 409), ("00", "error.rate_limited", 429), ("00", "error.invalid_credentials", 401)]
    )
    func aRefusalErasesNothing(_ folder: String, _ fixture: String, _ status: Int) async throws {
        let h = try SessionHarness()
        let env = environment(h)
        try await signedInWithWords(h, env)
        let refused = try Fixtures.data(folder, fixture)
        let accepted = try Fixtures.data("06", "account.delete.response")
        h.serve(["/v2/account": { count, _ in count == 0 ? (status, refused) : (202, accepted) }])

        let outcome = await env.deleteAccount(apple: FakeApple.same())

        #expect(outcome == .failed(fixture == "error.invalid_credentials" ? .appleRefused : .notNow))
        #expect(h.requests(to: "/v2/account").count == 1, "sent once, never retried by the client")
        #expect(h.keychain.contents["pending_deletion"] == nil)
        #expect(h.stored() == SessionHarness.signedIn)
        #expect(env.outbox != nil)
        #expect(try rows() == 1)
        #expect(try await h.manager.accessToken() == "invented.access.token", "the hold is released")

        #expect(await env.deleteAccount(apple: FakeApple.same()) == .deleted, "the retry asks Apple again and works")
    }

    @Test("no answer after sending: the error line, nothing erased, the flag kept for the next launch")
    func noAnswerKeepsTheFlag() async throws {
        let h = try SessionHarness()
        let env = environment(h)
        try await signedInWithWords(h, env)
        h.serve(["/v2/account": { _, _ in throw URLError(.timedOut) }])

        #expect(await env.deleteAccount(apple: FakeApple.same()) == .failed(.noAnswer))

        #expect(h.keychain.contents["pending_deletion"] != nil)
        #expect(try rows() == 1)
        #expect(h.stored() == SessionHarness.signedIn)
        #expect(h.recorder.events.contains(.accountDeletion(.unsure)))
    }

    // MARK: The next launch

    @Test("killed after sending: the next launch finds the account locked and finishes the erase, with no 'sign in again'")
    func killedAfterSendingFinishesOnLaunch() async throws {
        let h = try SessionHarness()
        let env = environment(h)
        try await signedInWithWords(h, env)
        try await h.store.markDeletionPending()
        let seen = states(h)
        let unauthenticated = try Fixtures.data("00", "error.unauthenticated")
        let revoked = try Fixtures.data("00", "error.session_revoked")
        h.serve([
            "/v2/access": { _, _ in (401, unauthenticated) },
            "/v2/auth/refresh": { _, _ in (401, revoked) },
        ])

        await env.resumeAccountDeletionIfPending()

        #expect(h.requests(to: "/v2/auth/refresh").count == 1, "one refresh tells a locked account from an expired token")
        #expect(try rows() == 0)
        #expect(h.keychain.contents.isEmpty)
        #expect(await h.manager.state == .signedOut(hasSignedInBefore: false, reason: .none))
        try await settle { seen.value.last == .signedOut(hasSignedInBefore: false, reason: .none) }
        #expect(!Self.flashedSignInAgain(seen.value))
    }

    @Test("a launch whose 401 was only an expired token: the refresh works, the flag goes, nothing is erased")
    func aLaunch401ThenAWorkingRefreshClearsTheFlag() async throws {
        let h = try SessionHarness()
        let env = environment(h)
        try await signedInWithWords(h, env)
        try await h.store.markDeletionPending()
        let unauthenticated = try Fixtures.data("00", "error.unauthenticated")
        h.serve([
            "/v2/access": { _, _ in (401, unauthenticated) },
            "/v2/auth/refresh": { _, _ in (200, SessionHarness.refreshAnswer()) },
        ])

        await env.resumeAccountDeletionIfPending()

        #expect(h.keychain.contents["pending_deletion"] == nil)
        #expect(try rows() == 1)
        #expect(h.stored()?.accessToken == "a2")
        #expect(h.recorder.events.contains(.accountDeletion(.resumeCleared)))
    }

    @Test("killed before the server heard: the next launch finds the session working, clears the flag and erases nothing")
    func killedBeforeTheServerHeardClearsTheFlag() async throws {
        let h = try SessionHarness()
        let env = environment(h)
        try await signedInWithWords(h, env)
        try await h.store.markDeletionPending()
        let member = try Fixtures.data("00", "access.member")
        h.serve(["/v2/access": { _, _ in (200, member) }])

        await env.resumeAccountDeletionIfPending()

        #expect(h.keychain.contents["pending_deletion"] == nil)
        #expect(h.stored() == SessionHarness.signedIn)
        #expect(try rows() == 1)
        #expect(h.recorder.events.contains(.accountDeletion(.resumeCleared)))
        #expect(try await h.manager.accessToken() == "invented.access.token")
    }

    @Test("a launch that can't reach the server keeps the flag and erases nothing")
    func aLaunchOfflineKeepsTheFlag() async throws {
        let h = try SessionHarness()
        let env = environment(h)
        try await signedInWithWords(h, env)
        try await h.store.markDeletionPending()
        h.reachability.set(online: false)

        await env.resumeAccountDeletionIfPending()

        #expect(h.keychain.contents["pending_deletion"] != nil)
        #expect(try rows() == 1)
        #expect(h.recorder.events.contains(.accountDeletion(.resumeKept)))
    }

    @Test("the session already gone with the flag set: the next launch erases everything, signed-in-before included")
    func noSessionWithTheFlagFinishes() async throws {
        let h = try SessionHarness(stored: nil)
        try h.keychain.write(Data("1".utf8), account: "has_signed_in_before")
        try await h.store.markDeletionPending()
        let env = environment(h)

        await env.resumeAccountDeletionIfPending()

        #expect(h.keychain.contents.isEmpty)
        #expect(await h.manager.state == .signedOut(hasSignedInBefore: false, reason: .none))
        #expect(StubProtocol.requests(on: h.session).isEmpty)
    }

    @Test("no flag: a launch asks nothing")
    func noFlagAsksNothing() async throws {
        let h = try SessionHarness()
        let env = environment(h)

        await env.resumeAccountDeletionIfPending()

        #expect(StubProtocol.requests(on: h.session).isEmpty)
        #expect(h.stored() == SessionHarness.signedIn)
    }

    // MARK: The sequence alone

    @Test("the resume decision: 200 clears, a dead session finishes, anything else keeps")
    func theResumeDecision() {
        #expect(Session.DeletionResume.after(nil) == .clear)
        #expect(Session.DeletionResume.after(.unauthenticated) == .finish)
        #expect(Session.DeletionResume.after(.sessionRevoked) == .finish)
        #expect(Session.DeletionResume.after(.suspended) == .keep)
        #expect(Session.DeletionResume.after(.offline) == .keep)
        #expect(Session.DeletionResume.after(.internal) == .keep)
    }
}
