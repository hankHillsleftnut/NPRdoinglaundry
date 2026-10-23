import Foundation
import GRDB
@testable import Retrospect
import Testing

/// The founder's rule: unsent words are never erased silently. A session the server ends keeps them; a different
/// person's sign-in or the person's own confirmed Log Out erases them. Real files in a temp folder, because an
/// in-memory database has no owner check and would pass without the rule.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct SessionKeepsWordsTests {
    private let folder = FileManager.default.temporaryDirectory.appendingPathComponent("keeps-\(UUID().uuidString)", isDirectory: true)

    private func environment() -> Platform.AppEnvironment {
        let folder = folder
        return Platform.AppEnvironment.preview(openDatabase: { try Store.LocalDatabase.onDisk(ownerUserID: $0, directory: folder) })
    }

    private func settle(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0 ..< 500 where !condition() {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(condition(), "the stack did not settle")
    }

    private func rows(for user: String) throws -> Int {
        let database = try Store.LocalDatabase.onDisk(ownerUserID: user, directory: folder)
        return try database.writer.read { try Store.OutboxRow.fetchCount($0) }
    }

    private func queueWord(in env: Platform.AppEnvironment) async throws {
        let outbox = try #require(env.outbox)
        try await outbox.enqueueEntry(#require(Store.EntryDraft(kind: .typed, text: "unsent words", createdAt: Date())))
    }

    @Test("the server ends the session: the stack stops, the words stay on the phone, and the same person gets them back")
    func serverEndedKeepsTheWords() async throws {
        let env = environment()
        let (states, feed) = AsyncStream.makeStream(of: Session.State.self)
        env.follow(states)
        feed.yield(.signedIn(userID: "user-a", access: .member))
        try await settle { env.outbox != nil }
        try await queueWord(in: env)

        feed.yield(.signedOut(hasSignedInBefore: true, reason: .revoked))
        try await settle { env.outbox == nil }

        #expect(env.journalData == nil)
        #expect(try rows(for: "user-a") == 1, "kept")
        feed.yield(.signedIn(userID: "user-a", access: .member))
        try await settle { env.outbox != nil }
        #expect(try await env.unsentEntryCount() == 1, "the same person has them again, ready to send")
    }

    @Test("a different person signing in erases the last person's words before their own store opens")
    func differentPersonErasesFirst() async throws {
        let env = environment()
        let (states, feed) = AsyncStream.makeStream(of: Session.State.self)
        env.follow(states)
        feed.yield(.signedIn(userID: "user-a", access: .member))
        try await settle { env.outbox != nil }
        try await queueWord(in: env)
        feed.yield(.signedOut(hasSignedInBefore: true, reason: .revoked))
        try await settle { env.outbox == nil }

        feed.yield(.signedIn(userID: "user-b", access: .member))
        try await settle { env.outbox != nil }

        #expect(try await env.unsentEntryCount() == 0, "b's outbox is empty: a's words are not b's to send")
        #expect(try rows(for: "user-b") == 0)
    }

    @Test("a cold launch that says signed out never touches a store on disk")
    func coldLaunchKeepsTheFile() async throws {
        let first = environment()
        await first.sessionDidChange(to: "user-a").value
        try await queueWord(in: first)
        await first.closeStore(erasing: false)

        let relaunch = environment()
        let (states, feed) = AsyncStream.makeStream(of: Session.State.self)
        relaunch.follow(states)
        feed.yield(.signedOut(hasSignedInBefore: true, reason: .none))
        feed.yield(.locked)
        try await Task.sleep(for: .milliseconds(100))

        #expect(try rows(for: "user-a") == 1)
    }

    @Test("Log Out with words not sent asks first; declined changes nothing; confirmed signs out and erases")
    func logOutAsks() async throws {
        let env = environment()
        try await env.session.install(Session.Credentials(
            accessToken: "invented.access", accessTokenExpiresAt: Date().addingTimeInterval(900),
            refreshToken: "invented-refresh", userID: "user-a", access: .member
        ))
        env.startSession()
        try await settle { env.outbox != nil }
        try await queueWord(in: env)

        #expect(await env.logOut(confirmed: false) == .hasUnsent(1))
        #expect(env.outbox != nil)
        #expect(try await env.unsentEntryCount() == 1)
        if case .signedIn = await env.session.state {} else {
            Issue.record("still signed in after declining")
        }

        #expect(await env.logOut(confirmed: true) == .signedOut)
        try await settle { env.outbox == nil }
        #expect(try rows(for: "user-a") == 0, "erased on the person's own confirmed choice")
        if case .signedOut = await env.session.state {} else {
            Issue.record("signed out")
        }
    }
}
