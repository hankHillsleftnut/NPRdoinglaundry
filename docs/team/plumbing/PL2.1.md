### PL2.1 · The local database: schema v1 (entries, outbox, cached reads)   size: M
Place in the tree: product › platform › local store › Store.LocalDatabase
Repo · branch: NPRdoinglaundry · pl/PL2.1-schema-v1
Needs: PL2.0      Unblocks: PL2.2, PL2.4, PL2.6

Why: the phone keeps its own copy of what you send and what Retro has shown you, so the journal opens instantly and works on a train.

Inputs:
- Contract 02 §2, §5 (Entry fields, `clientEntryId`, kinds), §3 (Brief).
- Reference: app-reference.md §5.1 (the old `Entry`: `id: UUID`, `type: text | voice | video`, absolute media URLs), §5.3 (`Documents/RetrospectData/…`).

Spec:
- `Platform/Store/LocalDatabase.swift`:
  ```swift
  extension Store {
      final class LocalDatabase: Sendable {
          static func onDisk(ownerUserID: String) throws -> LocalDatabase   // Application Support/Platform/store.sqlite
          static func inMemory() throws -> LocalDatabase                      // tests and previews
          let writer: any DatabaseWriter                                      // a DatabasePool on disk
          func erase() throws                                                 // sign-out (PL1.5)
      }
  }
  ```
- **Where:** `Application Support/Platform/store.sqlite` (+ `-wal`, `-shm`). The folder is created with `FileProtectionType.completeUntilFirstUserAuthentication` (a background drain after first unlock must be able to write, the same reasoning as the Keychain class in PL1.3). Included in device backup by default; `isExcludedFromBackup` is one flag if the founder decides otherwise (question in the plan).
- **Ownership:** a `meta` table holds `owner_hash` (SHA-256 of the user id, never the raw id). Opening with a different owner erases the file first: one person's cache never shows to the next person on a shared phone (testing.md §2 isolation).
- **Migration `v1`** (`DatabaseMigrator`, registered in `Store.Migrations.all`, never edited once merged; changes are `v2`, `v3`…):
  | table | columns |
  |---|---|
  | `meta` | `key TEXT PK`, `value TEXT` (`owner_hash`, `schema_note`) |
  | `entries` | `local_id TEXT PK` (UUID; for new entries, the same id as `clientEntryId` and the outbox key), `server_id TEXT UNIQUE NULL`, `kind TEXT` (`typed`, `voice`, `conversation`, `imported`, `unknown`), `text TEXT NOT NULL`, `created_at TEXT` (ISO, ms), `day TEXT` (YYYY-MM-DD, local), `media_path TEXT NULL` (relative to the app container, never absolute), `sync_state TEXT` (`local`, `sending`, `sent`, `failed`, `legacy`), `failure_code TEXT NULL` (a `Backend.Failure` code, never a message), `attempts INT DEFAULT 0`, `reading TEXT NULL` (`waiting`, `reading`, `read`, `failed`), `origin TEXT` (`new`, `server`, `migrated`) |
  | `outbox` | `id TEXT PK` (the idempotency key), `operation TEXT` (`entry.create`; later `entry.edit`, `entry.delete`, `guess.answer`…), `entity_id TEXT`, `payload BLOB` (the encoded request body), `attempts INT`, `next_attempt_at TEXT`, `status TEXT` (`pending`, `inFlight`, `done`, `dead`), `last_error_code TEXT NULL`, `created_at TEXT` |
  | `cached_documents` | `key TEXT PK` (`brief.latest`, `guesses`, `entries.today.<day>`…), `body BLOB` (the contract JSON as received), `fetched_at TEXT`, `etag TEXT NULL` |
  Indexes: `entries(day, created_at)`, `entries(sync_state)`, `outbox(status, next_attempt_at)`, `outbox(entity_id)`.
- **Records:** `Store.EntryRow`, `Store.OutboxRow`, `Store.CachedDocument` (`Codable, FetchableRecord, PersistableRecord, Sendable`), all fields typed with enums that decode an unknown raw value into `.unknown` (contracts rule 5).
- **Concurrency:** `LocalDatabase` is `Sendable` (GRDB writers are thread-safe); repositories and the outbox are actors that use it. No view touches it directly: views observe through repositories (`ValueObservation` → `AsyncStream`).

Steps: migrator → records → owner check → erase → tests.

Acceptance: the v1 schema creates on a fresh install; a second open with the same owner keeps data; a different owner erases it.

Tests (layer 5, in-memory and a temp-file database): "v1 creates every table and index" (reads `sqlite_master`); "an entry row round-trips with every sync state"; "an unknown kind decodes as unknown"; "entries for one day come back oldest first"; "opening with another owner erases the previous owner's rows"; "erase leaves an empty v1 database"; "media paths are stored relative" (an absolute path is rejected by the record's validation); "the database folder has completeUntilFirstUserAuthentication" (temp-file test reads the attribute).

Proof in the PR: test output; the schema dump (`.schema`) in the PR body.

Watch out: never store message text in `failure_code` or `last_error_code`. The `legacy` sync state is only for PL2.6's migrated rows, which are never sent.
