# Polish list

Nits and "close but not exact" items deferred under prototype mode (`prototype-mode.md`). Batched before the App Store. Add one line per item: PR, component, what, and where it came from.

| PR | Part | What | Source |
|---|---|---|---|
| #99 | DG.1 door | "retries absent means 0" is schema-only; nothing normalises it server-side (the viewer treats missing as 0). A bad Idempotency-Key is refused before taking the write-limit token. | fresh review, 22 Oct |
| #112 | DG.2 viewer | No date filter or pagination past 500 (the flow doc says "by date"). A failed load leaves the stale secret in sessionStorage, and any failure says "that secret did not work". A non-string `userId` query means "no filter" instead of 400. | fresh review, 22 Oct |
| #109 | Apple sign-in | givenName isn't trimmed, so "  " is stored as a name. | fresh review, 22 Oct |
| #87 | RRetroLine | rRetroAnnouncement only fires if the line is present when the id changes; if live data publishes .sent a render before the acknowledgement, the announcement is skipped. Watch the pair (P09/PL3.1). | fresh review, 22 Oct |
| #119 | Outbox | A repeat enqueue of the same id throws GRDB's raw unique-violation error; a typed `AlreadyQueued` would be clearer. `EntryKind(rawValue:) ?? .unknown` should be a switch so a new `CreateEntry.Kind` case is a compile error. `unsentCountCountsTheUnsent` makes four `UUID()`s; fixed ids read better. | integrator review, 22 Oct |
| #118 | invites | `linkFor` swallows a failed `openCode` silently: after a real key rotation every link goes null with no log line; the over-limit link page emits no door log line either, so a misconfigured proxy (all traffic one address) would silently turn every preview neutral. The bucket is taken for malformed codes too. | fresh review, 22 Oct |
| #119 | outbox | Repeat enqueue throws a raw `DatabaseError`; the compose screen needs a typed `AlreadyQueued` or a no-op. `EntryKind(rawValue:) ?? .unknown` should be a switch so a new `CreateEntry.Kind` case fails to compile. The actor blocks a cooperative-pool thread during each SQLite write (fine for single enqueues; revisit when the drainer does many). | fresh review, 22 Oct |

