### PL2.6 · Bring the old phone data into the store, once, provably          size: M
Place in the tree: product › platform › local store › Store.LegacyImport
Repo · branch: NPRdoinglaundry · pl/PL2.6-legacy-import
Needs: PL2.1, PL2.3      Unblocks: X06 (removing the old files), the journal drawer showing everything you ever wrote on this phone

Why: everything you've already written on this phone is still there after the update, in the new journal, and nothing is sent twice.

Inputs:
- Reference: app-reference.md §5.1 (old `Entry` fields; no custom `CodingKeys`), §5.3 (`Documents/RetrospectData/Entries/<UUID>.json`, ISO dates, media under `Audios/`, `Videos/`, `Images/`), §6 (`rich_goals` in UserDefaults, **default `JSONEncoder`: dates are Doubles since 2001**), §7 (`podcasts.json`: out of scope here; X06).

Spec:
- `Platform/Store/LegacyImport.swift`:
  ```swift
  extension Store {
      actor LegacyImport {
          init(database: LocalDatabase, documents: URL, defaults: UserDefaults, log: any Platform.LogSink)
          func run() async -> Report          // idempotent; safe on every launch
          struct Report: Sendable, Equatable { let imported: Int; let alreadyPresent: Int; let unreadable: Int; let confirmed: Bool }
      }
  }
  ```
- **Migration `v2`** adds `legacy_ledger (source TEXT, source_id TEXT, checksum TEXT, imported_at TEXT, confirmed_at TEXT NULL, PRIMARY KEY (source, source_id))` and `legacy_goals (local_id TEXT PK, server_id TEXT NULL, title TEXT, description TEXT, motivation TEXT, category TEXT, action_items BLOB, created_at TEXT)`.
- **Entries:** for each `Entries/*.json`, decode with a private `LegacyEntry` struct mirroring the old fields (never the old `Entry` type, so old-code changes can't break the import) and `.iso8601`. Insert into `entries` with `local_id` = the old UUID (so entries already taken by PL2.3's bridge are `alreadyPresent`), `origin = migrated`, `sync_state = legacy`, `kind` mapped as PL2.3, `media_path` re-resolved by id (`RetrospectData/Audios/<UUID>.m4a` if that file exists now; the stored absolute URL is ignored, because the container path changes across installs and restores), `day` from `created_at` in the current time zone. The checksum is SHA-256 of the file's bytes.
- **Goals:** decode `rich_goals` with a default `JSONDecoder` (Double dates) into `legacy_goals`; checksum of the stored `Data`. PL3.5 reconciles them with the server by `server_id`.
- **Two launches to confirm:** launch 1 imports and records checksums. Launch 2 re-reads every source, compares checksums, and sets `confirmed_at`; a changed source (the old app wrote it again) is re-imported and confirmed on the next launch. `Report.confirmed` is true only when every ledger row is confirmed. The old files are never modified or deleted here (X06 does that after the founder's go).
- **Never sent:** `legacy` rows never enter the outbox. Whether to send old entries that never reached the server is a founder question; until answered, nothing is sent.
- Runs off the main actor, after the session is ready, at most once per launch; a file that won't decode counts as `unreadable`, is logged `legacyUnreadable(source:)` and skipped (no content in the log), and never stops the rest.

Steps: v2 migration → entries → goals → confirm pass → tests.

Acceptance: after updating, the store has one row per old entry and goal; a second launch confirms them all; the old files are byte-identical.

Tests (layer 5, a fixture folder of invented entries in `RetrospectTests/Platform/Fixtures/Legacy/`):
- "every old entry is imported once with its old id".
- "running twice imports nothing new".
- "an entry already taken by the bridge counts as already present".
- "absolute media URLs from another container are re-resolved by id".
- "a missing media file leaves media_path empty, not broken".
- "rich_goals with 2001-based dates decode to the right dates".
- "an unreadable file is skipped and counted, and the rest import".
- "the second launch confirms every checksum"; "a changed source is re-imported, then confirmed".
- "the old files are unchanged after import" (hash the folder before and after).
- "no legacy row enters the outbox".

Proof in the PR: test output; the report from a simulator with a copy of the fixture folder.

Watch out: the old app keeps writing `Entries/*.json` until the journal ship gate; that's why the import is idempotent and confirmation re-checks. Never read `podcasts.json` here (ten writers; X06).
