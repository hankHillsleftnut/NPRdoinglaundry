# Polish list

Nits and "close but not exact" items deferred under prototype mode (`prototype-mode.md`). Batched before the App Store. Add one line per item: PR, component, what, and where it came from.

| PR | Part | What | Source |
|---|---|---|---|
| #99 | DG.1 door | "retries absent means 0" is schema-only; nothing normalises it server-side (the viewer treats missing as 0). A bad Idempotency-Key is refused before taking the write-limit token. | fresh review, 22 Oct |
| #112 | DG.2 viewer | No date filter or pagination past 500 (the flow doc says "by date"). A failed load leaves the stale secret in sessionStorage, and any failure says "that secret did not work". A non-string `userId` query means "no filter" instead of 400. | fresh review, 22 Oct |
| #109 | Apple sign-in | givenName isn't trimmed, so "  " is stored as a name. | fresh review, 22 Oct |
| #87 | RRetroLine | rRetroAnnouncement only fires if the line is present when the id changes; if live data publishes .sent a render before the acknowledgement, the announcement is skipped. Watch the pair (P09/PL3.1). | fresh review, 22 Oct |
