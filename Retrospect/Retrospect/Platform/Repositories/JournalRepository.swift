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
