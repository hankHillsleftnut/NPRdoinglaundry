### UI1.0 · SampleJournalData and the sample-data ledger               size: M
Place in the tree: journal › data seam › sample implementation
Repo · branch: NPRdoinglaundry · ui/UI1.0-sample-journal-data
Needs: `Platform/Flows/Journal.swift` (the integrator, from contract 02), T02        Unblocks: C30, C26, C28, C31, UI1.1, UI1.2, P09–P12, T04

Why: every journal screen can be built and tested in every state before the live data exists. When the live data arrives, nothing on screen has to change.

Inputs:
- Contract: [02-journal.md](../contracts/02-journal.md) §1–§6; fixtures `fixtures/02/*.json` (the integrator's)
- Platform: `Platform/Flows/Journal.swift` (the protocol and models); `Backend.Failure` (contract 00)
- Plan: ui-engineer.md §4 (the needs table)

Spec:
- **`SampleJournalData`** (`Features/Journal/Sample/SampleJournalData.swift`), `@MainActor @Observable`, conforms to `JournalData`, initialised with `(scenario: JournalScenario, clock: any Clock<Duration>)`.
- **Content** (`Features/Journal/Sample/SampleJournalContent.swift`): invented, lowercase and plausible, built from the contract fixtures where they exist (decoded from the same JSON files, so the shapes can't drift). It contains no names of real people; invented first names follow contracts rule 8.
- **Scenarios** (`JournalScenario`, also the T02 `-State` names):

| Scenario | What it gives |
|---|---|
| `full` | 6 entries today (typed, voice, imported), all sent and acknowledged; brief ready (v1 parts with a why); one guess offered; drawer with 3 days |
| `dayOne` | no entries; brief `.making(readyBy: 8:30)`; no guesses |
| `briefOff` | brief `.off` (no card at all) |
| `briefMaking` / `briefQuiet` / `briefPlayed` / `briefError` | the brief slot in that state |
| `sending` | the last entry `.sending` (never resolves) |
| `notSent` | the last entry `.failed(.network)`; `retry` succeeds after 1s of the injected clock |
| `offline` | `isOnline = false`; the last two entries `.waiting`; the brief is cached |
| `loading` | every `Loadable` stays `.loading` (a task that never resolves) |
| `error.network` / `error.server` | today fails with that `Backend.Failure` |
| `guessOffered` / `guessConfirmed` / `guessPending` / `guessError` | one guess in that state |
| `long` | a 1,200-character entry, a three-line brief headline, and a 60-entry drawer (pagination) |
| `searchHit` / `searchEmpty` | drawer search with match ranges, or none |
| `tookRead` / `tookWaiting` / `tookNoted` | JR-4 "what i took" in that state |
| `correction.applied` / `.confirm` / `.askOwnWords` / `.notACorrection` | `correct(…)` returns that outcome |
| `voice` | JR-4 for a voice entry, 1:42 |
| `deleteDialog` / `editing` | JR-4 opened in that state |

- **Acknowledgement:** the sample uses the same rotation rule as live (a pure function `nextAcknowledgement(previous:)` in `Features/Journal/`, since it's view logic shared by both). It's set only after `.sent`.
- **Ledger:** create `docs/design/sample-data-ledger.md` with one row per sample value: screen, field, sample value, contract path, and which wiring PR removes it.

Steps: scenarios enum → content from fixtures → behaviour (send, retry, answer, correct) on the injected clock → T02 registration → ledger.

Acceptance:
- Every scenario opens through T02 without a crash.
- Every model value decodes from, or matches, a contract fixture.
- No real clock: all delays use the injected clock.
- The ledger lists every sample value.

Tests:
- (unit) every scenario builds without throwing
- (unit) the sample content decodes from contract 02's fixtures
- (unit) a retry in `notSent` moves the entry to sent after the clock advances 1s
- (unit) the acknowledgement never repeats twice in a row over 100 sends
- (unit) the acknowledgement appears only after an entry is sent
- (unit) `loading` never resolves within 60 simulated seconds

Proof in the PR: test output; the ledger diff; a T02 launch of each scenario (headless screenshots of a debug list view).

Watch out:
- Don't add anything the protocol lacks. If a screen needs it, stop and ask the integrator.
- Never paste text from the founder's own data or a real account into samples.
