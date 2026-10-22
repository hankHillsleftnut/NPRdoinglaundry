import Foundation
import GRDB
@testable import Retrospect
import Testing

@Suite(.timeLimit(.minutes(1)))
struct OutboxTests {
    private let database: Store.LocalDatabase
    private let recorder = Platform.Log.Recorder()
    private let clock = Date(timeIntervalSince1970: 1_792_569_604.2)
    private let id = UUID(uuidString: "00000000-0000-4000-8000-000000000901")!

    init() throws {
        database = try Store.LocalDatabase.inMemory()
    }

    private func outbox(timeZone: TimeZone = TimeZone(identifier: "Europe/London")!) -> Store.Outbox {
        let now = clock
        return Store.Outbox(database: database, now: { now }, timeZone: { timeZone }, log: recorder)
    }

    private func draft(_ text: String = "dentist at 3 today, dreading it", id: UUID? = nil, mediaPath: String? = nil) throws -> Store.EntryDraft {
        try #require(Store.EntryDraft(
            id: id ?? self.id, kind: .typed, text: text, createdAt: Date(timeIntervalSince1970: 1_792_587_731.41), mediaPath: mediaPath
        ))
    }

    private func counts() throws -> (entries: Int, outbox: Int) {
        try database.writer.read { db in
            try (Store.EntryRow.fetchCount(db), Store.OutboxRow.fetchCount(db))
        }
    }

    /// Synchronous reads: in an async test, `writer.read` picks GRDB's async overload.
    private func entryRow(_ key: String) throws -> Store.EntryRow? {
        try database.writer.read { try Store.EntryRow.fetchOne($0, key: key) }
    }

    private func outboxRow(_ key: String) throws -> Store.OutboxRow? {
        try database.writer.read { try Store.OutboxRow.fetchOne($0, key: key) }
    }

    private func allOutboxRows() throws -> [Store.OutboxRow] {
        try database.writer.read { try Store.OutboxRow.fetchAll($0) }
    }

    // MARK: Enqueue

    @Test("enqueue writes the entry and its outbox row, keyed by the same id")
    func enqueueWritesBoth() async throws {
        let returned = try await outbox().enqueueEntry(draft("  dentist at 3 today, dreading it \n"))

        let key = id.uuidString.lowercased()
        let entry = try #require(try entryRow(key))
        let item = try #require(try outboxRow(key))
        #expect(returned == id)
        #expect(entry.text == "dentist at 3 today, dreading it")
        #expect(entry.kind == .typed)
        #expect(entry.syncState == .local)
        #expect(entry.origin == .new)
        #expect(entry.day == "2026-10-21")
        #expect(item.entityID == key)
        #expect(item.operation == .entryCreate)
        #expect(item.status == .pending)
        #expect(item.attempts == 0)
        #expect(abs(item.nextAttemptAt.timeIntervalSince(clock)) < 0.001)
    }

    @Test("the stored payload is the contract's request body")
    func theStoredPayloadIsTheContractBody() async throws {
        try await outbox().enqueueEntry(draft())

        let payload = try #require(try outboxRow(id.uuidString.lowercased())).payload
        let stored = try JSONSerialization.jsonObject(with: payload) as? NSDictionary
        let fixture = try JSONSerialization.jsonObject(with: Fixtures.data("02", "entry.create.request")) as? NSDictionary
        #expect(stored == fixture)
    }

    @Test("enqueue writes the entry and the outbox row together, or neither", arguments: [true, false])
    func enqueueWritesBothOrNeither(_ outboxRowIsTaken: Bool) async throws {
        let key = id.uuidString.lowercased()
        try seed(takingOutboxRow: outboxRowIsTaken, key: key)

        await #expect(throws: DatabaseError.self) { try await outbox().enqueueEntry(draft()) }

        // Only the row that was already there.
        #expect(try counts() == (outboxRowIsTaken ? 0 : 1, outboxRowIsTaken ? 1 : 0))
        #expect(recorder.events.isEmpty)
    }

    private func seed(takingOutboxRow outboxRowIsTaken: Bool, key: String) throws {
        try database.writer.write { db in
            if outboxRowIsTaken {
                try db.execute(sql: """
                INSERT INTO outbox (id, operation, entity_id, payload, attempts, next_attempt_at, status, created_at)
                VALUES (?, 'entry.create', 'other', x'00', 0, '2026-10-21T08:00:04.200Z', 'done', '2026-10-21T08:00:04.200Z')
                """, arguments: [key])
            } else {
                try db.execute(sql: """
                INSERT INTO entries (local_id, kind, text, created_at, day, sync_state, attempts, origin)
                VALUES (?, 'typed', 'earlier', '2026-10-21T08:00:04.200Z', '2026-10-21', 'sent', 0, 'server')
                """, arguments: [key])
            }
        }
    }

    @Test("the same draft enqueued twice leaves one entry and one outbox row")
    func theSameDraftTwiceLeavesOne() async throws {
        let outbox = outbox()
        try await outbox.enqueueEntry(draft())

        await #expect(throws: DatabaseError.self) { try await outbox.enqueueEntry(draft()) }

        #expect(try counts() == (1, 1))
    }

    @Test("an absolute media path is refused and nothing is saved")
    func anAbsoluteMediaPathSavesNothing() async throws {
        await #expect(throws: Store.AbsoluteMediaPath()) { try await outbox().enqueueEntry(draft(mediaPath: "/var/mobile/a.m4a")) }

        #expect(try counts() == (0, 0))
    }

    @Test("empty text makes no draft", arguments: ["", "   ", "\n\t "])
    func emptyTextMakesNoDraft(_ text: String) {
        #expect(Store.EntryDraft(kind: .typed, text: text, createdAt: clock) == nil)
    }

    @Test("the entry's day is the person's day, in their time zone")
    func theDayIsInTheirTimeZone() async throws {
        let lateUTC = Date(timeIntervalSince1970: 1_792_625_400) // 2026-10-21T23:30:00Z
        let late = try #require(Store.EntryDraft(id: id, kind: .voice, text: "x", createdAt: lateUTC))

        try await outbox(timeZone: #require(TimeZone(identifier: "Asia/Tokyo"))).enqueueEntry(late)

        let entry = try #require(try entryRow(id.uuidString.lowercased()))
        #expect(entry.day == "2026-10-22")
        #expect(entry.kind == .voice)
    }

    @Test("no outbox log line carries entry text or ids")
    func noOutboxLogLineCarriesText() async throws {
        try await outbox().enqueueEntry(draft())

        #expect(recorder.events == [.outboxEnqueued(operation: .entryCreate)])
    }

    // MARK: Counting and retrying

    private func setStatus(_ status: Store.OutboxStatus, of entity: UUID, entryState: Store.SyncState? = nil) throws {
        try database.writer.write { db in
            try db.execute(
                sql: "UPDATE outbox SET status = ?, attempts = 4, last_error_code = 'invalidRequest' WHERE entity_id = ?",
                arguments: [status.rawValue, entity.uuidString.lowercased()]
            )
            if let entryState {
                try db.execute(
                    sql: "UPDATE entries SET sync_state = ?, failure_code = 'invalidRequest', attempts = 4 WHERE local_id = ?",
                    arguments: [entryState.rawValue, entity.uuidString.lowercased()]
                )
            }
        }
    }

    @Test("unsentCount counts pending, inFlight and dead, never done")
    func unsentCountCountsTheUnsent() async throws {
        let outbox = outbox()
        let ids = (0 ..< 4).map { _ in UUID() }
        for id in ids {
            try await outbox.enqueueEntry(draft(id: id))
        }
        try setStatus(.inFlight, of: ids[1])
        try setStatus(.dead, of: ids[2])
        try setStatus(.done, of: ids[3])

        #expect(try await outbox.unsentCount() == 3)
    }

    /// A row written by a later build, with an operation this one doesn't know. Synchronous, see above.
    private func insertRow(id: String, operation: String, status: Store.OutboxStatus) throws {
        try database.writer.write { db in
            try db.execute(
                sql: """
                INSERT INTO outbox (id, operation, entity_id, payload, attempts, next_attempt_at, status, created_at)
                VALUES (?, ?, ?, X'7B7D', 4, '2026-10-21T08:00:04.200Z', ?, '2026-10-21T08:00:04.200Z')
                """,
                arguments: [id, operation, id, status.rawValue]
            )
        }
    }

    private func storedOperation(_ id: String) throws -> String? {
        try database.writer.read { try String.fetchOne($0, sql: "SELECT operation FROM outbox WHERE id = ?", arguments: [id]) }
    }

    @Test("an outbox row with an operation this build doesn't know reads as unknown and still counts as unsent")
    func anUnknownOperationReadsAsUnknownAndCounts() async throws {
        let outbox = outbox()
        try insertRow(id: "later", operation: "entry.edit", status: .pending)

        let item = try #require(try outboxRow("later"))

        #expect(item.operation == .unknown)
        #expect(try await outbox.unsentCount() == 1)
    }

    @Test("retry keeps the stored operation of a row this build reads as unknown")
    func retryKeepsAnUnknownOperation() async throws {
        let outbox = outbox()
        let key = id.uuidString.lowercased()
        try insertRow(id: key, operation: "entry.edit", status: .dead)

        try await outbox.retry(entityID: id)

        #expect(try storedOperation(key) == "entry.edit")
        #expect(try #require(try outboxRow(key)).status == .pending)
    }

    @Test("retry moves a dead item back to pending and its entry back to local")
    func retryMovesADeadItemBack() async throws {
        let outbox = outbox()
        try await outbox.enqueueEntry(draft())
        try setStatus(.dead, of: id, entryState: .failed)

        try await outbox.retry(entityID: id)

        let key = id.uuidString.lowercased()
        let item = try #require(try outboxRow(key))
        let entry = try #require(try entryRow(key))
        #expect(item.status == .pending)
        #expect(item.attempts == 0)
        #expect(item.lastErrorCode == nil)
        #expect(abs(item.nextAttemptAt.timeIntervalSince(clock)) < 0.001)
        #expect(entry.syncState == .local)
        #expect(entry.failureCode == nil)
        #expect(entry.attempts == 0)
    }

    @Test("retry with nothing refused throws and changes nothing", arguments: [Store.OutboxStatus.pending, .inFlight, .done])
    func retryWithNothingRefusedChangesNothing(_ status: Store.OutboxStatus) async throws {
        let outbox = outbox()
        try await outbox.enqueueEntry(draft())
        try setStatus(status, of: id)
        let before = try allOutboxRows()

        await #expect(throws: Store.NothingToRetry()) { try await outbox.retry(entityID: id) }

        #expect(try allOutboxRows() == before)
    }

    // MARK: States

    @Test("states publishes the current states, then each change")
    func statesPublishesChanges() async throws {
        let outbox = outbox()
        try await outbox.enqueueEntry(draft())
        var states = outbox.states().makeAsyncIterator()

        #expect(await states.next() == [id: .local])
        try setStatus(.inFlight, of: id, entryState: .sending)
        #expect(await states.next() == [id: .sending])
    }

    @Test("states leaves out entries that came from the server or the old app")
    func statesLeavesOutOtherOrigins() throws {
        try database.writer.write { db in
            try db.execute(sql: """
            INSERT INTO entries (local_id, kind, text, created_at, day, sync_state, attempts, origin)
            VALUES ('00000000-0000-4000-8000-000000000777', 'typed', 'x', '2026-10-21T08:00:04.200Z', '2026-10-21', 'sent', 0, 'server')
            """)
        }

        #expect(try database.writer.read(Store.Outbox.syncStates).isEmpty)
    }
}

@Suite(.timeLimit(.minutes(1)))
struct CreateEntryEndpointTests {
    @Test("the create-entry door is a keyed POST to /v2/entries that retries as a keyed write")
    func theDoorIsAKeyedPost() {
        let id = UUID()
        let endpoint = Backend.Endpoints.CreateEntry(
            clientEntryID: id, content: .init(text: "x", kind: .typed, clientEntryID: id, createdAt: Date())
        )

        #expect(endpoint.method == .post)
        #expect(endpoint.path.rawValue == "/v2/entries")
        #expect(endpoint.idempotencyKey == id)
        #expect(endpoint.requiresAuth)
    }

    @Test("the request body encodes to the contract's fixtures", arguments: ["entry.create.request", "entry.create.request.voice"])
    func theBodyEncodesToTheFixture(_ name: String) throws {
        let fixture = try Fixtures.data("02", name)
        let body = try Backend.Coding.decoder.decode(Backend.Endpoints.CreateEntry.Body.self, from: fixture)

        let encoded = try JSONSerialization.jsonObject(with: Backend.Coding.encoder.encode(body)) as? NSDictionary

        #expect(try encoded == (JSONSerialization.jsonObject(with: fixture) as? NSDictionary))
    }

    @Test("the response decodes from the contract's fixture")
    func theResponseDecodes() throws {
        let data = try Fixtures.data("02", "entry.create.response")
        let created = try Backend.Coding.decoder.decode(Backend.Envelope<Backend.Endpoints.CreateEntry.Created>.self, from: data).data

        #expect(created.entry.clientEntryId == "00000000-0000-4000-8000-000000000901")
    }
}
