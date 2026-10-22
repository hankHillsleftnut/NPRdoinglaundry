# Polish list

Nits and "close but not exact" items deferred under prototype mode (`prototype-mode.md`). Batched before the App Store. Add one line per item: PR, component, what, and where it came from.

| PR | Part | What | Source |
|---|---|---|---|
| #99 | DG.1 door | "retries absent means 0" is schema-only; nothing normalises it server-side (the viewer treats missing as 0). A bad Idempotency-Key is refused before taking the write-limit token. | fresh review, 22 Oct |
| #112 | DG.2 viewer | No date filter or pagination past 500 (the flow doc says "by date"). A failed load leaves the stale secret in sessionStorage, and any failure says "that secret did not work". A non-string `userId` query means "no filter" instead of 400. | fresh review, 22 Oct |
| #109 | Apple sign-in | givenName isn't trimmed, so "  " is stored as a name. | fresh review, 22 Oct |
| #87 | RRetroLine | rRetroAnnouncement only fires if the line is present when the id changes; if live data publishes .sent a render before the acknowledgement, the announcement is skipped. Watch the pair (P09/PL3.1). | fresh review, 22 Oct |
| #131 | Diagnostics recorder | Event kinds and `Permission` are checked against a literal copied from schema.ts, not a fixture: add `events` and `permissions` lists to `fixtures/00/diagnostics.ids.json` in a later contract PR. `deleteOlder` scans `at` unindexed (≤ 4,600 rows). The JSON encoder is built per record. | integrator review, 22 Oct |
| #119 | Outbox | A repeat enqueue of the same id throws GRDB's raw unique-violation error; a typed `AlreadyQueued` would be clearer. `EntryKind(rawValue:) ?? .unknown` should be a switch so a new `CreateEntry.Kind` case is a compile error. `unsentCountCountsTheUnsent` makes four `UUID()`s; fixed ids read better. | integrator review, 22 Oct |
| #118 | invites | `linkFor` swallows a failed `openCode` silently: after a real key rotation every link goes null with no log line; the over-limit link page emits no door log line either, so a misconfigured proxy (all traffic one address) would silently turn every preview neutral. The bucket is taken for malformed codes too. | fresh review, 22 Oct |
| #119 | outbox | Repeat enqueue throws a raw `DatabaseError`; the compose screen needs a typed `AlreadyQueued` or a no-op. `EntryKind(rawValue:) ?? .unknown` should be a switch so a new `CreateEntry.Kind` case fails to compile. The actor blocks a cooperative-pool thread during each SQLite write (fine for single enqueues; revisit when the drainer does many). | fresh review, 22 Oct |

| #134/#142 | session | A redacting `CustomStringConvertible` on `Credentials`, `Nonce` and `AuthResponse`, so a stray `print` can't show a token. | combined review, 22 Oct |
| #142 | session | `AppleRevocationCheck.live`: race the 3 s timeout in an unstructured Task so a late Apple callback can never hold `becameActive` (the continuation now resumes once, but the callback still isn't cancellable). | combined review, 22 Oct |
| #142 | legacy mirror | `LegacyMirror.publish` hops to main per call; a write then a clear could land out of order. Serialise the hops. | combined review, 22 Oct |
| #142 | session | Remember a `rate_limited` on refresh and wait `retryAfterSeconds` before the next proactive refresh instead of trying again on the next request. | combined review, 22 Oct |
| #142 | install check | A launch check that fails every time (not locked) reads as `.locked` forever; cap the retries or surface a state the gate can show. | combined review, 22 Oct |
| #143 | invites | Keychain read failures in `InviteCenter` are logged as `keychainWriteFailed`; give reads their own event. | combined review, 22 Oct |
| #143 | invites | `Ticket.none` conflates "no code" and "already in" (PI1 wants a toast for the second); split the case. | combined review, 22 Oct |
| #143 | invites | A waiting ticket is checked again only on `.active`, not on reachability (PL1.8 wires both). | combined review, 22 Oct |
| #143 | invites | `type(code:)` bypasses `afterSignIn`'s single flight, and a code typed while signed out isn't kept for after sign-in. | combined review, 22 Oct |

| #147 | outbox drainer | A 426 (app too old) marks queued items dead; pausing them would send them on their own after the update. A 2xx that fails to decode is also dead (the server did write it; a retry with the same key returns the same entry). Both leave the entry recoverable by "tap to retry", nothing is lost. | integrator read, 22 Oct |
| #143 | invites | A spent code can read as unspent after its redeemer's account is deleted (007 `ON DELETE SET NULL`): belongs with delete-my-account. The pending code outlives sign-out by contract (the link follows the phone). | CodeRabbit, 22 Oct |
| #144 | version floor | `Ticket.none` conflates "no code" and "already in"; the waiting ticket retries on an active scene, not on reachability. | combined review, 22 Oct |
\n
