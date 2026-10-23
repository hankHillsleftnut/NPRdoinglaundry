import AuthenticationServices
import Foundation
@testable import Retrospect
import Testing

/// The per-person stack follows `Session.States` for every kind of event, with the timing the app has:
/// states arrive on a stream, the store opens off the main actor, and nothing calls the old client.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct SessionDrivesStackTests {
    private func settle(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0 ..< 500 where !condition() {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(condition(), "the stack did not settle")
    }

    private func environment(_ databases: [String: Store.LocalDatabase]) -> Platform.AppEnvironment {
        Platform.AppEnvironment.preview(openDatabase: { id in
            guard let database = databases[id] else { throw CocoaError(.fileReadNoSuchFile) }
            return database
        })
    }

    private func entries(_ database: Store.LocalDatabase) async throws -> Int {
        try await database.writer.read { try Store.EntryRow.fetchCount($0) }
    }

    private func write(_ text: String, in environment: Platform.AppEnvironment) async throws {
        let outbox = try #require(environment.outbox)
        try await outbox.enqueueEntry(#require(Store.EntryDraft(kind: .typed, text: text, createdAt: Date())))
    }

    @Test("the matrix: sign-in, renewal, another person, the server ending the session, signing in again, a locked phone")
    func theEventMatrix() async throws {
        let a = try Store.LocalDatabase.inMemory(ownerUserID: "user-a")
        let b = try Store.LocalDatabase.inMemory(ownerUserID: "user-b")
        let env = environment(["user-a": a, "user-b": b])
        let (states, feed) = AsyncStream.makeStream(of: Session.State.self)
        env.follow(states)

        // nobody yet: nothing open, and the state is known
        feed.yield(.signedOut(hasSignedInBefore: false, reason: .none))
        try await settle { env.sessionState == .signedOut(hasSignedInBefore: false, reason: .none) }
        #expect(env.outbox == nil && env.journalData == nil)

        // Apple sign-in
        feed.yield(.signedIn(userID: "user-a", access: .member))
        try await settle { env.outbox != nil }
        let first = try #require(env.outbox)
        try await write("a's words", in: env)

        // a renewal (same person, state published again): the same stack, nothing lost
        feed.yield(.signedIn(userID: "user-a", access: .member))
        feed.yield(.locked)
        feed.yield(.signedIn(userID: "user-a", access: .member))
        try await settle { env.sessionState == .signedIn(userID: "user-a", access: .member) }
        #expect(env.outbox === first)
        #expect(try await entries(a) == 1)

        // another person signs in over the first, with no sign-out between
        feed.yield(.signedIn(userID: "user-b", access: .member))
        try await settle { env.outbox != nil && env.outbox !== first }
        #expect(try await entries(a) == 0, "a's words are erased before b's stack exists")
        try await write("b's words", in: env)

        // the server ends b's session
        feed.yield(.signedOut(hasSignedInBefore: true, reason: .revoked))
        try await settle { env.outbox == nil }
        #expect(try await entries(b) == 0)
        #expect(env.journalData == nil && env.reportSender == nil)

        // a signs in again: a clean store, a new stack
        feed.yield(.signedIn(userID: "user-a", access: .member))
        try await settle { env.outbox != nil }
        #expect(try await entries(a) == 0)
    }

    @Test("Sign in with Apple through the coordinator's own AppleSignIn reaches the session, opens the stack, and sends only /v2/auth/apple")
    func appleSignInOpensTheStack() async throws {
        let database = try Store.LocalDatabase.inMemory(ownerUserID: "u")
        let env = environment(["u": database])
        env.startSession()

        let urlSession = URLSession.stubbed()
        defer { StubProtocol.clear(urlSession) }
        let user = #"{"id":"u","firstName":"sam","isNew":true}"#
        let pair = #""accessToken":"invented.access","refreshToken":"invented-refresh","accessTokenExpiresAt":"2099-10-21T08:15:00.000Z""#
        let answer = Data(#"{"success":true,"data":{\#(pair),"user":\#(user),"access":{"state":"waitlisted"}}}"#.utf8)
        StubProtocol.register(on: urlSession) { (HTTPURLResponse.stub($0, status: 200), answer) }
        let client = Backend.Client(
            configuration: .resolve(.local, info: [:], isRelease: false), session: urlSession,
            tokens: env.session, reachability: ManualReachability(), clock: TestClock(), log: Platform.Log.Recorder()
        )
        let apple = Session.AppleSignIn(client: client, installer: env.session, log: Platform.Log.Recorder()) { Session.Nonce(raw: "invented-nonce") }
        apple.prepare(ASAuthorizationAppleIDProvider().createRequest())

        let outcome = try await apple.signIn(with: Session.AppleCredential(
            user: "001234.invented", identityToken: "invented.identity", authorizationCode: "invented-code",
            givenName: "sam", familyName: nil, email: nil
        ))

        try await settle { env.outbox != nil }
        #expect(outcome.access == .waitlisted)
        #expect(env.sessionState == .signedIn(userID: "u", access: .waitlisted))
        let paths = StubProtocol.requests(on: urlSession).map { $0.url?.path }
        #expect(paths == ["/v2/auth/apple"], "the new door only; no /auth/signin")
    }

    @Test("a store that can't be opened is reported, and 'try again' opens it")
    func storeOpenFailureCanBeRetried() async throws {
        let database = try Store.LocalDatabase.inMemory(ownerUserID: "user-a")
        let ready = Platform.Box(false)
        let env = Platform.AppEnvironment.preview(openDatabase: { _ in
            if ready.value {
                return database
            }
            throw CocoaError(.fileReadNoSuchFile)
        })
        let (states, feed) = AsyncStream.makeStream(of: Session.State.self)
        env.follow(states)

        feed.yield(.signedIn(userID: "user-a", access: .member))
        try await settle { env.storeOpenFailed }
        #expect(env.outbox == nil)

        ready.value = true
        env.retryOpeningStore()
        try await settle { env.outbox != nil }
        #expect(!env.storeOpenFailed)
    }
}
