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

        let writer: any DatabaseWriter

        private init(writer: any DatabaseWriter, ownerHash: String) throws {
            self.writer = writer
            try Migrations.all.migrate(writer)
            try writer.write { db in
                let current = try String.fetchOne(db, sql: "SELECT value FROM meta WHERE key = ?", arguments: [MetaKey.ownerHash])
                if let current, current != ownerHash {
                    try Self.eraseRows(db)
                }
                try db.execute(sql: "INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)", arguments: [MetaKey.ownerHash, ownerHash])
            }
        }

        /// The database for `ownerUserID`, in `directory`. If it holds someone
        /// else's rows, they're erased first: one person's cache never shows to
        /// the next person on a shared phone.
        ///
        /// The folder is protected `completeUntilFirstUserAuthentication`, so a
        /// background drain can write once the phone has been unlocked since it
        /// started.
        static func onDisk(ownerUserID: String, directory: URL = defaultDirectory) throws -> LocalDatabase {
            let protection = [FileAttributeKey.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: protection)
            try FileManager.default.setAttributes(protection, ofItemAtPath: directory.path)
            var configuration = Configuration()
            configuration.busyMode = .timeout(5)
            let pool = try DatabasePool(path: directory.appendingPathComponent("store.sqlite").path, configuration: configuration)
            return try LocalDatabase(writer: pool, ownerHash: ownerHash(ownerUserID))
        }

        /// A database in memory, for tests and previews.
        static func inMemory(ownerUserID: String = "preview") throws -> LocalDatabase {
            try LocalDatabase(writer: DatabaseQueue(), ownerHash: ownerHash(ownerUserID))
        }

        /// Sign-out: every row goes, the empty v1 schema and the owner stay.
        func erase() throws {
            try writer.write { try Self.eraseRows($0) }
        }

        /// SHA-256 of the user id, hex. The raw id is never stored.
        static func ownerHash(_ userID: String) -> String {
            SHA256.hash(data: Data(userID.utf8)).map { String(format: "%02x", $0) }.joined()
        }

        private static func eraseRows(_ db: GRDB.Database) throws {
            for table in ["entries", "outbox", "cached_documents"] {
                try db.execute(sql: "DELETE FROM \(table)")
            }
        }
    }

    enum MetaKey {
        static let ownerHash = "owner_hash"
    }
}
