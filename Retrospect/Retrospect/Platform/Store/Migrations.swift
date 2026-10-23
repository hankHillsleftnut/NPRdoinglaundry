import GRDB

extension Store {
    /// The schema's history. A migration is never edited once merged; a change
    /// is a new one (`v2`, `v3`…).
    enum Migrations {
        static var all: DatabaseMigrator {
            var migrator = DatabaseMigrator()
            migrator.registerMigration("v1", migrate: v1)
            migrator.registerMigration("v2", migrate: v2)
            migrator.registerMigration("v3", migrate: v3)
            migrator.registerMigration("v4", migrate: v4)
            return migrator
        }

        private static func v1(_ db: GRDB.Database) throws {
            try db.create(table: "meta") { table in
                table.primaryKey("key", .text)
                table.column("value", .text)
            }
            try db.create(table: "entries") { table in
                table.primaryKey("local_id", .text)
                table.column("server_id", .text).unique()
                table.column("kind", .text).notNull()
                table.column("text", .text).notNull()
                table.column("created_at", .text).notNull()
                table.column("day", .text).notNull()
                table.column("media_path", .text)
                table.column("sync_state", .text).notNull()
                table.column("failure_code", .text)
                table.column("attempts", .integer).notNull().defaults(to: 0)
                table.column("reading", .text)
                table.column("origin", .text).notNull()
            }
            try db.create(index: "entries_day_created", on: "entries", columns: ["day", "created_at"])
            try db.create(index: "entries_sync_state", on: "entries", columns: ["sync_state"])
            try db.create(table: "outbox") { table in
                table.primaryKey("id", .text)
                table.column("operation", .text).notNull()
                table.column("entity_id", .text).notNull()
                table.column("payload", .blob).notNull()
                table.column("attempts", .integer).notNull().defaults(to: 0)
                table.column("next_attempt_at", .text).notNull()
                table.column("status", .text).notNull()
                table.column("last_error_code", .text)
                table.column("created_at", .text).notNull()
            }
            try db.create(index: "outbox_status_next", on: "outbox", columns: ["status", "next_attempt_at"])
            try db.create(index: "outbox_entity", on: "outbox", columns: ["entity_id"])
            try db.create(table: "cached_documents") { table in
                table.primaryKey("key", .text)
                table.column("body", .blob).notNull()
                table.column("fetched_at", .text).notNull()
                table.column("etag", .text)
            }
        }

        /// DG.3: the diagnostics rings. One table, four rings told apart by
        /// `ring`; `payload` is the record in the report's own JSON shape.
        private static func v2(_ db: GRDB.Database) throws {
            try db.create(table: "diagnostics") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("ring", .text).notNull()
                table.column("at", .text).notNull()
                table.column("payload", .blob).notNull()
            }
            try db.create(index: "diagnostics_ring", on: "diagnostics", columns: ["ring"])
        }

        /// PL2.2b (PL3.1 F2): the acknowledgement line shown under an entry,
        /// chosen once when it's first sent and never changed.
        private static func v3(_ db: GRDB.Database) throws {
            try db.alter(table: "entries") { table in
                table.add(column: "acknowledgement", .text)
            }
        }

        /// INVITE-FLAGS (decisions 4, 5): small facts about this person on this
        /// phone ("you're in" seen; later a brief's "played"). A data table, so
        /// `erase()` empties it with everything else; never in `meta`.
        private static func v4(_ db: GRDB.Database) throws {
            try db.create(table: "flags") { table in
                table.primaryKey("key", .text)
                table.column("value", .text).notNull()
                table.column("set_at", .text).notNull()
            }
        }
    }
}
