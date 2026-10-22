import Foundation
import GRDB
@testable import Retrospect
import Testing

@Suite(.timeLimit(.minutes(1)))
struct LocalDatabaseTests {
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    private func entry(
        _ id: String = UUID().uuidString,
        day: String = "2026-10-21",
        at seconds: TimeInterval = 1_792_569_604.2,
        state: Store.SyncState = .local,
        text: String = "invented"
    ) -> Store.EntryRow {
        Store.EntryRow(
            localID: id, serverID: nil, kind: .typed, text: text, createdAt: Date(timeIntervalSince1970: seconds), day: day,
            mediaPath: nil, syncState: state, failureCode: nil, attempts: 0, reading: nil, origin: .new
        )
    }

    /// Whether any of the database's files still holds `marker`.
    private func filesContain(_ marker: String, in directory: URL) throws -> Bool {
        try Store.LocalDatabase.fileNames.contains { name in
            let file = directory.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: file.path) else { return false }
            return try Data(contentsOf: file).range(of: Data(marker.utf8)) != nil
        }
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("store-\(UUID().uuidString)", isDirectory: true)
    }

    @Test("v1 creates every table and index")
    func v1CreatesEveryTableAndIndex() throws {
        let database = try Store.LocalDatabase.inMemory()

        let names = try database.writer.read { try String.fetchSet(
            $0,
            sql: "SELECT name FROM sqlite_master WHERE type IN ('table', 'index') AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'grdb_%'"
        ) }

        #expect(names == [
            "meta", "entries", "outbox", "cached_documents",
            "entries_day_created", "entries_sync_state", "outbox_status_next", "outbox_entity",
        ])
    }

    @Test("an entry row round-trips with every sync state", arguments: [Store.SyncState.local, .sending, .sent, .failed, .legacy])
    func anEntryRowRoundTrips(_ state: Store.SyncState) throws {
        let database = try Store.LocalDatabase.inMemory()
        var row = entry(state: state)
        row.serverID = "server-1"
        row.failureCode = "invalidRequest"
        row.reading = .waiting
        row.mediaPath = "RetrospectData/voice/a.m4a"

        try database.writer.write { try row.insert($0) }

        let read = try #require(try database.writer.read { try Store.EntryRow.fetchOne($0, key: row.localID) })
        #expect(abs(read.createdAt.timeIntervalSince(row.createdAt)) < 0.001)
        var same = read
        same.createdAt = row.createdAt
        #expect(same == row)
    }

    @Test("dates are stored as ISO 8601 UTC with milliseconds")
    func datesAreStoredAsISO() throws {
        let database = try Store.LocalDatabase.inMemory()
        let row = entry()
        try database.writer.write { try row.insert($0) }

        let stored = try database.writer.read { try String.fetchOne($0, sql: "SELECT created_at FROM entries") }

        #expect(stored == "2026-10-21T08:00:04.200Z")
    }

    @Test("an unknown kind, state or origin decodes as unknown")
    func anUnknownKindDecodesAsUnknown() throws {
        let database = try Store.LocalDatabase.inMemory()
        try database.writer.write { db in
            try db.execute(sql: """
            INSERT INTO entries (local_id, kind, text, created_at, day, sync_state, attempts, reading, origin)
            VALUES ('a', 'hologram', 'x', '2026-10-21T08:00:04.200Z', '2026-10-21', 'teleported', 0, 'skimmed', 'moon')
            """)
        }

        let read = try #require(try database.writer.read { try Store.EntryRow.fetchOne($0, key: "a") })

        #expect(read.kind == .unknown)
        #expect(read.syncState == .unknown)
        #expect(read.reading == .unknown)
        #expect(read.origin == .unknown)
    }

    @Test("entries for one day come back oldest first")
    func entriesForOneDayComeBackOldestFirst() throws {
        let database = try Store.LocalDatabase.inMemory()
        try database.writer.write { db in
            try entry("late", at: 1_792_570_000).insert(db)
            try entry("other-day", day: "2026-10-20", at: 1_792_400_000).insert(db)
            try entry("early", at: 1_792_560_000).insert(db)
        }

        let ids = try database.writer.read { try Store.EntryRow.onDay("2026-10-21").fetchAll($0).map(\.localID) }

        #expect(ids == ["early", "late"])
    }

    @Test("media paths are stored relative; an absolute path is refused", arguments: ["/var/mobile/Documents/a.m4a", "file:///a.m4a"])
    func mediaPathsAreStoredRelative(_ path: String) throws {
        let database = try Store.LocalDatabase.inMemory()
        var row = entry()
        row.mediaPath = path

        #expect(throws: Store.AbsoluteMediaPath()) { try database.writer.write { try row.insert($0) } }
        #expect(try database.writer.read { try Store.EntryRow.fetchCount($0) } == 0)
    }

    @Test("an outbox row and a cached document round-trip")
    func anOutboxRowAndACachedDocumentRoundTrip() throws {
        let database = try Store.LocalDatabase.inMemory()
        let outbox = Store.OutboxRow(
            id: "key-1", operation: "entry.create", entityID: "key-1", payload: Data("{}".utf8), attempts: 2,
            nextAttemptAt: Date(timeIntervalSince1970: 1_792_569_700), status: .inFlight, lastErrorCode: "timedOut",
            createdAt: Date(timeIntervalSince1970: 1_792_569_604)
        )
        let document = Store.CachedDocument(key: "brief.latest", body: Data("{}".utf8), fetchedAt: Date(timeIntervalSince1970: 1_792_569_604), etag: nil)

        try database.writer.write { db in
            try outbox.insert(db)
            try document.insert(db)
        }

        #expect(try database.writer.read { try Store.OutboxRow.fetchOne($0, key: "key-1") } == outbox)
        #expect(try database.writer.read { try Store.CachedDocument.fetchOne($0, key: "brief.latest") } == document)
    }

    @Test("a second open with the same owner keeps the data")
    func aSecondOpenWithTheSameOwnerKeepsTheData() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Store.LocalDatabase.onDisk(ownerUserID: "user-a", directory: directory).writer.write { try entry("kept").insert($0) }

        let reopened = try Store.LocalDatabase.onDisk(ownerUserID: "user-a", directory: directory)

        #expect(try reopened.writer.read { try Store.EntryRow.fetchCount($0) } == 1)
    }

    @Test("opening with another owner erases the previous owner's rows")
    func openingWithAnotherOwnerErases() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Store.LocalDatabase.onDisk(ownerUserID: "user-a", directory: directory).writer.write { db in
            try entry().insert(db)
            try Store.CachedDocument(key: "guesses", body: Data(), fetchedAt: Date(), etag: nil).insert(db)
        }

        let other = try Store.LocalDatabase.onDisk(ownerUserID: "user-b", directory: directory)

        #expect(try other.writer.read { try Store.EntryRow.fetchCount($0) } == 0)
        #expect(try other.writer.read { try Store.CachedDocument.fetchCount($0) } == 0)
        let owner = try other.writer.read { try String.fetchOne($0, sql: "SELECT value FROM meta WHERE key = 'owner_hash'") }
        #expect(owner == Store.LocalDatabase.ownerHash("user-b"))
    }

    @Test("the owner is stored as a hash, never the raw id")
    func theOwnerIsStoredAsAHash() throws {
        let database = try Store.LocalDatabase.inMemory(ownerUserID: "6f1c2a8e-0000-4000-8000-000000000001")

        let values = try database.writer.read { try String.fetchAll($0, sql: "SELECT value FROM meta") }

        #expect(!values.contains { $0.contains("6f1c2a8e") })
        #expect(values.contains { $0.count == 64 })
    }

    @Test("erase leaves an empty v1 database")
    func eraseLeavesAnEmptyV1Database() throws {
        let database = try Store.LocalDatabase.inMemory()
        try database.writer.write { try entry().insert($0) }

        try database.erase()

        #expect(try database.writer.read { try Store.EntryRow.fetchCount($0) } == 0)
        try database.writer.write { try entry().insert($0) }
        #expect(try database.writer.read { try Store.EntryRow.fetchCount($0) } == 1)
    }

    @Test("the data tables are every table but meta, read from the schema")
    func theDataTablesAreReadFromTheSchema() throws {
        let database = try Store.LocalDatabase.inMemory()

        let tables = try database.writer.read { try Store.LocalDatabase.dataTables($0) }

        #expect(tables == ["cached_documents", "entries", "outbox"])
    }

    @Test("erase empties a table a later migration adds")
    func eraseEmptiesALaterTable() throws {
        let database = try Store.LocalDatabase.inMemory()
        try database.writer.write { db in
            try db.execute(sql: "CREATE TABLE later_ring (id INTEGER PRIMARY KEY, kind TEXT NOT NULL)")
            try db.execute(sql: "INSERT INTO later_ring (kind) VALUES ('invented')")
        }

        try database.erase()

        #expect(try database.writer.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM later_ring") } == 0)
        #expect(try database.writer.read { try String.fetchOne($0, sql: "SELECT value FROM meta WHERE key = 'owner_hash'") } != nil)
    }

    @Test("after erase, no earlier text is left in the database's files")
    func eraseLeavesNoTextInTheFiles() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let marker = "marker-\(UUID().uuidString)"
        let database = try Store.LocalDatabase.onDisk(ownerUserID: "user-a", directory: directory)
        try database.writer.write { try entry(text: marker).insert($0) }
        try #require(try filesContain(marker, in: directory))

        try database.erase()

        #expect(try !filesContain(marker, in: directory))
        #expect(try database.writer.read { try Store.EntryRow.fetchCount($0) } == 0)
    }

    @Test("opening with another owner leaves none of the previous owner's text in the files")
    func anotherOwnerFindsNoTextInTheFiles() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let marker = "marker-\(UUID().uuidString)"
        try Store.LocalDatabase.onDisk(ownerUserID: "user-a", directory: directory).writer.write { try entry(text: marker).insert($0) }
        try #require(try filesContain(marker, in: directory))

        let other = try Store.LocalDatabase.onDisk(ownerUserID: "user-b", directory: directory)

        #expect(try !filesContain(marker, in: directory))
        #expect(try other.writer.read { try Store.EntryRow.fetchCount($0) } == 0)
    }

    @Test("a stored time without milliseconds still reads, so one odd row never fails a fetch")
    func aTimeWithoutMillisecondsStillReads() throws {
        let database = try Store.LocalDatabase.inMemory()
        try database.writer.write { db in
            try entry("a").insert(db)
            try db.execute(sql: """
            INSERT INTO entries (local_id, kind, text, created_at, day, sync_state, attempts, origin)
            VALUES ('b', 'typed', 'x', '2026-10-21T08:00:05Z', '2026-10-21', 'local', 0, 'new')
            """)
        }

        let rows = try database.writer.read { try Store.EntryRow.onDay("2026-10-21").fetchAll($0) }

        #expect(rows.map(\.localID) == ["a", "b"])
        #expect(rows.last?.createdAt == Date(timeIntervalSince1970: 1_792_569_605))
    }

    /// The simulator has no data protection and reports no protection class,
    /// so this runs on a device only.
    @Test("the database folder is protected until first unlock", .enabled(if: !isSimulator, "the simulator has no data protection"))
    func theDatabaseFolderIsProtectedUntilFirstUnlock() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        _ = try Store.LocalDatabase.onDisk(ownerUserID: "user-a", directory: directory)

        let attributes = try FileManager.default.attributesOfItem(atPath: directory.path)
        #expect(attributes[.protectionKey] as? FileProtectionType == .completeUntilFirstUserAuthentication)
    }
}
