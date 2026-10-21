### PL2.2 · The outbox: write locally, send exactly once                      size: L (split: PL2.2a the queue and transaction, PL2.2b the drainer and its triggers)
Place in the tree: product › platform › local store › Store.Outbox
Repo · branch: NPRdoinglaundry · pl/PL2.2a-outbox-queue, pl/PL2.2b-outbox-drain
Needs: PL2.1, PL1.2, PL1.5, backend BE1.1 (honours `Idempotency-Key` on `/v2/entries`)      Unblocks: PL2.3, PL3.1, AC-2

Why: nothing you send is ever lost or duplicated, whatever the signal, the battery or the app's state when you tap send.

Inputs:
- Contract 00 §1 (`Idempotency-Key`, `idempotency_mismatch`), contract 02 §2 (`POST /v2/entries`, repeat key → same entry).
- Reference: app-reference.md §5.2 (today's fire-and-forget Task), §1.7 (scenePhase at `RetrospectApp.swift:353-372`), §11.2 (BG ids), §12.1 (`BGTaskSchedulerPermittedIdentifiers`).

Spec:
- `Platform/Store/Outbox.swift`:
  ```swift
  extension Store {
      actor Outbox {
          init(database: LocalDatabase, client: Backend.Client, reachability: any Backend.Reachability, clock: any Clock<Duration>, log: any Platform.LogSink)
          func enqueueEntry(_ draft: EntryDraft) async throws -> UUID   // one transaction: entries row (sync_state local) + outbox row; returns local id
          func drain(reason: DrainReason) async                          // safe to call any time; at most one drain runs
          func retry(entityID: UUID) async throws                        // a dead item back to pending, attempts reset
          func unsentCount() async throws -> Int                         // pending + inFlight + dead
          func states() -> AsyncStream<[UUID: EntrySyncState]>
          enum DrainReason: String, Sendable { case launch, foreground, reachability, afterWrite, backgroundTask, manual }
      }
      struct EntryDraft: Sendable { let id: UUID; let kind: EntryKind; let text: String; let createdAt: Date; let mediaPath: String? }
  }
  ```
- **One transaction:** the entry row and its outbox row are written in the same `writer.write { }`; if either fails, neither exists. The outbox id = the entry's `local_id` = `clientEntryId` = `Idempotency-Key`, for new entries only. Text is trimmed; empty text is rejected before the transaction (`EntryDraft` init returns nil).
- **The drainer:** one at a time (an `isDraining` flag plus a `needsAnotherPass` flag, so a trigger during a drain causes one more pass, never two drainers). Each pass: reset `inFlight` rows older than 2 minutes to `pending` (a crash mid-send); take `pending` rows whose `next_attempt_at <= now`, oldest first; for each, mark `inFlight` + entry `sending`, send with the stored key, then in one transaction mark `done` + entry `sent` + `server_id` + `reading` from the response. Items for the same entity go strictly in order; an entity with a failing earlier item blocks its later items, not other entities.
- **Failures:** `offline` → stop the pass, leave pending (no attempt counted). Retryable (`timedOut`, 408, 429 with its `retryAfter`, 5xx, `upstream*`) → `attempts += 1`, `next_attempt_at = now + fullJitter(base: 2 s, cap: 5 min, attempt)`. Permanent (other 4xx, `decoding`) → `dead`, entry `failed` with `failure_code`. `unauthenticated` → stop the pass (PL1.5 decides sign-in), not dead. `idempotencyMismatch` → `dead` and log `outboxMismatch` (a bug: same key, different body). No limit on attempts for retryable failures (an entry is never thrown away by time alone); the UI shows "waiting to send".
- **Triggers** (PL2.2b): launch (after the session is ready), `scenePhase == .active` (bridge: one line in `RetrospectApp.swift:353-372` → `Task { await platform.outbox?.drain(reason: .foreground) }`), reachability becoming `.online`, after every enqueue, and a `BGAppRefreshTask` with a new id `com.shauryanarang.Retrospect.outbox.drain` (bridge: added to `BGTaskSchedulerPermittedIdentifiers` in `Info.plist` and registered in `AppDelegate.didFinishLaunching` at `:15-23`; scheduled when the app backgrounds with unsent items; the handler sets `expirationHandler` to cancel the drain cleanly).
- **Sign-out:** `unsentCount()` feeds PL1.5's `.hasUnsent(count)`; a forced sign-out erases the database (PL2.1), so nothing is sent under the next person's session.
- **Logging:** `outboxEnqueued(operation:)`, `outboxSent(operation:attempts:ms:)`, `outboxRetry(operation:code:)`, `outboxDead(operation:code:)`: no text, no ids.

Steps (a): types → transaction → tests. (b): drainer → triggers → bridges → tests.

Acceptance:
- An entry written offline is sent exactly once when the network returns, with the same key on every attempt.
- Killing the app mid-send and relaunching sends it again with the same key, and the server keeps one entry.
- A permanently refused entry shows as failed with a reason, and can be retried.

Tests (layer 5, in-memory database, stub URL protocol, test clock):
- "enqueue writes the entry and the outbox row together, or neither" (inject a failing write).
- "an offline write is sent once when reachability returns".
- "every retry of an item carries the same Idempotency-Key".
- "an inFlight item left by a crash is resent with the same key after two minutes".
- "two triggers during a drain cause one extra pass, never two drainers" (count concurrent sends).
- "items for one entity are sent in order; a failed one doesn't block another entity".
- "a 400 makes the item dead and the entry failed with its code"; "a 503 is retried with jittered backoff capped at five minutes" (the test clock reads the delays); "429 waits for Retry-After".
- "unauthenticated stops the pass without killing the item".
- "retry moves a dead item back to pending".
- "unsentCount counts pending, inFlight and dead".
- "no outbox log line carries entry text" (scan the recording sink).

Proof in the PR: test output; the two bridge diffs (scenePhase, Info.plist + AppDelegate registration).

Watch out: `BGTaskScheduler.register` must run before `didFinishLaunching` returns, and only once; the test-host guard (PL0.1) skips it in tests. Never add `Idempotency-Key` to entries the old app sent (PR #35's reasoning): only rows with `origin = new` enter the outbox.
