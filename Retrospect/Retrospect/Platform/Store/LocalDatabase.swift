import CryptoKit
import Foundation
import GRDB

extension Store {
    /// The phone's own copy of what you send and what Retro has shown you.
    /// Thread-safe (GRDB's writers are); the outbox and repositories use it,
    /// views never touch it.
    final class LocalDatabase: Sendable {
        /// Where the database lives on disk: `Application Support/Platform/store.sqlite`.
        static var defaultDirectory: URL {
            URL.applicationSupportDirectory.appendingPathComponent("Platform", isDirectory: true)
        }

        /// The database's files: the database and its `-wal` and `-shm`.
        static let fileNames = ["store.sqlite", "store.sqlite-wal", "store.sqlite-shm"]

        let writer: any DatabaseWriter

        private init(writer: any DatabaseWriter) {
            self.writer = writer
        }

        /// The database for `ownerUserID`, in `directory`. If it belongs to
        /// someone else, its files are deleted and it starts empty: one person's
        /// cache never shows to the next person on a shared phone, not even in
        /// the file's free pages or its write-ahead log.
        ///
        /// The folder is protected `completeUntilFirstUserAuthentication`, so a
        /// background drain can write once the phone has been unlocked since it
        /// started.
        static func onDisk(ownerUserID: String, directory: URL = defaultDirectory) throws -> LocalDatabase {
            let protection = [FileAttributeKey.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: protection)
            try FileManager.default.setAttributes(protection, ofItemAtPath: directory.path)
            let owner = ownerHash(ownerUserID)
            var pool = try openPool(in: directory)
            if let current = try storedOwner(pool), current != owner {
                try pool.close()
                for name in fileNames {
                    let file = directory.appendingPathComponent(name)
                    if FileManager.default.fileExists(atPath: file.path) {
                        try FileManager.default.removeItem(at: file)
                    }
                }
                pool = try openPool(in: directory)
            }
            try setOwner(owner, pool)
            return LocalDatabase(writer: pool)
        }

        /// A database in memory, for tests and previews.
        static func inMemory(ownerUserID: String = "preview") throws -> LocalDatabase {
            let queue = try DatabaseQueue(configuration: configuration)
            try Migrations.all.migrate(queue)
            try setOwner(ownerHash(ownerUserID), queue)
            return LocalDatabase(writer: queue)
        }

        /// Sign-out: every row of every table goes, the empty schema and the
        /// owner stay. Deletes overwrite the freed space (`secure_delete`), the
        /// file is rebuilt (`VACUUM`) and the write-ahead log is emptied, so no
        /// earlier text is left anywhere in the files.
        func erase() throws {
            try writer.write { db in
                for table in try Self.dataTables(db) {
                    try db.execute(sql: "DELETE FROM \(table.quotedDatabaseIdentifier)")
                }
            }
            try writer.vacuum()
            try writer.writeWithoutTransaction { try $0.checkpoint(.truncate) }
        }

        /// Every table that holds data: all of them except `meta` and the
        /// bookkeeping of SQLite and GRDB. Read from the schema, so a table a
        /// later migration adds is erased too.
        static func dataTables(_ db: GRDB.Database) throws -> [String] {
            try String.fetchAll(db, sql: """
            SELECT name FROM sqlite_master
            WHERE type = 'table' AND name <> 'meta' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'grdb_%'
            ORDER BY name
            """)
        }

        private static var configuration: Configuration {
            var configuration = Configuration()
            configuration.busyMode = .timeout(5)
            configuration.prepareDatabase { try $0.execute(sql: "PRAGMA secure_delete = ON") }
            return configuration
        }

        private static func openPool(in directory: URL) throws -> DatabasePool {
            let pool = try DatabasePool(path: directory.appendingPathComponent(fileNames[0]).path, configuration: configuration)
            try Migrations.all.migrate(pool)
            return pool
        }

        private static func storedOwner(_ writer: any DatabaseWriter) throws -> String? {
            try writer.read { try String.fetchOne($0, sql: "SELECT value FROM meta WHERE key = ?", arguments: [MetaKey.ownerHash]) }
        }

        private static func setOwner(_ owner: String, _ writer: any DatabaseWriter) throws {
            try writer.write { db in
                try db.execute(sql: "INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)", arguments: [MetaKey.ownerHash, owner])
            }
        }

        /// SHA-256 of the user id, hex. The raw id is never stored.
        static func ownerHash(_ userID: String) -> String {
            SHA256.hash(data: Data(userID.utf8)).map { String(format: "%02x", $0) }.joined()
        }
    }

    enum MetaKey {
        static let ownerHash = "owner_hash"
    }
}
