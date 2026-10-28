import Foundation
import GRDB
@testable import Retrospect
import Testing

/// FR.b1.data: the live first-run seam. Asks only keys the door accepts, keeps and queues each answer in one
/// write, resumes from the phone after a relaunch, hands `complete` to the outbox and the door's access state to
/// the session, and after sign-out does nothing for the next person.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct LiveFirstRunDataTests {
    private final class Access: @unchecked Sendable {
        private let lock = NSLock()
        private var seen: [Session.AccessState] = []

        var values: [Session.AccessState] {
            lock.withLock { seen }
        }

        func record(_ access: Session.AccessState) {
            lock.withLock { seen.append(access) }
        }
    }

    private let now = Date(timeIntervalSince1970: 1_792_569_604)
    private let database: Store.LocalDatabase
    private let sender = ScriptedSender()
    private let log = Platform.Log.Recorder()
    private let access = Access()
    private let outbox: Store.Outbox
    private let data: LiveFirstRunData

    init() throws {
        let database = try Store.LocalDatabase.inMemory(ownerUserID: "user-a")
        self.database = database
        outbox = Self.outbox(on: database, sender: sender, log: log, now: now)
        data = Self.seam(on: outbox, access: access, now: now)
    }

    private static func outbox(on database: Store.LocalDatabase, sender: ScriptedSender, log: Platform.Log.Recorder, now: Date) -> Store.Outbox {
        Store.Outbox(
            database: database, sender: sender, now: { now }, timeZone: { .gmt }, jitter: { $0 }, pick: { _ in 0 },
            sleep: { _ in try await Task.sleep(for: .seconds(3600)) }, log: log
        )
    }

    private static func seam(on outbox: Store.Outbox, access: Access, now: Date) -> LiveFirstRunData {
        LiveFirstRunData(outbox: outbox, setAccess: { access.record($0) }, now: { now })
    }

    private func rows() throws -> [Store.OutboxRow] {
        try database.writer.read { try Store.OutboxRow.order(Column("created_at"), Column.rowID).fetchAll($0) }
    }

    private func answerRows() throws -> [Store.FirstRunAnswerRow] {
        try database.writer.read { try Store.FirstRunAnswerRow.fetchAll($0) }
    }

    // MARK: The questions

    @Test("the live seam asks the 8 questions the door accepts, in the core order, and never struggle")
    func asksOnlyAcceptedKeys() async {
        await data.open()
        #expect(data.isLoaded)
        #expect(data.questions.map(\.key) == [.namePlace, .yearFromNow, .careMost, .onYourMind, .workingOn, .keepMeaning, .highLow, .people])
        #expect(data.answeredKeys.isEmpty)
        #expect(data.listening(for: .namePlace) == nil, "typed only until a recogniser lands")
    }

    // MARK: Answering

    @Test("an answer is kept on the phone and queued, in one write; the seam says saved and marks the key")
    func anAnswerIsSaved() async throws {
        await data.open()

        let outcome = await data.answer(.namePlace, text: "  sam, in london.  ", given: .typed)

        #expect(outcome == .saved)
        #expect(data.answeredKeys == [.namePlace])
        #expect(data.kept == [.namePlace: "sam, in london."], "trimmed, as the door would")
        let row = try #require(try rows().first)
        #expect(row.operation == .onboardingAnswer)
        let body = try Backend.Coding.decoder.decode(Backend.Endpoints.OnboardingAnswer.Body.self, from: row.payload)
        #expect(body.questionKey == .namePlace)
        #expect(body.text == "sam, in london.")
        #expect(body.given == .typed)
        #expect(body.clientEntryId == row.id)
        #expect(body.createdAt == now)
        #expect(try answerRows().map(\.text) == ["sam, in london."])
    }

    @Test("spoken answers are sent as voice")
    func voiceIsVoice() async throws {
        await data.open()
        _ = await data.answer(.careMost, text: "my sister.", given: .voice)
        let body = try Backend.Coding.decoder.decode(Backend.Endpoints.OnboardingAnswer.Body.self, from: #require(try rows().first).payload)
        #expect(body.given == .voice)
    }

    @Test("a key the door refuses, no words, or words past the door's limit are refused on the phone: nothing queued, nothing to dead-letter")
    func refusedOnThePhone() async throws {
        await data.open()
        let long = String(repeating: "a", count: LiveFirstRunData.longestAnswer + 1)

        #expect(await data.answer(.struggle, text: "sleep.", given: .typed) == .failedKept(.invalid))
        #expect(await data.answer(.namePlace, text: "   ", given: .typed) == .failedKept(.invalid))
        #expect(await data.answer(.namePlace, text: long, given: .typed) == .failedKept(.invalid))

        #expect(try rows().isEmpty)
        #expect(try answerRows().isEmpty)
        #expect(data.answeredKeys.isEmpty)
        // the limit itself is allowed
        #expect(await data.answer(.namePlace, text: String(repeating: "a", count: LiveFirstRunData.longestAnswer), given: .typed) == .saved)
    }

    @Test("when the store can't keep the answer, the words stay on screen (failedKept) and the key is not marked")
    func aStoreFailureKeepsTheWords() async throws {
        await data.open()
        try await database.writer.write { try $0.execute(sql: "DROP TABLE first_run_answers") }

        let outcome = await data.answer(.namePlace, text: "sam.", given: .typed)

        #expect(outcome == .failedKept(.unknown))
        #expect(data.answeredKeys.isEmpty)
        #expect(try rows().isEmpty, "no outbox row without the words row")
    }

    @Test("answering a question again (back, then changed words) keeps the newest words and queues the newer answer")
    func answeringAgain() async throws {
        await data.open()
        _ = await data.answer(.namePlace, text: "sam.", given: .typed)

        _ = await data.answer(.namePlace, text: "sam, in london.", given: .typed)

        #expect(data.kept[.namePlace] == "sam, in london.")
        #expect(try rows().count == 2)
    }

    // MARK: Resume

    @Test("after a relaunch the seam resumes from the phone: the answered keys and their words, with nothing sent yet")
    func resumesAfterRelaunch() async throws {
        await data.open()
        _ = await data.answer(.namePlace, text: "sam.", given: .typed)
        _ = await data.answer(.yearFromNow, text: "the seed is raised.", given: .typed)

        let relaunched = Self.seam(on: Self.outbox(on: database, sender: sender, log: log, now: now), access: access, now: now)
        #expect(relaunched.answeredKeys.isEmpty, "unknown until opened")
        await relaunched.open()

        #expect(relaunched.answeredKeys == [.namePlace, .yearFromNow])
        #expect(relaunched.kept == [.namePlace: "sam.", .yearFromNow: "the seed is raised."])
        #expect(!relaunched.isComplete)
        #expect(try await outbox.unsentCount() == 2, "and the outbox still has both to send")
    }

    // MARK: Offline, then online

    @Test("airplane mode: the answer is saved and the page moves on; the outbox pauses; back online it goes out once")
    func offlineThenOnline() async throws {
        await data.open()
        sender.inspect = { _ in }
        let outcome = await data.answer(.namePlace, text: "sam.", given: .typed)
        let id = try #require(try rows().first).id
        sender.script(id, [.failure(Backend.Failure(.offline))])

        #expect(outcome == .saved)
        await outbox.drain(reason: .manual)
        #expect(try rows().first?.status == .pending)
        #expect(try rows().first?.attempts == 0)

        await outbox.drain(reason: .reachability)
        #expect(try rows().first?.status == .done)
        #expect(sender.sends.filter { $0.id == id }.count == 2)
    }

    // MARK: Complete

    @Test("finishing queues complete behind the answers; when the door answers, the session keeps the new access state")
    func finishQueuesCompleteAndTheSessionLearns() async throws {
        await data.open()
        _ = await data.answer(.namePlace, text: "sam.", given: .typed)
        sender.script(Store.Outbox.completeID, [.success(Store.OutboxSendResult(access: .member))])

        await data.finishQuestions()

        #expect(data.completeQueued)
        #expect(!data.isComplete)
        #expect(try rows().map(\.operation) == [.onboardingAnswer, .onboardingComplete])
        await outbox.drain(reason: .manual)
        #expect(sender.sends.map(\.id).last == Store.Outbox.completeID)
        try await settle { data.isComplete }
        #expect(access.values == [.member])
        await data.finishQuestions()
        #expect(try rows().count == 2, "finishing again queues nothing new")
    }

    @Test("a relaunch after complete landed knows it (no second complete from the host)")
    func relaunchAfterComplete() async {
        await data.open()
        sender.script(Store.Outbox.completeID, [.success(Store.OutboxSendResult(access: .member))])
        await data.finishQuestions()
        await outbox.drain(reason: .manual)

        let relaunched = Self.seam(on: Self.outbox(on: database, sender: sender, log: log, now: now), access: access, now: now)
        await relaunched.open()

        #expect(relaunched.completeQueued)
        #expect(relaunched.isComplete)
    }

    // MARK: Sign-out

    @Test("after stop nothing is written, nothing is shown, and a late receipt never changes the session")
    func stopEndsEverything() async throws {
        await data.open()
        _ = await data.answer(.namePlace, text: "sam.", given: .typed)
        sender.script(Store.Outbox.completeID, [.success(Store.OutboxSendResult(access: .member))])
        await data.finishQuestions()

        data.stop()

        #expect(await data.answer(.yearFromNow, text: "nothing.", given: .typed) == .failedKept(.signedOut))
        #expect(try rows().count == 2, "no new row")
        #expect(data.answeredKeys == [.namePlace])
        await data.finishQuestions()
        await outbox.drain(reason: .manual)
        try await Task.sleep(for: .milliseconds(50))
        #expect(access.values.isEmpty, "the receipt after stop reached nobody")
        #expect(!data.isComplete)
    }

    @Test("one person's answers never reach another: B's store opens empty and A's files are gone (owner-bound store)")
    func answersNeverCrossPeople() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("first-run-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let a = try Store.LocalDatabase.onDisk(ownerUserID: "user-a", directory: directory)
        let aOutbox = Self.outbox(on: a, sender: sender, log: log, now: now)
        let aData = Self.seam(on: aOutbox, access: access, now: now)
        await aData.open()
        _ = await aData.answer(.namePlace, text: "sam.", given: .typed)
        #expect(try await aOutbox.firstRunAnswers() == [.namePlace: "sam."])

        let b = try Store.LocalDatabase.onDisk(ownerUserID: "user-b", directory: directory)
        let bOutbox = Self.outbox(on: b, sender: sender, log: log, now: now)
        let bData = Self.seam(on: bOutbox, access: access, now: now)
        await bData.open()

        #expect(bData.answeredKeys.isEmpty)
        #expect(bData.kept.isEmpty)
        #expect(try await bOutbox.unsentCount() == 0, "A's answer row is not in B's outbox")
        await bOutbox.drain(reason: .manual)
        #expect(sender.sends.isEmpty, "nothing of A's was sent as B")
    }

    @Test("nothing the seam does puts the person's words in the log")
    func noWordsInTheLog() async {
        await data.open()
        _ = await data.answer(.namePlace, text: "a secret only the person wrote", given: .typed)
        _ = await data.answer(.struggle, text: "another secret", given: .typed)
        await data.finishQuestions()
        await outbox.drain(reason: .manual)

        for event in log.events {
            let strings = ContentCheck.values(in: event).compactMap { $0 as? String }
            #expect(!strings.contains { $0.contains("secret") }, "\(event) carries the person's words")
        }
    }

    private func settle(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0 ..< 500 where !condition() {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(condition(), "did not settle")
    }
}

/// The seam through the environment (the wiring seam FR.b1.root mounts): built with the person's stack,
/// stopped and dropped before the store is erased, built again empty for the next person.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct LiveFirstRunEnvironmentTests {
    /// A synchronous read: in an async test, `writer.read` picks GRDB's async overload.
    private static func answerCount(_ database: Store.LocalDatabase) throws -> Int {
        try database.writer.read { try Store.FirstRunAnswerRow.fetchCount($0) }
    }

    private func settle(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0 ..< 500 where !condition() {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(condition(), "the stack did not settle")
    }

    @Test("signed in, the seam is built on the person's outbox and loads; sign-out stops and drops it; the next sign-in starts empty")
    func theSeamFollowsTheStack() async throws {
        let database = try Store.LocalDatabase.inMemory(ownerUserID: "user-a")
        let environment = Platform.AppEnvironment.preview(openDatabase: { _ in database })
        #expect(environment.firstRun == nil)
        await environment.sessionDidChange(to: "user-a").value
        let seam = try #require(environment.firstRun)
        try await settle { seam.isLoaded }
        #expect(await environment.answer(.namePlace, text: "sam.") == .saved)
        #expect(try await #require(environment.outbox).unsentCount() == 1)

        await environment.sessionWillChange().value

        #expect(environment.firstRun == nil)
        #expect(await seam.answer(.yearFromNow, text: "late.", given: .typed) == .failedKept(.signedOut), "a late answer lands nowhere")
        #expect(try Self.answerCount(database) == 0, "erased with the store")
        await environment.sessionDidChange(to: "user-a").value
        let next = try #require(environment.firstRun)
        try await settle { next.isLoaded }
        #expect(next.answeredKeys.isEmpty)
        #expect(next !== seam)
    }

    @Test("a session the server ended keeps the answers for the same person; Log Out then erases them")
    func aServerEndedSessionKeepsTheAnswers() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("first-run-env-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let environment = Platform.AppEnvironment.preview(openDatabase: { try Store.LocalDatabase.onDisk(ownerUserID: $0, directory: directory) })
        let (states, feed) = AsyncStream<Session.State>.makeStream()
        environment.follow(states)

        feed.yield(.signedIn(userID: "user-a", access: .approved))
        try await settle { environment.firstRun?.isLoaded == true }
        #expect(await environment.answer(.namePlace, text: "sam.") == .saved)

        feed.yield(.signedOut(hasSignedInBefore: true, reason: .revoked))
        try await settle { environment.firstRun == nil }
        feed.yield(.signedIn(userID: "user-a", access: .approved))
        try await settle { environment.firstRun?.isLoaded == true }
        #expect(environment.firstRun?.answeredKeys == [.namePlace], "kept for the same person")

        _ = await environment.logOut(confirmed: true)
        feed.yield(.signedIn(userID: "user-a", access: .approved))
        try await settle { environment.firstRun?.isLoaded == true && environment.firstRun?.answeredKeys.isEmpty == true }
    }
}

private extension Platform.AppEnvironment {
    func answer(_ key: Flows.QuestionKey, text: String) async -> Flows.AnswerOutcome? {
        await firstRun?.answer(key, text: text, given: .typed)
    }
}
