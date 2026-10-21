### PL2.4 · Cached reads: show what you had, then what's new                 size: M
Place in the tree: product › platform › repositories › Repositories.CachedRead
Repo · branch: NPRdoinglaundry · pl/PL2.4-cached-reads
Needs: PL2.1, PL1.5      Unblocks: PL3.1 (brief, guesses, today), PL2.5, PL3.3–PL3.7

Why: the journal and the brief open instantly with what you saw last, even offline, and quietly update when fresh data arrives.

Inputs:
- Contract 02 §2 (`GET /v2/entries/today`), §3 (`GET /v2/briefs/latest`), §4 (`GET /v2/guesses`); contract 00 §2 (errors).
- The UI seam (ui-engineer.md §4): screens read `Loadable<T>`.

Spec:
- `Platform/Repositories/Loadable.swift` (the shared state type; the integrator's flow protocols use it, so it lands first or with `Platform/Flows/Journal.swift`, whichever is earlier, by agreement):
  ```swift
  enum Loadable<Value: Sendable>: Sendable {
      case loading                                             // nothing cached yet
      case loaded(Value, freshness: Freshness)                 // .fresh, or .cached(since: Date)
      case failed(Backend.Failure, cached: Value?)             // offline with a cache shows the cache and says so
  }
  ```
- `Platform/Repositories/CachedRead.swift`:
  ```swift
  extension Repositories {
      actor CachedRead<Value: Codable & Sendable> {
          init(key: String, maxAge: Duration, database: Store.LocalDatabase, fetch: @Sendable @escaping () async throws -> Value, clock: any Clock<Duration>)
          func stream() -> AsyncStream<Loadable<Value>>   // emits cached immediately (if any), then fresh or failed
          func refresh(force: Bool) async                  // stale-while-revalidate; one fetch in flight per key
          func invalidate() async
      }
  }
  ```
  Behaviour: on `stream()`, read `cached_documents[key]`; emit `.loaded(cached, .cached(since:))` at once if present, else `.loading`. If missing or older than `maxAge`, fetch (single-flight per key). Fresh → write the body + `fetched_at` in one transaction, emit `.loaded(value, .fresh)`. Failure → emit `.failed(failure, cached:)`. The stored body is the contract JSON, decoded on read, so a decoding change in a later app version re-reads old cache safely; a cache that no longer decodes is deleted and logged `cacheDropped(key:)`.
- **Keys and ages for the journal** (used by PL3.1): `entries.today.<YYYY-MM-DD>` 30 s; `brief.latest` 5 min; `guesses` 5 min. Today's key changes at local midnight (the day comes from `TimeZone.current`, the same zone sent in `X-Time-Zone`).
- Refresh triggers are the caller's (PL3.1 refreshes on appear and on `.active`); the repository never polls.

Steps: `Loadable` → `CachedRead` → tests.

Acceptance: opening a screen offline shows the cached value marked as cached; online, the fresh value replaces it without a flash of empty.

Tests (layer 5): "a cached value is emitted before the fetch completes"; "with no cache, loading comes first, then the value"; "a fresh value is stored and emitted"; "offline with a cache emits failed(offline, cached)"; "two streams on the same key cause one fetch"; "a cache that no longer decodes is dropped and refetched"; "today's key changes at local midnight in another time zone" (inject the zone and clock); one decode test per fixture: `entries.today.json`, `entries.today.empty.json`, `brief.latest.v1/v2/quiet/none.json`, `guesses.json`, `guesses.silent.json` (layer 4).

Proof in the PR: test output.

Watch out: never cache signed audio URLs as playable after `expiresAt`; the brief's `audio` object is cached but `Media.Source` (PL3.1) re-fetches when it has expired.
