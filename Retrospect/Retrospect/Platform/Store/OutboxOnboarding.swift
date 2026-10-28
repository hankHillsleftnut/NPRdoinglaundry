//
//  OutboxOnboarding.swift
//  FR.b1.data: the first run's answers through the outbox (contract 01 §4), never lost. An answer is
//  kept on the phone (`first_run_answers`, latest words per question: resume and the recap read it)
//  and queued (`onboarding.answer`, key = the answer's own id) in ONE transaction, so neither exists
//  without the other; it survives a kill and airplane mode like an entry. `onboarding.complete` is one
//  row per store, sent only when no answer row is still pending or in flight (a refused answer does
//  not hold it: it stays visible and the outbox logs it as a dead count). The door makes a member of
//  the person; the drainer hands that back through `completions()`.
//
import Foundation
import GRDB

extension Store {
    /// One first-run answer as the phone keeps it: the question's key and the person's latest words for it.
    struct FirstRunAnswerRow: Codable, Equatable, FetchableRecord, PersistableRecord, Sendable {
        static let databaseTableName = "first_run_answers"

        var key: String
        var text: String
        var createdAt: Date

        enum CodingKeys: String, CodingKey {
            case key, text, createdAt = "created_at"
        }

        static func databaseDateEncodingStrategy(for _: String) -> DatabaseDateEncodingStrategy {
            Store.Timestamp.encoding
        }

        static func databaseDateDecodingStrategy(for _: String) -> DatabaseDateDecodingStrategy {
            Store.Timestamp.decoding
        }
    }
}

extension Store.Outbox {
    /// The one `onboarding.complete` row's id (and entity) in a person's store. Fixed, so queueing it
    /// twice stores one row; a store is one person's, so it never clashes.
    static let completeID = "onboarding-complete"

    /// Keeps the answer's words for `key` (replacing earlier words for the same question) and queues
    /// `onboarding.answer` for the door, in one transaction. Returns the answer's id, which is the row's
    /// key. The caller has already checked the words (not empty, within the door's length).
    @discardableResult
    func enqueueAnswer(
        key: Flows.QuestionKey, doorKey: Backend.Endpoints.OnboardingAnswer.QuestionKey, text: String,
        given: Backend.Endpoints.OnboardingAnswer.Given, createdAt: Date, id: UUID = UUID()
    ) throws -> UUID {
        let payload = try Backend.Coding.encoder.encode(
            Backend.Endpoints.OnboardingAnswer.Body(questionKey: doorKey, text: text, given: given, clientEntryID: id, createdAt: createdAt)
        )
        let rowID = id.uuidString.lowercased()
        let queuedAt = now()
        let answer = Store.FirstRunAnswerRow(key: key.rawValue, text: text, createdAt: createdAt)
        let item = Store.OutboxRow(
            id: rowID, operation: .onboardingAnswer, entityID: rowID, payload: payload, attempts: 0,
            nextAttemptAt: queuedAt, status: .pending, lastErrorCode: nil, createdAt: queuedAt
        )
        try database.writer.write { db in
            try answer.save(db)
            try item.insert(db)
        }
        log.record(.outbox(.enqueued(operation: .onboardingAnswer)))
        if started {
            Task { await drain(reason: .afterWrite) }
        }
        return id
    }

    /// Queues `onboarding.complete`, once: a row already queued, in flight or delivered stays as it is;
    /// a refused one goes back in the queue. Returns whether a row was queued by this call.
    @discardableResult
    func enqueueComplete() throws -> Bool {
        let queuedAt = now()
        let payload = try Backend.Coding.encoder.encode(Backend.NoBody())
        let item = Store.OutboxRow(
            id: Self.completeID, operation: .onboardingComplete, entityID: Self.completeID, payload: payload, attempts: 0,
            nextAttemptAt: queuedAt, status: .pending, lastErrorCode: nil, createdAt: queuedAt
        )
        let queued = try database.writer.write { db -> Bool in
            if let existing = try Store.OutboxRow.fetchOne(db, key: Self.completeID) {
                guard existing.status == .dead else { return false }
                try db.execute(
                    sql: "UPDATE outbox SET status = ?, attempts = 0, last_error_code = NULL, next_attempt_at = ? WHERE id = ?",
                    arguments: [Store.OutboxStatus.pending.rawValue, Backend.Coding.timestamp(queuedAt), Self.completeID]
                )
                return true
            }
            try item.insert(db)
            return true
        }
        guard queued else { return false }
        log.record(.outbox(.enqueued(operation: .onboardingComplete)))
        if started {
            Task { await drain(reason: .afterWrite) }
        }
        return true
    }

    /// The words kept for each question on this phone, by key. A key this build doesn't know is left out.
    func firstRunAnswers() throws -> [Flows.QuestionKey: String] {
        let rows = try database.writer.read { try Store.FirstRunAnswerRow.fetchAll($0) }
        return Dictionary(rows.compactMap { row -> (Flows.QuestionKey, String)? in
            guard let key = Flows.QuestionKey(rawValue: row.key), key != .unknown else { return nil }
            return (key, row.text)
        }) { first, _ in first }
    }

    /// Whether `onboarding.complete` has been delivered.
    func isCompleteSent() throws -> Bool {
        try database.writer.read { db in
            try Store.OutboxRow.fetchOne(db, key: Self.completeID)?.status == .done
        }
    }

    // MARK: The drain rule

    /// An answer row the door hasn't answered yet (pending or in flight): `complete` waits for it.
    static func isAnswerOnItsWay(_ row: Store.OutboxRow) -> Bool {
        row.operation == .onboardingAnswer && (row.status == .pending || row.status == .inFlight)
    }

    /// `complete` is held while any answer is still on its way; a refused answer (dead) does not hold it.
    static func waitsForAnswers(_ row: Store.OutboxRow, among rows: [Store.OutboxRow]) -> Bool {
        row.operation == .onboardingComplete && rows.contains(where: isAnswerOnItsWay)
    }

    /// The `complete` rows a pass sends (due, and no answer on its way), decided after the pass's other rows.
    /// `anotherPass`: a due `complete` was held only by answers this very pass is sending (`sendingNow`, by
    /// entity), so one more pass sends it as soon as they have landed. Held by an answer that is waiting for
    /// its retry, it waits with it (the retry timer wakes both); a refused one never holds it.
    static func completeToSend(
        among rows: [Store.OutboxRow], cutoff: String, sendingNow: Set<String>
    ) -> (send: [Store.OutboxRow], anotherPass: Bool) {
        var send: [Store.OutboxRow] = []
        var anotherPass = false
        for row in rows where row.operation == .onboardingComplete {
            let isDue = row.status == .pending && Backend.Coding.timestamp(row.nextAttemptAt) <= cutoff
            guard isDue else { continue }
            if waitsForAnswers(row, among: rows) {
                anotherPass = anotherPass || rows.contains { isAnswerOnItsWay($0) && sendingNow.contains($0.entityID) }
            } else {
                send.append(row)
            }
        }
        return (send, anotherPass)
    }

    // MARK: Completion

    /// The access state the door answered each time `complete` lands (`member`). Nothing is replayed to a
    /// late listener; the row's `done` status (`isCompleteSent`) is the durable fact.
    func completions() -> AsyncStream<Session.AccessState> {
        let token = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: Session.AccessState.self)
        completionListeners[token] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.dropCompletionListener(token) }
        }
        return stream
    }

    private func dropCompletionListener(_ token: UUID) {
        completionListeners[token] = nil
    }

    func publishCompletion(_ access: Session.AccessState) {
        completionListeners.values.forEach { $0.yield(access) }
    }
}

extension Store.ClientSender {
    /// `onboarding.answer`: the stored bytes go out with the row's id as the key (the body's `clientEntryId`).
    func sendAnswer(_ item: Store.OutboxRow) async throws -> Store.OutboxSendResult {
        guard let key = UUID(uuidString: item.id) else { throw Backend.Failure(.invalidRequest) }
        let body: Backend.Endpoints.OnboardingAnswer.Body
        do {
            body = try Backend.Coding.decoder.decode(Backend.Endpoints.OnboardingAnswer.Body.self, from: item.payload)
        } catch {
            throw Backend.Failure(.invalidRequest)
        }
        // The door checks the header against the body's id; a row whose id isn't its body's would be refused for good.
        guard body.clientEntryId == key.uuidString.lowercased() else { throw Backend.Failure(.invalidRequest) }
        let saved = try await client.send(Backend.Endpoints.OnboardingAnswer(body: body))
        return Store.OutboxSendResult(serverID: saved.answer.id)
    }

    /// `onboarding.complete`: `{}` to the door; the access state it answers comes back for the session.
    func sendComplete() async throws -> Store.OutboxSendResult {
        let completed = try await client.send(Backend.Endpoints.OnboardingComplete())
        return Store.OutboxSendResult(access: completed.access.state)
    }
}
