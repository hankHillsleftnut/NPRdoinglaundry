### PL3.1 · LiveJournalData: the journal on real data                        size: L (split: PL3.1a send and today, PL3.1b brief and audio, PL3.1c guesses, PL3.1d entries, search and edit, PL3.1e what Retro took and "not right")
Place in the tree: product › journal (JR-1 → JR-4) › live data › LiveJournalData
Repo · branch: NPRdoinglaundry · pl/PL3.1a-journal-send … pl/PL3.1e-journal-took
Needs: PL2.2, PL2.4, PL1.5; `Platform/Flows/Journal.swift` (integrator); contract 02 and fixtures; backend BE1.1 (a), BE1.3 + BE1.3b (b), BE1.4 (c), BE1.5 + BE1.5b (d), BE1.6 + BE1.7 + BEA.1 (e)
Unblocks: the journal wiring PR (integrator), T04

Why: what you send lands in your bank, safely, and Retro says it got it; today's brief plays; you can find anything you wrote and tell Retro when it got something wrong.

Inputs:
- Contract 02 §1–§6, every fixture in `fixtures/02/`; contract 00 §2 (errors).
- The protocol: `Platform/Flows/Journal.swift` and the seam table in ui-engineer.md §4 (what the views call). If the protocol lacks something below, stop and ask the integrator; never add to it yourself.

Spec:
- `Platform/Flows/LiveJournalData.swift`: `@MainActor @Observable final class LiveJournalData: JournalData`, built by `Platform.Environment` from `Repositories.Journal` (an actor) and `Media.Source`. Every action is `async`, never throws to a view: outcomes land on state.
- **(a) Send and today:** `send(text:)` builds an `EntryDraft` (a new UUID), enqueues it (PL2.2) and appends it to `today` at once as `.waiting`; outbox state changes flow into each entry's state (`waiting`, `sending`, `sent`, `failed`). `sendVoice(_:)` does the same with the transcript and the recording's relative path. `retry(clientEntryId:)` calls `Outbox.retry`. `today` merges the cached server list (`CachedRead` key `entries.today.<day>`) with local rows not yet on the server, de-duplicated by `clientEntryId`, oldest first.
- **The acknowledgement:** `acknowledgement(for:)` returns a line only once that entry is `.sent`. `Journal.Acknowledgements` holds the founder's fixed set (copy pending; placeholder `"saved."` only in tests) and picks with an injected random source so the same line is never shown twice in a row; the chosen line is stored per entry, so scrolling back never changes it.
- **(b) Brief:** `brief: Loadable<BriefSlot>` from `GET /v2/briefs/latest` (`CachedRead` `brief.latest`): `enabled == false` → `.off`; `brief == null` and enabled → `.making(readyBy:)` (from the brief settings, when contract 06 has them; until then `.none`); `kind == quiet` → `.quiet(line)`; else `.ready(Brief)`. Audio goes through `Media.Source` (`Platform/Media/Source.swift`, an actor): hands the player a URL that's valid for at least the episode's length plus 5 minutes, refetches `brief.latest` when `expiresAt` is closer than that, and downloads to `Caches/Platform/audio/<briefId>.<ext>` for offline replay (purgeable; re-downloaded if missing). No audio → the player's `.failed` never shows; the brief reads as text.
- **(c) Guesses:** `guesses` from `GET /v2/guesses` (`CachedRead` `guesses`); `speaking == false` → `[]`. `answer(_:verdict:)` sends `POST /v2/guesses/:id` through the outbox (operation `guess.answer`, key = a UUID stored with the answer), updates the guess at once (optimistic) and returns `GuessOutcome`; a repeat answer returns the stored status.
- **(d) Entries:** `entries(cursor:query:)` → `GET /v2/entries` (no cache for search; history pages cached under `entries.page.<cursor or first>` for 5 min); `matches` ranges converted to `Range<String.Index>` safely (ranges past the text end are dropped and logged). `entry(id:)`, `edit(id:text:)` (outbox `entry.edit`, the entry shows "retro is reading it again"), `delete(id:)` (outbox `entry.delete`; removed locally at once, restored with a failure if the server refuses).
- **(e) What Retro took, "not right":** `took(id:)` → `GET /v2/entries/:id/took` (refetched while `reading` is `waiting` or `reading`, every 10 s while the screen is visible, stopping at `read`/`failed`). `correct(text:about:)` → `POST /v2/corrections` (not queued: the person waits for the answer; offline returns `.offline` so the sheet can say so), mapped to `.applied(echo)`, `.confirm(candidates)`, `.askOwnWords(quote, writtenOn)`, `.notACorrection`; `confirm(…)` → `POST /v2/corrections/confirm`. After `.applied`, `took` for affected entries is invalidated.
- `isOnline` mirrors `Backend.Reachability`.

Steps: per split, endpoints → repository → live object → fixture tests → behaviour tests.

Acceptance:
- Running the app with `-Data live -Environment local` (T02a), every journal state on the T02 list is reachable on real data, except those needing founder-only dials.
- Each split's behaviour matches the sample implementation's on the same scenario (the wiring PR's check).

Tests (layer 4: every `fixtures/02/*.json` decodes; layer 5):
- (a) "a sent entry appears at once as waiting, then sent"; "the acknowledgement appears only after sent, never the same twice in a row, and never changes for an entry"; "offline, the entry stays waiting and no acknowledgement shows"; "today merges server and local rows without duplicates".
- (b) "brief off, making, quiet, ready and none map from their fixtures"; "audio expiring within the episode length is refetched before playing"; "a missing cached audio file is downloaded again".
- (c) "speaking false shows no guesses"; "an answer updates at once and is sent once"; "a repeat answer returns the stored status".
- (d) "search ranges past the end are dropped"; "edit shows reading again"; "a refused delete restores the entry with its failure".
- (e) "took polls while waiting and stops at read"; one test per correction outcome fixture; "offline correction returns offline and sends nothing".
- "no log line or analytics event carries entry text, a correction or a brief" (scan the sink).

Proof in the PR: test output; a recording of the journal on local staging (integrator, test account) for each split.

Watch out: never call the model or stream (v1 has no conversation; PL3.2 is v2). The brief's v2 `items` are never shown (contract 02 §3). Corrections are blocked in production until BEA.1; build and test against fixtures, ship with the gate.
