# Contract 04 · Goals

The goals flow: GL-1 (the goals tab: your goals as cards, Retro's questions first, the ended row), GL-2 (one goal: what you said, what you did this week, one guess), the ended list, adding and renaming a goal, turning a goal off and back on, answering Retro's questions (yes / not quite), and check-in pushes. Built on contract 00. Status: **draft for the founder's review**.

Every agent field below was read from the brain's code on 21 Oct (`origin/main` a886060: `src/goals/lifecycle.ts`, `src/understanding/said-vs-did.ts`, `src/understanding/read.ts`, `src/hypotheses/offer.ts`, migration 139) and the backend's (`backend/src/routes/goals.ts`, `services/goals.ts`, `services/goal-lifecycle.ts`, `services/goal-dedupe.ts`). Where the brain can't give what a screen needs, the byte that adds it is named (BE4.x, `../flows/goals/backend.md`).

## 0. The honesty rules this contract enforces

Goals are where an app is most tempted to cheer or scold. These rules are the claim ladder applied to goals. The door enforces them, so no client can break them, and each has a test (BE4.1a).

1. **A goal is your words.** `title` is what you said or typed, unchanged (lowercase only if you wrote it so). Retro never rewrites it.
2. **"Said" is arithmetic, "did" is evidence.** `said` counts your own entries that mention the goal (the brain's `isMentioned` rule, `lifecycle.ts:32`). `did` counts dated things that plainly served it (calendar events, videos you chose), each judged by the brain with "none" allowed and each one correctable ("not for this goal"). Nothing else is counted, and the two are never merged into a score, a percentage or a streak.
3. **No verdict words, ever.** No field carries "on track", "behind", "failing", "great job" or any judgement. The gap shows only as two bars and two numbers.
4. **Evidence before anything is said about progress.** For the first 14 days after a goal is stated (or stated again), `did` is `tooEarly`. When there's nothing on either side, the card says `nothingYet`. Neither state shows a bar that could be read as zero effort.
5. **Retro's one line is earned.** `line` is present only when it rests on something: the too-early line (days counted), "you do this more than you mention it" (arithmetic, with thresholds), or a **live** pattern the brain linked to this goal (already promoted after repetition). Otherwise there is no line. Never a model-written sentence.
6. **Guesses are asked, never asserted.** A goal Retro only heard you mention is a **question** ("is that a goal?") quoting your exact words. A why behind a goal is a hypothesis (contract 02 `Guess`), shown only while the founder's `speak` dial is on (D11). A check-in is a question.
7. **Quitting is a choice.** Turning a goal off is immediate, undoable, and never called failure. Nothing is deleted.

## 1. Shared types

```ts
type GoalStatus = "active" | "off" | "faded" | "merged" | "done" | "unknown";
// brain goals.status: active → active; quit → off ("turned off by you"); expired → faded
// (stated over 90 days ago, not mentioned since); merged → merged; achieved → done (no app path sets it yet: §9 Q8).
// The door reads `status`, never `is_active` (the two disagree today: agent-api-reference §9.2, §9.5).

type Goal = {
  id: string;                            // goals.id
  title: string;                         // your words (§0.1), 1–200 characters
  description?: string;                  // ≤ 2,000; never shown on GL-1
  status: GoalStatus;
  origin: "you" | "onboarding" | "question" | "unknown";   // how it started (BE4.1b stores it)
  statedAt: string;                      // max(created_at, status_at of the last "turned back on" / "stated again")
  endedAt?: string;                      // status_at, when status is off | faded | merged | done
  mergedInto?: { id: string; title: string };              // status merged only
  card: GoalCard;                        // absent on ended goals (§3)
};

type GoalCard = {
  said: { count: number };               // own entries mentioning it, last 28 days (§9 Q1)
  did:
    | { state: "counted"; count: number }                 // things that served it, last 28 days (§9 Q1)
    | { state: "tooEarly"; daysIn: number; knowMoreOn: string };   // YYYY-MM-DD, statedAt + 14 days
  state: "compared" | "tooEarly" | "nothingYet";          // the door decides (§0.4); the app draws it
  line?: RetroLine;
  computedAt: string;                    // when the brain last counted (the daily snapshot, BE4.0a)
};

type RetroLine = {
  kind: "tooEarly" | "doesMoreThanSays" | "pattern" | "unknown";
  text: string;                          // lowercase, Retro's voice; built by the door from fixed templates or a pattern label
  sources: SourceRef[];                  // contract 02 §1; [] for tooEarly
};
// The only texts (BE4.0a's GOAL_LINES): tooEarly "just started. i'll know more in two weeks." (days 0–6) and
// "<n> days in. i'll know more next week." (days 7–13); doesMoreThanSays "you do this more than you mention it."
// (did ≥ 3 and did ≥ 2 × said); pattern = a live linked pattern's label as the brain stores it.

type GoalQuestion = {
  id: string;
  kind: "isThisAGoal" | "stillOnIt" | "unknown";
  question: string;                      // always ends with "?"
  quote?: { text: string; writtenOn: string; entryId: string };   // isThisAGoal: your exact words, verified present in the entry
  goal?: { id: string; title: string };                           // stillOnIt: the goal it asks about
  answers: ["yes", "notQuite"];          // fixed; labels "yes" / "not quite"
};

type DidItem = {
  id: string;                            // raw_content.id the brain linked (never a pattern)
  kind: "calendar" | "entry" | "watched" | "unknown";       // content_type calendar|google_calendar → calendar; own words → entry; youtube → watched
  on: string;                            // YYYY-MM-DD, the user's local day (the door converts; the brain is UTC)
  text: string;                          // one line: the event title, the video title, or the entry's first line (≤ 140 characters)
  hours?: number;                        // calendar only, 1 decimal, booked time (a floor, never "the whole picture")
  opens?: SourceRef;                     // present when the app has a page for it (entry → JR-4); absent for calendar and watched until YO-3 exists
};
```
`Guess` and `SourceRef` are contract 02's types, unchanged.

## 2. The goals tab (GL-1)

`GET /v2/goals` — bucket `read`, cached by the app as `goals` (PL2.5, max age 5 min)
```json
{ "goals": [ Goal ], "questions": [ GoalQuestion ], "ended": { "off": 2, "faded": 0, "merged": 1, "done": 0 }, "asOf": "2026-10-21T06:00:12.000Z" }
```
- `goals`: active only, ordered by the latest of (last mention, last did item, statedAt), newest first ("newest-moving first", mid-fi plan). Max 50.
- `questions`: at most **one** (the screen shows one at a time, first in the scroll; build note "questions lead", 20 Oct). A `stillOnIt` check-in wins over an `isThisAGoal` suggestion. `[]` when the person has none, or when the suggestions dial is off (§9 Q3).
- `ended`: counts only; the row reads them ("turned off 2 · merged 1 ›", zeros omitted). All zero → no row.
- `asOf`: the snapshot's time; the app never shows it.

`GET /v2/goals/ended` — bucket `read`, cache `goals.ended`
```json
{ "goals": [ Goal ] }
```
Every goal whose status isn't `active`, most recently ended first, max 100, `card` absent.

## 3. One goal (GL-2)

`GET /v2/goals/:id` — bucket `read`, cache `goals.<id>`
```json
{
  "goal": Goal,
  "said": { "count": 14, "firstOn": "2026-09-30", "lastOn": "2026-10-19" },
  "didThisWeek": { "hours": 4.5, "items": [ DidItem ] },
  "guess": Guess
}
```
- `said` here counts **every** mention since `statedAt` (the header "said 14 times · first on 30 sep · last on sunday"); `firstOn`/`lastOn` absent when `count` is 0.
- `didThisWeek`: items from the last 7 local days, newest first, max 20; `hours` omitted when no calendar item counted. During `tooEarly` the items still list (they're facts), but the card's did bar stays "too early to tell".
- `guess`: at most one **offered** hypothesis whose `supports` touch this goal's evidence or a pattern linked to it (BE4.0f); omitted when `speaking` is false (D11) or there is none. Answering it is contract 02 `POST /v2/guesses/:id`.
- An ended goal returns the same shape with `goal.card` absent, `didThisWeek.items` `[]` and no `guess`: GL-2 shows the dated line ("turned off on 12 oct") and "turn back on".
- Someone else's goal, or a made-up id: `not_found`.

## 4. Adding, renaming, turning off and on

`POST /v2/goals` — bucket `write`, idempotent (`Idempotency-Key: <clientGoalId>`)
```json
{ "title": "learn the cello", "description": "a lesson a week", "clientGoalId": "<uuid>", "fromOnboarding": false, "quote": null }
```
→ **201** `{ "goal": Goal }`; a replay → **200** with the same goal; same key, different body → `idempotency_mismatch`.
- `title` 1–200 characters after trimming; `description` ≤ 2,000; `fromOnboarding` (contract 01 §2) sets `origin: "onboarding"`; `quote` (optional, ≤ 500) is the onboarding candidate's quote, kept as the first "said".
- **Saying the same goal twice** (the backend's embedding match, `goal-dedupe.ts`, > 0.9 similar) returns the existing goal: still active → **200** with it unchanged; ended → it's turned back on ("stated again") and returned. The app shows the returned goal, whatever its id.
- A new goal's card is `tooEarly` with `daysIn: 0` at once (the door doesn't wait for the snapshot).

`PATCH /v2/goals/:id` — bucket `write`, idempotent (`Idempotency-Key` per change)
```json
{ "title": "learn the cello properly" }
{ "active": false }
{ "active": true }
```
→ `{ "goal": Goal }`. Exactly one of `title` or `active` per request (`invalid_request` otherwise).
- `title`: a rename. The goal keeps its id, history and counts; the embedding is redone (`updateGoal`).
- `active: false`: status `off`, reason "turned off by you", immediate (`lifecycleFor`).
- `active: true`: always an explicit revive from GL-2's "turn back on" (the door sends the backend's `revive: true`), so faded and merged goals come back too; `statedAt` resets, and the card is `tooEarly` again.
- There is **no delete** (§9 Q9). Delete-my-data (contract 06) removes goals with everything else.

## 5. Retro's questions (yes / not quite)

`POST /v2/goals/questions/:id` — bucket `write`, idempotent (`Idempotency-Key`); answering an answered question returns its stored outcome
```json
{ "answer": "yes" }
```
→ one of:
```json
{ "outcome": "goalCreated", "goal": Goal }
{ "outcome": "declined" }
{ "outcome": "kept", "goal": Goal }
{ "outcome": "turnedOff", "goal": Goal }
```
| kind | yes | not quite |
|---|---|---|
| `isThisAGoal` | `goalCreated` (title = the quote's goal words, chosen by BE4.0d; `origin: "question"`) | `declined`: never asked about these words again |
| `stillOnIt` | `kept`: stated again (`statedAt` resets; the 90-day fade restarts) | `turnedOff`: the goal is turned off; the app offers undo (§9 Q4) |

A question that has expired or vanished (its entry was deleted, the goal was turned off elsewhere) → `not_found`; the app folds the card away quietly.

## 6. "Not for this goal"

`POST /v2/goals/:id/did/:itemId/remove` — bucket `write`, idempotent (repeat → same result)
→ `{ "removed": true, "card": GoalCard }`. The brain records the verdict (BE4.0c); that item is never linked to that goal again and both counts are recomputed at once. Undo is `DELETE /v2/goals/:id/did/:itemId/remove` → `{ "removed": false, "card": GoalCard }`.

## 7. Check-ins

A check-in is a `stillOnIt` question (§5), made by the brain when an active goal has gone quiet: stated over 21 days ago, no mention and no did item in the last 21 days, and no check-in on it in the last 28 days (BE4.0e; thresholds are §9 Q4's lean). At most one per person per week.

`GET /v2/goals/checkins` → `{ "enabled": false }`; `PUT /v2/goals/checkins` `{ "enabled": true }` → `{ "enabled": true }`. Per person, **off by default** (like the brief, founder 21 Oct). Contract 06 shows this switch in settings; this contract owns the door.

**The push** (when enabled and a check-in is made). The payload carries no goal words (contract 07 owns the format; this is the goals part):
```json
{ "aps": { "alert": { "title": "retrospect", "body": "a question about one of your goals." }, "category": "goal.checkin", "thread-id": "goals" },
  "route": "goals", "questionId": "<uuid>" }
```
- Sent between 10:00 and 20:00 in the user's time zone (`users.time_zone`), never twice in 7 days, never when push is off (BE2.7's device rules).
- Tapping opens GL-1 with that question first. If it's already answered or gone, GL-1 opens normally.

## 8. Errors

Every door can return contract 00's `unauthenticated`, `invite_required`, `suspended`, `update_required`, `rate_limited`, `upstream_timeout`, `upstream_unavailable`, `internal`. Per door:

| Door | Also |
|---|---|
| `GET /v2/goals`, `/ended` | — |
| `GET /v2/goals/:id` | `not_found` |
| `POST /v2/goals` | `invalid_request`, `idempotency_mismatch` |
| `PATCH /v2/goals/:id` | `invalid_request`, `not_found`, `idempotency_mismatch` |
| `POST /v2/goals/questions/:id` | `invalid_request`, `not_found`, `idempotency_mismatch` |
| `POST/DELETE /v2/goals/:id/did/:itemId/remove` | `not_found` (goal or item not yours, or the item isn't linked) |
| `GET/PUT /v2/goals/checkins` | `invalid_request` (PUT: strict boolean) |

No goals door calls a model on the request path, so none returns `spend_limited`. The brain's daily said-vs-did judge (one small model call per person with active goals) is counted against the person's spend by BEA.4 and skipped, not failed, when the cap is reached (the card keeps the last snapshot).

## 9. Decisions the founder makes for this contract

Each has a lean; work goes ahead on the lean. Full options and what changes under each are in `../flows/goals/README.md` §7.

1. **Count windows.** Lean: the card's said and did both count the last 28 days; GL-2's header counts every mention since stated; GL-2's rows are this week, as drawn.
2. **Retro's one line.** Lean: only the three earned kinds in §1 (`tooEarly`, `doesMoreThanSays`, `pattern`); no weekday arithmetic ("most on sundays") until a brain engine earns it.
3. **"is that a goal?" questions.** Lean: from the brain's `stated_goal` facts with an exact quote, behind a new dial `goal_questions.speak`, off until the founder turns it on (like D11).
4. **Check-ins.** Lean: off by default per person; quiet for 21 days; at most one a week; 10:00–20:00; a content-free push; "not quite" turns the goal off with undo.
5. **The ended row's ›.** Lean: an "ended" list (GL-3) in the settings-page layout; needs a Paper drawing.
6. **Adding a goal (+).** Lean: a sheet with the voice composer and one title, "what are you working toward?"; needs a Paper drawing.
7. **Did rows.** Lean: a row opens its source when the app has a page for it (entries → JR-4); "not for this goal" is in the long-press menu, with undo.
8. **Done.** Lean: no "done" in v1; "turn off" only, as drawn.
9. **Delete a goal.** Lean: no; rename and turn off cover it.
10. **A check-in's label.** Lean: "a question" on check-ins; "a guess" stays on is-that-a-goal and GL-2's guess.

## 10. Fixtures

`fixtures/04/` holds the `data` object of each success, and the whole envelope for each error:
`goals.list.json`, `goals.list.minimal.json`, `goals.list.checkin.json`, `goals.ended.json`, `goal.detail.json`, `goal.detail.minimal.json`, `goal.detail.off.json`, `goal.create.request.json`, `goal.create.onboarding.request.json`, `goal.create.response.json`, `goal.rename.request.json`, `goal.turnoff.request.json`, `goal.turnon.request.json`, `goal.update.response.json`, `question.answer.request.json`, `question.answer.goal-created.json`, `question.answer.declined.json`, `question.answer.kept.json`, `question.answer.turned-off.json`, `did.remove.response.json`, `checkins.request.json`, `checkins.response.json`, `push.checkin.json`, `error.invalid_request.json`, `error.not_found.json`, `error.idempotency_mismatch.json`, `error.rate_limited.json`, `error.upstream_timeout.json`, `error.upstream_unavailable.json`, `error.internal.json`. Invented content only (contracts README rule 8).
