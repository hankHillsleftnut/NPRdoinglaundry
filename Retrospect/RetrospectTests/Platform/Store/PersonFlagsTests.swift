import Foundation
import GRDB
@testable import Retrospect
import Testing

/// INVITE-FLAGS: the per-person "you're in seen" flag lives in the person's
/// own database: kept for them, erased with them, never inherited.
@Suite(.timeLimit(.minutes(1)))
struct PersonFlagsTests {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("flags-\(UUID().uuidString)", isDirectory: true)
    }

    /// Opens `owner`'s store in `directory`, marks the flag, and lets go of the store.
    private func markSeen(owner: String, in directory: URL) async throws {
        let flags = try Store.PersonFlags(database: Store.LocalDatabase.onDisk(ownerUserID: owner, directory: directory))
        try await flags.set(.youreInSeen)
        #expect(try await flags.isSet(.youreInSeen))
    }

    private func seen(owner: String, in directory: URL) async throws -> Bool {
        let flags = try Store.PersonFlags(database: Store.LocalDatabase.onDisk(ownerUserID: owner, directory: directory))
        return try await flags.isSet(.youreInSeen)
    }

    @Test("the flag starts unset, sets once, and setting it again keeps the first time")
    func setsOnce() async throws {
        let database = try Store.LocalDatabase.inMemory(ownerUserID: "user-a")
        let times = Platform.Box([Date(timeIntervalSince1970: 1_792_569_600), Date(timeIntervalSince1970: 1_792_569_700)])
        let flags = Store.PersonFlags(database: database, now: { times.value.removeFirst() })
        #expect(try await flags.isSet(.youreInSeen) == false)

        try await flags.set(.youreInSeen)
        try await flags.set(.youreInSeen)

        #expect(try await flags.isSet(.youreInSeen))
        let rows: [[String]] = try await database.writer.read { db in
            try Row.fetchAll(db, sql: "SELECT key, value, set_at FROM flags").map { [$0["key"], $0["value"], $0["set_at"]] }
        }
        #expect(rows == [["youre_in_seen", "1", "2026-10-21T08:00:00.000Z"]], "one row; the first time stands")
    }

    @Test("the same person keeps it across a relaunch, or signing back in after the server ended the session (the store is reopened, not erased)")
    func theSamePersonKeepsIt() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try await markSeen(owner: "user-a", in: directory)

        #expect(try await seen(owner: "user-a", in: directory))
    }

    @Test("Log Out's erase clears it (it is a data table, not meta)")
    func eraseClearsIt() async throws {
        let database = try Store.LocalDatabase.inMemory(ownerUserID: "user-a")
        let flags = Store.PersonFlags(database: database)
        try await flags.set(.youreInSeen)

        try database.erase()

        #expect(try await flags.isSet(.youreInSeen) == false)
        let meta = try await database.writer.read { try String.fetchAll($0, sql: "SELECT key FROM meta") }
        #expect(meta == [Store.MetaKey.ownerHash], "nothing but the owner lives in meta")
    }

    @Test("a different person signing in on the phone never inherits it, and the first person's flag is gone with their files")
    func aDifferentPersonNeverInheritsIt() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try await markSeen(owner: "user-a", in: directory)

        #expect(try await seen(owner: "user-b", in: directory) == false)
        #expect(try await seen(owner: "user-a", in: directory) == false, "B's open deleted A's files")
    }

    @Test("the flags table is one of the tables erase empties")
    func flagsIsADataTable() async throws {
        let database = try Store.LocalDatabase.inMemory()
        let tables = try await database.writer.read { try Store.LocalDatabase.dataTables($0) }
        #expect(tables.contains("flags"))
        #expect(!tables.contains("meta"))
    }

    @Test("v4 is additive: a v3 store with rows migrates and keeps every row")
    func v4IsAdditive() throws {
        let queue = try DatabaseQueue()
        try Store.Migrations.all.migrate(queue, upTo: "v3")
        try queue.write { db in
            try db.execute(sql: """
            INSERT INTO entries (local_id, kind, text, created_at, day, sync_state, origin, acknowledgement)
            VALUES ('e1', 'typed', 'invented', '2026-10-21T08:00:00.000Z', '2026-10-21', 'local', 'new', NULL)
            """)
            try db.execute(sql: """
            INSERT INTO outbox (id, operation, entity_id, payload, next_attempt_at, status, created_at)
            VALUES ('o1', 'createEntry', 'e1', x'7B7D', '2026-10-21T08:00:00.000Z', 'pending', '2026-10-21T08:00:00.000Z')
            """)
            try db.execute(sql: "INSERT INTO cached_documents (key, body, fetched_at) VALUES ('brief', x'7B7D', '2026-10-21T08:00:00.000Z')")
            try db.execute(sql: "INSERT INTO meta (key, value) VALUES ('owner_hash', 'abc')")
        }
        #expect(try queue.read { try $0.tableExists("flags") } == false)

        try Store.Migrations.all.migrate(queue)

        let counts: [Int?] = try queue.read { db in
            try ["entries", "outbox", "cached_documents", "flags"].map { try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \($0)") }
        }
        let owner: String? = try queue.read { try String.fetchOne($0, sql: "SELECT value FROM meta WHERE key = 'owner_hash'") }
        #expect(try queue.read { try $0.tableExists("flags") })
        #expect(counts == [1, 1, 1, 0], "every v3 row is kept; flags starts empty")
        #expect(owner == "abc")
    }

    @Test("the first-run flags (FR.b1) set and read apart from each other, and go with the rest on erase")
    func firstRunFlags() async throws {
        let database = try Store.LocalDatabase.inMemory(ownerUserID: "user-a")
        let flags = Store.PersonFlags(database: database)
        #expect(try await flags.isSet(.firstRunStarted) == false)
        #expect(try await flags.isSet(.firstRunDone) == false)

        try await flags.set(.firstRunStarted)

        #expect(try await flags.isSet(.firstRunStarted))
        #expect(try await flags.isSet(.firstRunDone) == false, "started is not done")
        #expect(Store.PersonFlags.Key.firstRunStarted.rawValue == "first_run_started")
        #expect(Store.PersonFlags.Key.firstRunDone.rawValue == "first_run_done")
        try database.erase()
        #expect(try await flags.isSet(.firstRunStarted) == false)
    }

    @Test("a closed flags object reads as unknown and writes nothing")
    func aClosedObjectWritesNothing() async throws {
        let database = try Store.LocalDatabase.inMemory()
        let flags = Store.PersonFlags(database: database)
        await flags.close()

        #expect(await flags.markYoureInSeen() == false)
        #expect(await flags.youreInSeen() == nil)
        #expect(try await database.writer.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM flags") } == 0)
    }
}

/// The flag through the environment: built with the person's stack, dropped
/// (closed) before the store is erased.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct PersonFlagsEnvironmentTests {
    private func count(_ database: Store.LocalDatabase) async throws -> Int {
        try await database.writer.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM flags") } ?? -1
    }

    @Test("with no store open the flag is unknown and begin writes nothing, without crashing")
    func noStoreIsUnknown() async {
        let environment = Platform.AppEnvironment.preview()
        #expect(await environment.youreInSeen() == nil)
        #expect(await environment.markYoureInSeen() == false)
    }

    @Test("signed in, begin marks it for that person; Log Out erases it; signing in again starts unseen")
    func theFlagFollowsTheStack() async throws {
        let database = try Store.LocalDatabase.inMemory(ownerUserID: "user-a")
        let environment = Platform.AppEnvironment.preview(openDatabase: { _ in database })
        await environment.sessionDidChange(to: "user-a").value
        #expect(await environment.youreInSeen() == false)

        #expect(await environment.markYoureInSeen())
        #expect(await environment.youreInSeen() == true)

        await environment.sessionWillChange().value
        #expect(environment.personFlags == nil)
        #expect(await environment.youreInSeen() == nil)
        #expect(try await count(database) == 0, "erased with the store")

        await environment.sessionDidChange(to: "user-a").value
        #expect(await environment.youreInSeen() == false)
    }

    /// Waits until the flag is known (a store is open) or unknown (none is), as `open` asks.
    private func settle(_ environment: Platform.AppEnvironment, open: Bool) async throws {
        var tries = 0
        while await (environment.youreInSeen() != nil) != open, tries < 200 {
            tries += 1
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test("a session the server ended keeps the flag for the same person; Log Out then erases it")
    func aServerEndedSessionKeepsIt() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("flags-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let environment = Platform.AppEnvironment.preview(openDatabase: { try Store.LocalDatabase.onDisk(ownerUserID: $0, directory: directory) })
        let (states, feed) = AsyncStream<Session.State>.makeStream()
        environment.follow(states)

        feed.yield(.signedIn(userID: "user-a", access: .approved))
        try await settle(environment, open: true)
        #expect(await environment.markYoureInSeen())

        feed.yield(.signedOut(hasSignedInBefore: true, reason: .revoked))
        try await settle(environment, open: false)
        #expect(await environment.youreInSeen() == nil, "the stack closed")

        feed.yield(.signedIn(userID: "user-a", access: .approved))
        try await settle(environment, open: true)
        #expect(await environment.youreInSeen() == true, "the store was kept, and the flag with it")

        _ = await environment.logOut(confirmed: true)
        feed.yield(.signedIn(userID: "user-a", access: .approved))
        try await settle(environment, open: true)
        #expect(await environment.youreInSeen() == false, "Log Out erased it")
    }

    @Test("a begin that comes after the stack closed writes nothing to the erased store")
    func aLateBeginWritesNothing() async throws {
        let database = try Store.LocalDatabase.inMemory(ownerUserID: "user-a")
        let environment = Platform.AppEnvironment.preview(openDatabase: { _ in database })
        await environment.sessionDidChange(to: "user-a").value
        let held = try #require(environment.personFlags)

        await environment.sessionWillChange().value

        #expect(await held.markYoureInSeen() == false)
        #expect(await environment.markYoureInSeen() == false)
        #expect(try await count(database) == 0)
    }
}
