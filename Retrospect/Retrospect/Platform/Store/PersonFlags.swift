import Foundation
import GRDB

extension Store {
    /// What the invite screens ask about "you're in" (contract 01 §3: approved
    /// and not yet seen on this phone shows the moment; "begin" marks it seen).
    /// `AppEnvironment` and `PersonFlags` implement it; screens fake it.
    protocol YoureInSeenStoring: AnyObject {
        /// True once this person tapped "begin" on this phone; nil while it
        /// isn't known (no store open yet, or the store couldn't be read). The
        /// root waits on nil: it must not show the moment again, nor the journal.
        func youreInSeen() async -> Bool?
        /// "begin": marks it seen for this person. False when nothing was
        /// written (no store open, the stack closed, or the write failed).
        @discardableResult
        func markYoureInSeen() async -> Bool
    }

    /// Small per-person facts kept in the person's own database (`flags`, v4):
    /// erased with it on Log Out, deleted with its files when someone else
    /// signs in, kept when the server ends the session (DECISION 23 Oct). Never
    /// sent, never logged with a value. Keys are a closed list: no free strings.
    actor PersonFlags: YoureInSeenStoring {
        enum Key: String, CaseIterable, Sendable {
            case youreInSeen = "youre_in_seen"
            /// FR.b1: "begin" also starts the first run; the root routes on it (FR.b1.root), never on access alone.
            case firstRunStarted = "first_run_started"
            /// FR.b1: the first run ended on this phone; the root never shows it again.
            case firstRunDone = "first_run_done"
        }

        private let database: LocalDatabase
        private let now: @Sendable () -> Date
        /// Set by the close path before the store is erased or handed on: from
        /// then on nothing is read or written, so a late "begin" can't land in
        /// an erased store.
        private var closed = false

        init(database: LocalDatabase, now: @escaping @Sendable () -> Date = Date.init) {
            self.database = database
            self.now = now
        }

        /// Whether `key` is set. Throws when the store can't be read or is closed.
        func isSet(_ key: Key) throws -> Bool {
            guard !closed else { throw Closed() }
            return try database.writer.read { db in
                try Bool.fetchOne(db, sql: "SELECT 1 FROM flags WHERE key = ?", arguments: [key.rawValue]) ?? false
            }
        }

        /// Sets `key`; setting it again keeps the first time it was set.
        func set(_ key: Key) throws {
            guard !closed else { throw Closed() }
            let stamp = Backend.Coding.timestamp(now())
            try database.writer.write { db in
                try db.execute(
                    sql: "INSERT OR IGNORE INTO flags (key, value, set_at) VALUES (?, '1', ?)",
                    arguments: [key.rawValue, stamp]
                )
            }
        }

        /// The person's stack is closing: nothing more is read or written.
        func close() {
            closed = true
        }

        func youreInSeen() -> Bool? {
            try? isSet(.youreInSeen)
        }

        /// Where the first run stands on this phone (FR.b1.root): `started` by "begin", `done` on leaving it. The
        /// root routes on these two, never on access alone, so an existing member never sees the first run.
        struct FirstRun: Equatable, Sendable {
            var started: Bool
            var done: Bool
        }

        /// Both first-run flags, or nil while they can't be known (closed, or the store couldn't be read).
        func firstRun() -> FirstRun? {
            guard let started = try? isSet(.firstRunStarted), let done = try? isSet(.firstRunDone) else { return nil }
            return FirstRun(started: started, done: done)
        }

        /// "begin" also starts the first run. False when nothing was written.
        @discardableResult
        func markFirstRunStarted() -> Bool {
            (try? set(.firstRunStarted)) != nil
        }

        /// The first run ended on this phone: the root shows the journal from now on. False when nothing was written.
        @discardableResult
        func markFirstRunDone() -> Bool {
            (try? set(.firstRunDone)) != nil
        }

        @discardableResult
        func markYoureInSeen() -> Bool {
            (try? set(.youreInSeen)) != nil
        }

        struct Closed: Error {}
    }
}

/// The screens' door to the flag: the signed-in person's `PersonFlags`, or
/// "not known" and no write while no store is open. The flags object is read
/// once per call, so a call that spans an account change talks to the old,
/// closed object (nil / false), never to the next person's store.
extension Platform.AppEnvironment: Store.YoureInSeenStoring {
    func youreInSeen() async -> Bool? {
        guard let flags = personFlags else { return nil }
        return await flags.youreInSeen()
    }

    @discardableResult
    func markYoureInSeen() async -> Bool {
        guard let flags = personFlags else { return false }
        return await flags.markYoureInSeen()
    }
}
