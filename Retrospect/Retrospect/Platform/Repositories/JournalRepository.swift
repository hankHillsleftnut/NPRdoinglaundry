import Foundation
import GRDB

extension Platform {
    /// Where the app reads and writes what it keeps: each repository is the store plus the
    /// network for one area, so a screen's data never touches GRDB or the client directly.
    enum Repositories {}
}

extension Platform.Repositories {
    /// The journal's reads (PL3.1a: today). The store comes first; the server refreshes it.
    actor Journal {
        private let database: Store.LocalDatabase
        private let client: Backend.Client
        private let now: @Sendable () -> Date
        private let timeZone: @Sendable () -> TimeZone

        init(
            database: Store.LocalDatabase,
            client: Backend.Client,
            now: @escaping @Sendable () -> Date = { Date() },
            timeZone: @escaping @Sendable () -> TimeZone = { .current }
        ) {
            self.database = database
            self.client = client
            self.now = now
            self.timeZone = timeZone
        }

        /// The person's local day now, the same zone the client reports as `X-Time-Zone`.
        func localDay() -> String {
            Store.Outbox.day(of: now(), in: timeZone())
        }

        private static func todayKey(_ day: String) -> String {
            "entries.today.\(day)"
        }

        /// What the last fetch of `day` left in the store; nil when nothing was kept.
        func cachedToday(day: String) -> [Flows.Journal.Entry]? {
            let key = Self.todayKey(day)
            guard let document = try? database.writer.read({ try Store.CachedDocument.fetchOne($0, key: key) }) else { return nil }
            return try? Backend.Coding.decoder.decode([Flows.Journal.Entry].self, from: document.body)
        }

        /// Asks the server for today's entries and keeps them for next time. A fetch that
        /// finishes after the task was cancelled (sign-out) writes nothing.
        func refreshToday(day: String) async throws -> [Flows.Journal.Entry] {
            let today = try await client.send(Backend.Endpoints.EntriesToday())
            guard !Task.isCancelled else { throw CancellationError() }
            // The cache is keyed by the local day it was asked on; the server's own date is the same day.
            let document = try Store.CachedDocument(
                key: Self.todayKey(day), body: Backend.Coding.encoder.encode(today.entries), fetchedAt: now(), etag: nil
            )
            try? await database.writer.write { try document.save($0) }
            return today.entries
        }

        /// What the last fetch of the brief left in the store; nil when nothing was kept.
        func cachedBrief() -> Backend.Endpoints.BriefLatest.Latest? {
            guard let document = try? database.writer.read({ try Store.CachedDocument.fetchOne($0, key: "brief.latest") }) else { return nil }
            return try? Backend.Coding.decoder.decode(Backend.Endpoints.BriefLatest.Latest.self, from: document.body)
        }

        /// Asks the server for the latest brief and keeps the whole answer for next time.
        func refreshBrief() async throws -> Backend.Endpoints.BriefLatest.Latest {
            let latest = try await client.send(Backend.Endpoints.BriefLatest())
            guard !Task.isCancelled else { throw CancellationError() }
            let document = try Store.CachedDocument(
                key: "brief.latest", body: Backend.Coding.encoder.encode(latest), fetchedAt: now(), etag: nil
            )
            try? await database.writer.write { try document.save($0) }
            return latest
        }

        /// What the last fetch of the guesses left in the store; nil when nothing was kept.
        func cachedGuesses() -> [Flows.Journal.Guess]? {
            guard let document = try? database.writer.read({ try Store.CachedDocument.fetchOne($0, key: "guesses") }) else { return nil }
            return try? Backend.Coding.decoder.decode([Flows.Journal.Guess].self, from: document.body)
        }

        /// The guesses on offer, kept for next time. While the server isn't speaking the list is empty and so is the kept one.
        func refreshGuesses() async throws -> [Flows.Journal.Guess] {
            let listed = try await client.send(Backend.Endpoints.GuessesList())
            guard !Task.isCancelled else { throw CancellationError() }
            let guesses = listed.speaking ? listed.guesses : []
            let document = try Store.CachedDocument(
                key: "guesses", body: Backend.Coding.encoder.encode(guesses), fetchedAt: now(), etag: nil
            )
            try? await database.writer.write { try document.save($0) }
            return guesses
        }

        /// Sends an answer straight away. The server keeps the first answer and returns the stored status, so a
        /// repeat is safe; `key` is the id the outbox row would have had.
        func answerGuess(id: String, verdict: Flows.Journal.GuessVerdict, key: UUID) async throws -> Flows.Journal.Guess.Status {
            let answered = try await client.send(Backend.Endpoints.AnswerGuess(guessID: id, content: .init(verdict: verdict), key: key))
            return answered.status
        }

        /// Answers still waiting to be sent (queued, or in flight), by guess; the newest of a guess's wins.
        func queuedAnswers() -> [String: Flows.Journal.GuessVerdict] {
            let rows = (try? database.writer.read { db in
                try Store.OutboxRow.fetchAll(
                    db,
                    sql: "SELECT * FROM outbox WHERE operation = ? AND status IN (?, ?) ORDER BY created_at, rowid",
                    arguments: [Store.OutboxOperation.guessAnswer.rawValue, Store.OutboxStatus.pending.rawValue, Store.OutboxStatus.inFlight.rawValue]
                )
            }) ?? []
            var answers: [String: Flows.Journal.GuessVerdict] = [:]
            for row in rows {
                if let body = try? Backend.Coding.decoder.decode(Backend.Endpoints.AnswerGuess.Body.self, from: row.payload) {
                    answers[row.entityID] = body.verdict
                }
            }
            return answers
        }

        /// The entries written in this app for `day`, now and after every change, oldest first.
        nonisolated func rows(day: String) -> AsyncStream<[Store.EntryRow]> {
            let observation = ValueObservation.tracking { db in
                try Store.EntryRow
                    .filter(Column(Store.EntryRow.CodingKeys.origin) == Store.Origin.new.rawValue)
                    .filter(Column(Store.EntryRow.CodingKeys.day) == day)
                    .order(Column(Store.EntryRow.CodingKeys.createdAt), Column("rowid"))
                    .fetchAll(db)
            }
            .removeDuplicates()
            let writer = database.writer
            return AsyncStream { continuation in
                let cancellable = observation.start(
                    in: writer,
                    scheduling: .async(onQueue: DispatchQueue(label: "com.shauryanarang.Retrospect.journal.rows")),
                    onError: { _ in continuation.finish() },
                    onChange: { continuation.yield($0) }
                )
                continuation.onTermination = { _ in cancellable.cancel() }
            }
        }
    }
}
