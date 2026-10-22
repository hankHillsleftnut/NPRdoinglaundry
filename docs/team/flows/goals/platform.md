# Goals · Platform cards

The tree on this side: **goals** › live data › `LiveGoalsData`, split into reads (PL3.5a), writes through the outbox (PL3.5b), your old goals reconciled once (PL3.5c) and the check-in push (PL3.5d). Contract: [04-goals.md](../../contracts/04-goals.md), every fixture in `fixtures/04/`. The protocol the views call is the integrator's `Platform/Flows/Goals.swift`, written from contract 04 before UIG.0 and PL3.5a start; its seam table is below so both sides build to the same names. If the protocol lacks something a card needs, stop and ask the integrator; never add to it yourself.

## The seam (for the integrator's `Platform/Flows/Goals.swift`)

| Screen need | Contract 04 | Shape the views expect |
|---|---|---|
| The goals tab | §2 `GET /v2/goals` | `list: Loadable<GoalsList>` where `GoalsList` = `goals: [Goal]`, `question: GoalQuestion?` (the first, or nil), `ended: EndedCounts` |
| The ended list | §2 `GET /v2/goals/ended` | `ended() async -> Loadable<[Goal]>` |
| One goal | §3 `GET /v2/goals/:id` | `goal(id:) -> Loadable<GoalDetail>` (`goal`, `said`, `didThisWeek`, `guess: Guess?`) |
| Add | §4 `POST` | `add(title:description:) async -> GoalWriteOutcome` (`.saved(Goal)`, `.queued(Goal)`, `.failed(Backend.Failure)`) |
| Rename | §4 `PATCH title` | `rename(id:title:) async -> GoalWriteOutcome` |
| Turn off / back on | §4 `PATCH active` | `setActive(id:_:) async -> GoalWriteOutcome`; `undoTurnOff(id:)` |
| Answer a question | §5 | `answer(questionId:_: GoalAnswer) async -> GoalQuestionOutcome` (`.goalCreated(Goal)`, `.declined`, `.kept(Goal)`, `.turnedOff(Goal)`, `.queued`, `.failed`) |
| Not for this goal | §6 | `removeDid(goalId:itemId:) async -> GoalCard?`; `undoRemoveDid(goalId:itemId:)` |
| GL-2's guess | contract 02 §4 | the journal's `answer(_:verdict:)` (PL3.1c), reached through the same flow object |
| Check-in switch | §7 | `checkinsEnabled: Loadable<Bool>`, `setCheckins(_:) async` (settings uses it; goals only reads it) |
| Connectivity | contract 00 | `isOnline: Bool` |

Every enum in these types has an `unknown` case (contracts rule 5): `GoalStatus.unknown` draws as an ended row with no status word; `GoalQuestion.Kind.unknown` is never shown; `RetroLine.Kind.unknown` draws no line; `DidItem.Kind.unknown` draws the row with the generic `journal` glyph and no chevron.

---

### PL3.5a · Goals repository and reads                                     size: M
Place in the tree: product › goals › live data › reads
Repo · branch: NPRdoinglaundry · `pl/PL3.5a-goals-reads`
Needs: `Platform/Flows/Goals.swift` (integrator), PL2.4 (`CachedRead`, `Loadable`), PL2.5 (cache keys), PL1.4 (the typed client); backend BE4.1a for the live run (fixtures until then)      Unblocks: PL3.5b, PL3.5d, the goals wiring PR

Why: your goals open instantly, even offline, with the last thing the server said, and refresh quietly behind.

Inputs:
- Contract 04 §1–§3, §8; fixtures `goals.list*.json`, `goals.ended.json`, `goal.detail*.json`, `error.*.json`
- PL2.4 (`CachedRead<Value>`: emits cached at once, then fresh or failed), PL2.5 (keys `goals`, `goals.<id>`, default max age 5 min)
- Code anchors: `Platform/Backend/Endpoint.swift` (PL1.4's endpoint pattern), `Platform/Flows/LiveJournalData.swift` (PL3.1's shape to copy)

Spec:
- `Platform/Backend/Endpoints/Goals.swift`: one `Endpoint` per door: `GoalsList`, `GoalsEnded`, `GoalDetail(id:)`, `CreateGoal`, `UpdateGoal(id:)`, `AnswerGoalQuestion(id:)`, `RemoveDid(goalId:itemId:)`, `RestoreDid(goalId:itemId:)`, `GetCheckins`, `PutCheckins`. Response types in `Backend.Goals` (`Sendable`, `Decodable`, explicit `CodingKeys` only where names differ, never `convertFromSnakeCase`; dates as ISO with milliseconds; `on`/`firstOn` as `Day` (`YYYY-MM-DD`), never `Date`).
- `Platform/Repositories/Goals.swift`: `actor Repositories.Goals` with `listStream()`, `endedStream()`, `detailStream(id:)` over `CachedRead` (keys `goals`, `goals.ended`, `goals.<id>`; max age 5 min for the list and detail, 30 min for ended), and `invalidate(_:)` used by writes.
- `Platform/Flows/LiveGoalsData.swift`: `@MainActor @Observable final class LiveGoalsData: GoalsData`. Subscribes to `listStream()` on first access and on every foreground; maps the contract types onto the protocol's view models without logic: no counting, no state deciding (the door sent `card.state`), no word building (the door sent `line.text`). The only client-side value is the bar scale (the views' job, C29.1).
- Opening a goal whose detail isn't cached but whose list card is: the detail starts as `.loading` and the page shows the card's title at once (passed from the list), never a blank page.
- `isOnline` mirrors `Backend.Reachability`.

Steps: endpoints → response types and fixture decoding → repository → live object (reads only) → tests.

Acceptance:
- With `-Data live -Environment local` (T02a) and a seeded account, GL-1's `full`, `tooEarly`, `nothingYet`, `ended`, `empty` and `offline` states are reachable on real data.
- Offline with a cache, the list shows the cached goals marked cached; offline without one, `.failed(.offline)`.

Tests (layer 4: every `fixtures/04/*.json` decodes into its type; layer 5):
- "every goals fixture decodes, and every error fixture decodes into its failure"
- "an unknown status, question kind, line kind or item kind decodes as unknown instead of failing"
- "the list streams the cached goals first, then the fresh ones"
- "offline with no cache, the list fails as offline"
- "opening a goal shows its title from the list while its detail loads"
- "a failed refresh keeps the cached list and reports the failure beside it"
- "no log line or analytics event carries a goal title, a quote or a did item's text" (scan the sink)

Proof: test output; a recording on local staging (integrator, test account) of GL-1 loading and going offline.

Watch out: day strings are local days the server already converted: never parse them into `Date` and back (time zones would shift them).

---

### PL3.5b · Goal writes through the outbox                                 size: M
Place in the tree: product › goals › live data › writes
Repo · branch: NPRdoinglaundry · `pl/PL3.5b-goals-writes`
Needs: PL3.5a, PL2.2 (the outbox), PL3.1c (the outbox's generic operations, added for `guess.answer`); backend BE4.1b, BE4.4, BE4.2 for the live run      Unblocks: PL3.5c, P16.2/P17.2 wiring, T05b live

Why: adding, renaming, turning off and answering all happen the moment you tap, even with no signal, and each reaches the server exactly once.

Inputs: contract 04 §4–§6; fixtures `goal.*.request.json`, `goal.create.response.json`, `goal.update.response.json`, `question.answer.*.json`, `did.remove.response.json`; PL2.2's `Store.Outbox` and PL3.1c's operation types.

Spec:
- Outbox operations (each a row with its own `Idempotency-Key`, a UUID stored with the row): `goal.create` (key = `clientGoalId`), `goal.rename`, `goal.setActive`, `goal.question.answer`, `goal.did.remove`, `goal.did.restore`.
- **Optimistic, then the truth:**
  - `add`: inserts a local goal (id = `clientGoalId`, card too early, `daysIn: 0`, line "just started. i'll know more in two weeks." taken from the contract's fixture constant **only until** the server answers) and enqueues. On the response, the local row is **replaced by the returned goal**, whose id may differ (the server matched an existing goal: BE4.1b); the list is re-fetched.
  - `rename`, `setActive`: change the cached goal at once; on a permanent failure, restore it and return `.failed` (the view shows the error line).
  - `answer`: removes the question at once; a created or kept goal is inserted from the response; offline → `.queued`, and the card stays folded (the outcome arrives later and the list refreshes).
  - `removeDid`: removes the row and lowers the counts at once using the server's returned card when it arrives (never computing counts on the phone; until then the bar holds its old value, dimmed to `opacity.pending`).
- **Undo** (`undoTurnOff`, `undoRemoveDid`): if the original operation hasn't been sent, it's cancelled in the outbox (one transaction) and nothing reaches the server; if it has, the reverse operation is enqueued (`setActive(true)` / `goal.did.restore`).
- After any write lands: invalidate `goals`, `goals.<id>`, and `goals.ended` when status changed.

Steps: operation types → optimistic cache edits → response reconciliation → undo → tests.

Acceptance: every write is visible at once, sent once, and survives a relaunch mid-send; undo before sending sends nothing; a create that matched an existing goal shows that goal once, never twice.

Tests (layer 5):
- "a goal added offline appears at once and is sent exactly once when back online"
- "a create the server matched to an existing goal replaces the local row instead of duplicating it"
- "a refused rename restores the old title and reports the failure"
- "undo before sending cancels the turn-off and sends nothing"
- "undo after sending enqueues turning it back on"
- "answering offline folds the question and queues the answer"
- "a repeated answer returns the stored outcome without a second goal"
- "removing a did item dims the bar until the server's recounted card arrives"
- "killing the app mid-send and relaunching sends with the same key" (in-memory GRDB, injected clock)

Proof: test output; a local-staging recording of add → turn off → undo.

Watch out: never count on the phone ("no intelligence in a client"): the optimistic too-early card is the one exception, and it's replaced as soon as the server answers.

---

### PL3.5c · Your old goals, reconciled once                                size: S
Place in the tree: product › goals › live data › legacy goals
Repo · branch: NPRdoinglaundry · `pl/PL3.5c-goals-legacy`
Needs: PL3.5b, PL2.6 (`legacy_goals` imported from `rich_goals`)      Unblocks: the goals ship gate (G4)

Why: the goals you set up in the current app are there in the new one, once, without duplicates or ghosts coming back.

Inputs: PL2.6 (`legacy_goals (local_id, server_id, title, description, …)`); app-reference §6 (`GoalsManager.syncRichGoals`: matches by server id, else by normalised title; turns server goals back "on"); backend BE4.1b (`blocksRevival`).

Spec:
- On the first launch with the goals flow switched on: for each `legacy_goals` row with no `server_id`, enqueue `goal.create` with `clientGoalId` = a UUID derived deterministically from `local_id` (UUID v5 in a fixed namespace) so a retry or a second launch can't create two. Rows with a `server_id` need nothing: the server already has them, in whatever status the brain set.
- Never sends `active: true` for a legacy goal (that's how the old sync undid merges, audit G1).
- Marks `legacy_ledger.confirmed_at` per goal when its create lands; when all are confirmed, sets `Store.Flags.goalsReconciled` and never runs again.
- Stops `GoalsManager.syncToBackend()` from running once the goals flow is on (a bridge: one guard line in `GoalsManager.swift:429`, listed in the PR), so the two never race.

Tests: "a legacy goal with no server id is created once, even across two launches" · "a legacy goal with a server id is left alone" · "reconciling never turns a merged or faded goal back on" · "the old sync doesn't run once the flow is on".

Watch out: `rich_goals` dates are Doubles since 2001 (PL2.6 decodes them); `createdAt` isn't sent: the server's `statedAt` is the day it arrives, so old goals start too early. That's honest (the brain hasn't counted them yet) and goes in the PR body for the founder.

---

### PL3.5d · The check-in push: category, tap and route                      size: S
Place in the tree: product › goals › check-ins › tap → Routing
Repo · branch: NPRdoinglaundry · `pl/PL3.5d-goals-checkin-push`
Needs: PL3.5a, PL5.1 (registration), PL5.3 (categories and taps), contract 07 (registers `goal.checkin` and the goals deep links); backend BE4.3 for the live run      Unblocks: T05b's push step

Why: tapping a check-in opens your goals with that question waiting first.

Inputs: contract 04 §7, fixture `push.checkin.json`; PL5.2's payload parser; PL5.3's category list.

Spec:
- `Routing.Destination` gains `.goals(questionId: UUID?)` and `.goal(id: UUID)`; deep links `retrospect://goals` and `retrospect://goals/<id>` parse to them (PL5.2's parser; unknown shapes → `.goals(nil)`).
- Category `goal.checkin`: no actions on the notification itself (answering happens in the app, where the question can be read in full).
- On tap: select the goals tab, pop to GL-1, and set `LiveGoalsData.pinnedQuestionId`; the list asks the door fresh (not the cache) and, if that question is still open, shows it first; if not, GL-1 opens normally with no message.
- Foreground arrival: no banner while the goals tab is visible; the list refreshes instead.

Tests: "a check-in tap opens goals with that question first" · "a tap for an answered question opens goals normally" · "a goals deep link with an id opens that goal" · "an unknown goals link opens the goals tab" · "the notification shows no goal words" (asserts the payload fixture's alert strings are the fixed ones).
