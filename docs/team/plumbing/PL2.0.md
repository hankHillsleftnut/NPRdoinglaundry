### PL2.0 · GRDB in the app, proven by a spike                               size: M (spike, thrown away) + S (the package, kept)
Place in the tree: product › platform › local store › the database engine
Repo · branch: NPRdoinglaundry · pl/PL2.0-grdb (the package and the measurements; the spike code stays out of the PR)
Needs: PL0.3, PL0.4      Unblocks: PL2.1 and everything local-first

Why: everything you write on the phone must survive a crash, a dead battery or a lost signal. That needs a database with real transactions and testable migrations. SwiftData on iOS 18 doesn't give us that reliably (decision D5).

Inputs:
- README §9 D5 (GRDB over SwiftData, the reasons).
- Reference: app-reference.md §13 (packages, `.gitignore`), §12.3 (build settings: Swift 5 mode, iOS 18.1).
- GRDB 7's own docs: `DatabasePool`, `DatabaseMigrator` (including `eraseDatabaseOnSchemaChange` for DEBUG only), `ValueObservation`, `Configuration.prepareDatabase`.

Spec:
- **The package:** `https://github.com/groue/GRDB.swift`, product `GRDB`, rule `exactVersion` at the newest 7.x release tagged at least two weeks ago, added as exact-text `project.pbxproj` edits, then `xcodebuild -resolvePackageDependencies` (there is no Xcode GUI here; integrator, 22 Oct), linked to the app target only. `Package.resolved` updated in the same PR (PL0.4 made it tracked). Static linking is fine; no `GRDB-dynamic`.
- **The spike** (on a throwaway branch, measured, then deleted; only its numbers go in the PR body):
  1. A `DatabasePool` in a temp folder with WAL, `foreign_keys = ON`, and `busyTimeout` 5 s; an in-memory `DatabaseQueue` for tests.
  2. A `v1` migration with two tables, a `v2` migration adding a column and an index; open a v1 file with the v2 migrator.
  3. Insert 10,000 rows in one transaction, then 1,000 single-row transactions; read a day's rows by an indexed column.
  4. A `ValueObservation` driving a SwiftUI list while a detached task writes 100 rows per second for 10 s.
  5. Open the database with file protection `completeUntilFirstUserAuthentication`, lock the simulator, write from a background task (`xcrun simctl` can't lock; use a device or skip with a note, never fake it).
- **Measured and recorded in the PR body:** cold open time, 10k insert, 1k transactions, day read, observation latency (write → view), memory high-water, app binary size change. Run on the assigned simulator, Release configuration.
- **Stop rule:** if any of the five fails or the binary grows more than 3 MB, stop and report to the integrator; don't fall back to SwiftData or anything else silently.

Steps: package via Xcode → `Package.resolved` → spike on a side branch → measurements → PR with package only.

Acceptance:
- The app builds with GRDB linked; a clean clone resolves the same version twice.
- The PR body has all seven measurements and the pinned version.

Tests (layer 5): "GRDB opens an in-memory database in the test host" (one smoke test, kept: proves the package links into tests).

Proof in the PR: measurements table; `Package.resolved` diff; build output.

Watch out: GRDB's `Database` and `Record` names don't collide with ours only because ours are namespaced (`Store.LocalDatabase`); never add a bare `Database` or `Row` type to the module. Never call `eraseDatabaseOnSchemaChange` outside `#if DEBUG`.
