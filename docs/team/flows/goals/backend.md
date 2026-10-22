# Goals · backend cards

The tree on this side: **goals** › see your goals (BE4.0a, BE4.0b, BE4.1a) · answer Retro's questions (BE4.0d, BE4.4) · one goal (BE4.0c, BE4.0f, BE4.2) · add and rename (BE4.1b) · check-ins (BE4.0e, BE4.3). Contract: [04-goals.md](../../contracts/04-goals.md). Every door is built with the kit (BE0.1), passes the nine-test door suite (BE0.2) and the invite gate (BE0.12). Every agent route gets a two-user PGlite test, and every agent write runs under `SET ROLE service_role` in its test (BEA.1's harness). Fixtures: the backend validates every `fixtures/04/*.json` success file against its door's zod output schema (testing.md layer 4).

Order: BE4.0a → BE4.0b → BE4.1a → BE4.1b → BE4.0c → BE4.0f → BE4.2 → BE4.0d → BE4.4 → BE4.0e → BE4.3. Two in review at once at most.

**Who owns what.** The `goals` table belongs to the backend's schema; the agent only alters it (agent-api-reference §12.2 note). So: goal rows are created, renamed and switched by the **backend** (its existing `services/goals.ts`, which already does dedupe, embeddings and the lifecycle fields). Counting, judging, suggesting and checking in are **brain** work, exposed by new agent routes that the doors call. Migrations are agent migrations (house style §12.2), numbered at build time: **152 is BEA.1's**, so these take the next free numbers in merge order. Files only, listed as not applied; production migrations are the founder's.

---

### BE4.0a · Said counts and the daily progress snapshot                    size: M
Place in the tree: goals › see your goals › brain › `goal_progress`
Repo · branch: agent · `agent/BE4.0a-goal-progress`
Needs: BEA.2 (ownership in the agent), BEA.4 (spend counted for every model call)      Unblocks: BE4.0b, BE4.0c, BE4.0e

Why: the goals tab opens instantly with honest counts, and Retro does the expensive judging once a day instead of every time you look.

Inputs:
- Contract: 04 §0 (rules 2, 4, 5), §1 (`GoalCard`), §9 Q1–Q2 (leans)
- Reference: agent-api-reference §9.5 (`readSaidVsDid`: one model call, scans all calendar and YouTube rows), §10.6 (`goals` + 139), §10.1 (own-words types)
- Code anchors: `src/understanding/said-vs-did.ts:81-127` (`readSaidVsDid`), `:42` (`judgePrompt`), `:45-60` (`vetLinks`); `src/goals/lifecycle.ts:26-36` (`distinctiveWords`, `isMentioned`), `:61` (`OWN_WORDS`), `:63-89` (`applyGoalLifecycle`); `src/jobs/daily-ingestion.ts:58` (where the lifecycle runs); `src/index.ts:129-136` (crons behind `ENABLE_AGENT_CRONS`); `src/pipelines/podcast-v2.ts:37` (the episode calls `readSaidVsDid` too)

Spec:
- **Migration** `<n>_goal_progress.sql`: table `goal_progress (goal_id uuid PK → goals ON DELETE CASCADE, user_id uuid NOT NULL → users ON DELETE CASCADE, said_28d int NOT NULL, said_all int NOT NULL, said_first_at timestamptz, said_last_at timestamptz, did_28d int NOT NULL, did_hours_7d numeric(5,1), links jsonb NOT NULL default '[]', line jsonb, computed_at timestamptz NOT NULL)`. `links` = `[{ itemId, kind: 'event'|'content', at, hours? }]` (ids and dates only, never text). Index `(user_id)`. RLS on, `REVOKE ALL … FROM PUBLIC, anon, authenticated`, `GRANT SELECT, INSERT, UPDATE, DELETE … TO service_role`.
- **Engine** `src/goals/progress.ts`:
  - `countMentions(goal, ownWords, since)` (pure): reuses `isMentioned`; returns `{ count, firstAt, lastAt }`. `said_28d` over 28 days; `said_all` since `statedAt` (= max(created_at, status_at), lifecycle's rule at `lifecycle.ts:55`).
  - `buildProgress(userId, { db, now, judge, timeZone })`: loads active goals (`status = 'active'`, never `is_active`), the person's own words since the oldest `statedAt` (projected columns `created_at, content`, own-words types only), runs `readSaidVsDid` **once** with an extended window, drops links the person rejected (BE4.0c's table, read here once it exists; until then none), then per goal: `did_28d` = counted event + content links dated within 28 days; `did_hours_7d` = event hours in the last 7 local days (the zone from `users.time_zone`, UTC when missing).
  - `line` (pure, `chooseLine`), contract 04 §0.5, one of: `tooEarly` when `statedAt` is under 14 days (`daysIn` < 7 → "just started. i'll know more in two weeks."; else "<n> days in. i'll know more next week."); `doesMoreThanSays` when `did_28d ≥ 3` and `did_28d ≥ 2 × said_28d` ("you do this more than you mention it."); `pattern` when the judge linked a **live** pattern (first by `confidence`; text = its label, lowercased only if it is all lowercase already, ending in a full stop); else `null`. Every string lives in one exported constant `GOAL_LINES`.
- **Job:** `refreshGoalProgress(userId)` upserts one row per active goal and deletes rows of goals no longer active. Runs in `runDailyIngestion` right after `applyGoalLifecycle` (line 58), and is also exported for BE4.0b's refresh. Skips the judge (keeps yesterday's links, recounts said) when the spend guard says the person is at the cap; logs `[goal-progress] user=<id> goals=<n> links=<n> skipped=<reason?>` (counts only).
- **Episode reuse:** `podcast-v2.ts:37` reads the snapshot's links when `computed_at` is under 24 h old, instead of judging again (one model call a day per person, not two). Behind a flag `GOAL_PROGRESS_REUSE` (default on) so it can be turned off if episodes regress.
- The judge's model and prompt are unchanged ("when unsure, leave it out" is the claim ladder's guard here). Its cost goes through BEA.4's counter under `goal_progress`.

Steps: migration → `countMentions` + `chooseLine` (pure, tested) → `buildProgress` → the job hook → the episode reuse flag → tests.

Acceptance:
- One run writes one row per active goal and none for ended goals; a second run the same day makes no second model call when nothing changed (the judge is skipped if no own words, events or patterns changed since `computed_at`).
- A goal stated 9 days ago gets the too-early line; one with 7 things done and 2 mentions gets "you do this more than you mention it."; one with nothing gets no line.
- No row ever holds an event title or entry text.

Tests (agent, layers 1–2):
- `mentions count only the person's own words, inside the window`
- `a revived goal counts from the day it was stated again`
- `the too-early line counts days and switches at day seven`
- `does-more-than-says needs at least three things and twice the mentions`
- `a live pattern linked by the judge becomes the line; a candidate pattern never does`
- `a person at the spend cap keeps yesterday's links and still gets fresh mention counts`
- `the snapshot only reads and writes the person's own goals` (two users)
- `the snapshot writes as service_role` (role switched)
- `the episode reuses a fresh snapshot instead of judging again`

Proof: test output; a local-staging run on a seeded test account (BE0.S) printing counts per goal (numbers only).

Watch out: `readSaidVsDid` filters `status = 'active'` while `readUnderstanding` filters `is_active`: use `status` everywhere here and leave a findings-log entry for the other reader. Crons only run with `ENABLE_AGENT_CRONS`; on local staging call the job by hand. `daily-ingestion` only visits people with new content in 24 h: that's fine for counts (nothing changed) but `tooEarly` must be computed at read time from `statedAt`, not trusted from the snapshot (BE4.0b does this).

---

### BE4.0b · Goal progress and one-goal routes                               size: M
Place in the tree: goals › see your goals › brain routes
Repo · branch: agent · `agent/BE4.0b-goal-routes`
Needs: BE4.0a      Unblocks: BE4.1a, BE4.0c, BE4.0d, BE4.0f

Why: the doors get everything GL-1 and GL-2 show from one place, already counted, with nothing for the app to work out.

Inputs:
- Contract: 04 §1–§3
- Reference: agent-api-reference "Read this first" (userId is trusted: the door is the defence), §9.3 (`lineage` scoping notes), §10.1 (content types)
- Code anchors: `src/index.ts:53-68` (mount `/goals` with `requireInternalSecret`); `src/routes/hypotheses.ts` (route style); BE4.0a's `src/goals/progress.ts`

Spec:
- `GET /goals/:userId/progress` → `{ goals: [{ goalId, statedAt, said28d, did28d, line, computedAt }], ended: { quit, expired, merged, achieved } }`. Reads `goal_progress` + `goals` (projected columns). A goal with no snapshot row yet (created since the last run) gets `said28d` counted live (one query, no model), `did28d` 0 and the too-early line. `line.kind = 'tooEarly'` is always recomputed from `statedAt` and `now`, never read stale.
- `GET /goals/:userId/:goalId` → `{ goalId, saidAll, firstAt, lastAt, didThisWeek: [{ itemId, kind, at, hours? , text }], hoursThisWeek }`: the goal must belong to `userId` (else 404 `{ error: 'not found' }`); items come only from this goal's `links` (user-scoped by construction), resolved to `raw_content` by id **and** `user_id`; `text` = the event title from `source_items.normalized_data.title`, the video's first line, or the entry's first line, trimmed to 140 characters; `at` stays UTC (the door converts to a local day).
- `POST /goals/:userId/refresh` → `{ refreshed: true }` (fire-and-forget behind a per-user lock, like BEA.5): recounts said for every goal with no model call. Called by the doors after a create, rename or revive so a new goal's mentions show the same day.
- Validation: `userId`, `goalId` are UUIDs (`invalid` → 400 `{ error }`, BEA.6's JSON handler). Never `select('*')` (`goals.embedding` is 3,072 floats).

Acceptance: each route returns only the caller-named user's data; a made-up or foreign goal id is a 404; a goal created a minute ago appears with a live said count and the too-early line.

Tests: `progress lists active goals with their counts and ended totals` · `a goal with no snapshot yet is too early with a live said count` · `one goal resolves its did items to short text and dates` · `another person's goal is not found` (two users) · `an item linked to a goal but owned by someone else is never returned` · `refresh recounts without calling the judge`.

Watch out: `source_items` lookups by id are not user-scoped in some helpers (agent-api-reference §9.3): always join back through the person's `raw_content` row first.

---

### BE4.1a · Doors: your goals, the ended list, one goal                   size: M
Place in the tree: goals › see your goals › `GET /v2/goals`, `GET /v2/goals/ended`, `GET /v2/goals/:id`
Repo · branch: backend · `be/BE4.1a-goals-read`
Needs: BE4.0b, BE0.1, BE0.2, BE0.12      Unblocks: PL3.5a (live), P16/P17 wiring, BE4.1b, BE4.2

Why: the goals tab and one goal show real data, shaped so the app only draws.

Inputs:
- Contract: 04 §0–§3, §8; fixtures `goals.list*.json`, `goals.ended.json`, `goal.detail*.json`
- Reference: backend-reference §12 (mount `/v2` between `index.ts:82` and `:84`), §4 (the agent client: timeouts, retries)
- Code anchors: `backend/src/services/goals.ts:233` (`listGoals`), `:259` (`getGoal`); `backend/src/services/goal-lifecycle.ts` (status words)

Spec:
- `GET /v2/goals`: user from the token; goal rows from the backend (`id, title, description, status, status_at, status_reason, created_at, merged_into`, plus `origin` from BE4.1b's column) joined with agent `GET /goals/:userId/progress` (timeout 8 s, retry `read`). Maps status (`quit → off`, `expired → faded`, `achieved → done`, else `unknown` and a logged count); builds `GoalCard`: `state` = `tooEarly` when `statedAt` is under 14 days, `nothingYet` when said and did are both 0, else `compared`; `did` = `{ state: 'tooEarly', daysIn, knowMoreOn }` or `{ state: 'counted', count }`; `line` passed through only if its `kind` is in the closed list (anything else dropped and counted). Orders by the latest of last mention, last did item and `statedAt`. Adds `questions` (BE4.4 fills it; `[]` until then) and `ended` counts.
- **The honesty check** (contract 04 §0.3): one exported function `assertNoVerdict(text)` runs over every `line.text` and question; a match against the closed word list (`on track`, `behind`, `failing`, `failed`, `great job`, `well done`, `keep it up`, `streak`, `%`) drops the line and logs a count. It's a backstop: the brain's templates never contain these.
- `GET /v2/goals/ended`: non-active goals, newest `status_at` first, max 100, `mergedInto` resolved to `{ id, title }` only when that goal is the same person's.
- `GET /v2/goals/:id`: ownership first (`goals.user_id`), else `not_found`; agent `GET /goals/:userId/:goalId`; `didThisWeek.items` mapped to `DidItem` (`on` = the local day from `users.time_zone`; `kind` from content type; `opens` = `{ kind: 'entry', id }` for own-words items only); `said` from `saidAll`/`firstAt`/`lastAt` as local days; `guess` added by BE4.2 (absent until then). Ended goal → `card` absent, items `[]`.
- If the agent fails, `GET /v2/goals` returns `upstream_unavailable` / `upstream_timeout` rather than cards without counts: a card in `nothingYet` would claim "nothing to compare yet" when that isn't known. The app keeps its cached list (contract 04 §8).
- Buckets `read`. Logs: door, userId, status, ms, counts (goals, items); never titles or text.

Acceptance: the three fixtures' shapes come back field for field from a seeded staging account; no response ever carries a verdict word; a foreign goal id is `not_found`.

Tests (door suite on each door, plus):
- `a goal stated nine days ago is too early with the knowing day two weeks after it was stated`
- `a goal with nothing said or done is nothing yet, never compared at zero`
- `status words map, and an unknown status is counted, not shown raw`
- `a line with a verdict word is dropped`
- `merged-into is only shown when that goal is the same person's`
- `did days follow the person's time zone, not UTC`
- `when the brain fails the list fails, rather than showing empty cards`
- fixtures validate against the output schemas.

Proof: test output; a staging run listing counts only.

Watch out: never `select('*')` on `goals` (the embedding). The old `/goals` routes stay as they are until the old screens retire (X-bytes).

---

### BE4.1b · Doors: add, rename, turn off and on                          size: M
Place in the tree: goals › add and rename, turn off › `POST /v2/goals`, `PATCH /v2/goals/:id`
Repo · branch: backend (+ one agent migration) · `be/BE4.1b-goals-write`
Needs: BE4.1a      Unblocks: PL3.5b, BE4.4, contract 01's onboarding "yes" (replaces BE2.1's stop-gap door)

Why: you can add a goal, fix its name, turn it off and bring it back, and nothing is ever lost or done twice.

Inputs:
- Contract: 04 §4; contract 01 §2 (`fromOnboarding`); fixtures `goal.create*.json`, `goal.rename.request.json`, `goal.turn*.request.json`, `goal.update.response.json`
- Code anchors: `backend/src/services/goals.ts:41-91` (`createGoal`: embedding, `findSameGoal` dedupe, revive), `:93-160` (`updateGoal`, `blocksRevival`), `:163-215` (`declineGoal` sets only `is_active` — the bug below); `backend/src/services/goal-lifecycle.ts` (`lifecycleFor`); `backend/src/types/index.ts:316-331` (schemas)

Spec:
- **Migration** (agent, additive): `ALTER TABLE goals ADD COLUMN IF NOT EXISTS origin text NOT NULL DEFAULT 'you' CHECK (origin IN ('you','onboarding','question'))`, `ADD COLUMN IF NOT EXISTS first_quote text`, `ADD COLUMN IF NOT EXISTS client_goal_id uuid`, unique index `(user_id, client_goal_id)` where not null.
- `POST /v2/goals`: zod `{ title: trimmed 1–200, description?: ≤2000, clientGoalId: uuid, fromOnboarding?: boolean, quote?: string ≤500 | null }`; `Idempotency-Key` required and equal to `clientGoalId`. Replay (same key, same body hash) → 200 with the stored goal; different body → 409 `idempotency_mismatch`. Calls `createGoal` (keeps its dedupe and revive); writes `origin`, `first_quote`, `client_goal_id`; then agent `POST /goals/:userId/refresh` (fire-and-forget). Returns 201 with the contract `Goal`, card too early with `daysIn: 0`.
- `PATCH /v2/goals/:id`: exactly one of `title` (1–200) or `active` (strict boolean). Ownership first. `title` → `updateGoal` (re-embeds). `active:false` → `lifecycleFor(false)`. `active:true` → `updateGoal(…, { isActive: true, revive: true })` (the person's explicit choice brings back faded and merged goals; `status_at` resets). Idempotent per `Idempotency-Key` (stored hash, like BE0.0's table).
- **The lifecycle fix:** `declineGoal` (old app) moves to `lifecycleFor(false)` so `status` and `is_active` can't disagree; a one-off migration sets `status = 'quit', status_reason = 'turned off before lifecycle sync'` where `is_active = false AND status = 'active'` (same shape as 139's backfill). A test asserts no write path sets one without the other.
- Buckets `write`; the embedding call is the only provider call (OpenAI embeddings, counted under BEA.4 as `goal_embedding`).

Acceptance: a create retried ten times makes one goal; saying an existing goal again returns it; turning off is immediate and turning back on restores it too early; no row ends up with `is_active` and `status` disagreeing.

Tests (door suite, plus): `a create retried with the same key makes one goal` · `the same key with a different title is idempotency_mismatch` · `saying an active goal again returns it unchanged` · `saying an ended goal again turns it back on` · `an onboarding yes stores its origin and quote` · `a rename keeps the goal's id and history` · `turning off sets status and is_active together` · `turning back on revives a faded goal and restarts its two weeks` · `you can't rename or turn off someone else's goal` · `a patch with both a title and active is refused` · fixtures validate.

Watch out: `createGoal` can return an **existing** goal with a different id: the response is the truth, and PL3.5b replaces its optimistic row by the returned id. The old app's `syncRichGoals` still turns goals "on" without `revive`; `blocksRevival` must keep refusing that.

---

### BE4.0c · "Not for this goal"                                            size: S
Place in the tree: goals › one goal › brain › link verdicts
Repo · branch: agent · `agent/BE4.0c-goal-link-verdicts`
Needs: BE4.0b      Unblocks: BE4.2

Why: when Retro counts something that had nothing to do with your goal, you say so once and it never counts it again.

Inputs: contract 04 §6; code anchors `src/understanding/said-vs-did.ts:45-60` (`vetLinks`), BE4.0a's `buildProgress`.

Spec:
- Migration `<n>_goal_link_verdicts.sql`: `goal_link_verdicts (user_id, goal_id → goals CASCADE, item_id uuid, verdict text CHECK ('removed'), link jsonb NOT NULL, created_at, PRIMARY KEY (goal_id, item_id))` (`link` keeps the removed snapshot entry, ids and dates only, so undo can restore it exactly), RLS/grants as house style.
- `POST /goals/:userId/:goalId/links/:itemId/remove` → upsert the verdict, drop the link from `goal_progress.links`, recount `did_28d`/`did_hours_7d` and the line, return the new counts. `DELETE` the same path (undo) → put the verdict's `link` back into `goal_progress.links`, recount, delete the verdict, return the counts.
- `buildProgress` filters verdict rows before counting (the judge still sees everything, so its other links don't shift).
- 404 when the goal isn't the user's or the item isn't currently linked.

Tests: `a removed item never counts toward that goal again` · `removing recounts the card at once` · `undo restores the item` · `the item still counts for another goal it serves` · two-user test · role-switched write test.

Watch out: the item id is a `raw_content` id; never accept a pattern id here (patterns aren't rows on GL-2).

---

### BE4.0f · The guess for one goal                                          size: S
Place in the tree: goals › one goal › brain › hypotheses for a goal
Repo · branch: agent · `agent/BE4.0f-goal-guess`
Needs: BE1.4 (hypotheses can be listed), BE4.0b      Unblocks: BE4.2

Why: when Retro has a thought about why a goal is going the way it is, it asks it on that goal's page, and only when it's allowed to speak.

Inputs: contract 04 §3 (`guess`); contract 02 §4 (`Guess`); agent-api-reference §3.3–§3.5 (`hypotheses`, `supports`, `chooseOffer`, the `speak` dial).

Spec: `GET /hypotheses/:userId?goalId=<id>` (extends BE1.4's listing): open hypotheses (`stored | offered`) whose `supports` include a pattern in this goal's snapshot links, or an answer/fact whose evidence includes one of the goal's linked items; at most one, the one `chooseOffer` would pick; `[]` when `readHypothesisDial().speak` is false. Showing it on GL-2 counts as an offer (`markOffered`, the 14-day spacing and two-offer limit apply).

Tests: `a hypothesis resting on the goal's pattern is listed for that goal` · `nothing is listed while the dial is off` · `a hypothesis offered twice is never listed again` · two-user test.

Watch out: the dial is the founder's (D11); never flip it in code or a migration.

---

### BE4.2 · Doors: "not for this goal", and the guess on GL-2                size: M
Place in the tree: goals › one goal › `POST|DELETE /v2/goals/:id/did/:itemId/remove`, `guess` in `GET /v2/goals/:id`
Repo · branch: backend · `be/BE4.2-goal-evidence`
Needs: BE4.0c, BE4.0f, BE4.1a      Unblocks: UIG.3, P17.2 (live)

Why: GL-2's evidence can be corrected, and its one guess appears there with what it rests on.

Inputs: contract 04 §3, §6; contract 02 §4 (`restsOn` resolved to text, BE1.4's resolver); fixtures `did.remove.response.json`, `goal.detail.json`.

Spec:
- `POST /v2/goals/:id/did/:itemId/remove` and `DELETE …`: ownership of the goal first; agent call (timeout 8 s, retry `none`); return `{ removed, card }` with the card built by BE4.1a's mapper. Idempotent: a repeat returns the same body.
- `GET /v2/goals/:id`: adds `guess` from agent `GET /hypotheses/:userId?goalId=` resolved with BE1.4's `restsOn` resolver; omitted when empty.
- Buckets: write for remove, read for the detail.

Tests (door suite, plus): `removing an item returns the recounted card` · `removing twice returns the same result` · `undo restores the count` · `the guess is omitted while speaking is off` · `a guess rests on readable text` · `you can't remove an item from someone else's goal`.

---

### BE4.0d · "Is that a goal?" from your stated words                      size: M
Place in the tree: goals › answer Retro's questions › brain › suggestions
Repo · branch: agent · `agent/BE4.0d-goal-questions`
Needs: BE4.0b      Unblocks: BE4.4, BE4.0e

Why: when you keep saying you want something but never named it as a goal, Retro asks, quoting your own words, and never asks about the same words twice.

Inputs:
- Contract: 04 §1 (`GoalQuestion`), §5, §9 Q3
- Reference: agent-api-reference §10.2 (`assertions`, `stated_goal`, `assertion_evidence.excerpt`, `char_start/char_end`), §3.5 (`product_dials`)
- Code anchors: `src/brain/pulls.ts:146-168` (`goalsVsBehavior`, `currentTruth({ predicate: 'stated_goal' })`), `src/agents/fact-extractor.ts:56` (how `stated_goal` is extracted), `src/goals/lifecycle.ts` (`DUPLICATE`, `cosine`)

Spec:
- Migration `<n>_goal_questions.sql`: `goal_questions (id uuid PK, user_id, kind text CHECK ('is_this_a_goal','still_on_it'), assertion_id → assertions NULL, goal_id → goals CASCADE NULL, quote text, quote_raw_content_id uuid, status text CHECK ('open','yes','not_quite','expired') default 'open', outcome_goal_id uuid NULL, created_at, answered_at)`; unique `(user_id, assertion_id)` so a fact is asked about once, ever. Seed dial row `goal_questions` = `{ "speak": false, "per_day": 1 }`.
- Engine `src/goals/questions.ts` `proposeGoalQuestions(userId)` (daily, after BE4.0a): active `stated_goal` facts with at least one `assertion_evidence` row from the person's **own words** whose `excerpt` is non-empty and appears verbatim in that entry; not similar (> `DUPLICATE`, by the goal embeddings already stored, or `isMentioned` when no vector) to any goal in any status; not already asked. Question text = template `you keep saying <paraphrase>. is that a goal?` **only** when there are ≥ 2 supporting own-words entries, else `you said "<quote>". is that a goal?`. `<paraphrase>` is the fact's own `object_value` text, lowercased, never model-rewritten. Max one open `is_this_a_goal` at a time.
- Routes: `GET /goals/:userId/questions` → open questions (respects the dial: `[]` when `speak` false); `POST /goals/:userId/questions/:id { answer: 'yes'|'not_quite' }` → `{ outcome, goalTitle? }` and marks the row; a repeat returns the stored outcome. A question whose entry was deleted (BE1.5b's forget) or whose fact was retired → `expired`.
- `yes` on `is_this_a_goal` returns `goalTitle` = the fact text (the door creates the goal through BE4.1b's path, origin `question`, `first_quote` = the quote).

Tests: `a goal you only mentioned is asked about with your exact words` · `two entries make "you keep saying"; one makes a quote` · `something already a goal is never asked` · `a declined fact is never asked again` · `nothing is asked while the dial is off` · `a question whose entry was deleted expires` · `answering twice returns the same outcome` · two-user test · role-switched write test.

Watch out: never ask about health, sexuality, religion or money unasked (guess-card rule): skip facts whose domain is in the brain's restricted set (`trust.ts`), and add a test.

---

### BE4.4 · Door: yes / not quite on Retro's questions                    size: M
Place in the tree: goals › answer Retro's questions › `POST /v2/goals/questions/:id`, `questions` in `GET /v2/goals`
Repo · branch: backend · `be/BE4.4-goal-questions`
Needs: BE4.0d, BE4.1b      Unblocks: PL3.5b, P16.2 (live), BE4.3

Why: one tap answers Retro, and the goals list changes at once in the way you'd expect.

Inputs: contract 04 §1, §2 (`questions`), §5; fixtures `question.answer.*.json`, `goals.list.json`, `goals.list.checkin.json`.

Spec:
- `GET /v2/goals` adds `questions` from agent `GET /goals/:userId/questions` (a `still_on_it` wins over `is_this_a_goal`; at most one); each question's text passes `assertNoVerdict`.
- `POST /v2/goals/questions/:id { answer: 'yes' | 'notQuite' }`, `Idempotency-Key` required. Maps per contract §5: `is_this_a_goal` + yes → creates the goal through BE4.1b's service (key derived from the question id, so a retry can't make two) → `goalCreated`; + notQuite → `declined`. `still_on_it` + yes → `updateGoal(active, revive)` (stated again) → `kept`; + notQuite → `lifecycleFor(false)` → `turnedOff`. Unknown or expired question → `not_found`.
- Buckets `write`.

Tests (door suite, plus): `yes on is-that-a-goal creates exactly one goal even when retried` · `not quite declines and the question never returns` · `yes on a check-in restates the goal and restarts its two weeks` · `not quite on a check-in turns the goal off` · `an expired question is not found` · `the list carries at most one question, a check-in first` · fixtures validate.

---

### BE4.0e · Quiet goals become check-in questions                         size: M
Place in the tree: goals › check-ins › brain
Repo · branch: agent · `agent/BE4.0e-goal-checkins`
Needs: BE4.0d (the `goal_questions` table)      Unblocks: BE4.3

Why: before a goal quietly fades, Retro asks once whether you're still working toward it, instead of deciding for you.

Inputs: contract 04 §7, §9 Q4; code anchors `src/goals/lifecycle.ts:19` (`EXPIRE_DAYS` 90), BE4.0a's snapshot.

Spec:
- `proposeCheckins(userId, now)` (daily, after BE4.0a and before `applyGoalLifecycle` would expire anything): an active goal stated ≥ 21 days ago, with no mention and no did link in the last 21 days, no `still_on_it` question for it in the last 28 days; at most one new check-in per person per 7 days; the goal whose fade date is nearest wins. Writes a `still_on_it` row with question text `still working toward this?`.
- Constants `CHECKIN_QUIET_DAYS = 21`, `CHECKIN_REPEAT_DAYS = 28`, `CHECKIN_PER_WEEK = 1` in one exported object.
- Route `GET /goals/:userId/checkins/due` → `[{ questionId, createdAt }]` (ids only) for the backend's push sender; open check-ins not yet pushed. `POST /goals/:userId/checkins/:id/pushed` marks it.
- An open check-in expires after 14 days; the goal's normal 90-day fade is untouched.

Tests: `a goal quiet for three weeks gets one check-in` · `a goal mentioned last week gets none` · `never more than one check-in a week` · `a goal asked about in the last four weeks isn't asked again` · `a check-in never says anything but the fixed question` · two-user test.

---

### BE4.3 · The check-in push and its switch                                 size: M
Place in the tree: goals › check-ins › push sender, `GET|PUT /v2/goals/checkins`
Repo · branch: backend · `be/BE4.3-checkin-push`
Needs: BE4.0e, BE2.7 (the push sender and device rules), BE4.4, BEA.4      Unblocks: PL3.5d

Why: if you want them, check-ins reach you as a quiet notification at a sensible hour, and nothing on your lock screen says what your goal is.

Inputs: contract 04 §7; fixtures `checkins.request.json`, `checkins.response.json`, `push.checkin.json`; backend-reference (BE2.7's sender once written).

Spec:
- Migration (backend schema): `users.goal_checkins_enabled boolean NOT NULL DEFAULT false`.
- `GET /v2/goals/checkins` → `{ enabled }`; `PUT { enabled: boolean }` (strict) → `{ enabled }`. Bucket `write`.
- **Sender** (a backend job every 15 min, behind `ENABLE_GOAL_CHECKIN_PUSH`, default off): for users with the switch on and a registered device, asks agent `GET /goals/:userId/checkins/due`, and sends at most one push per user per 7 days, only when the user's local time (from `users.time_zone`) is 10:00–20:00, through BE2.7's sender with exactly `push.checkin.json`'s payload (no goal words), then marks it pushed. With the switch off, the check-in still appears on GL-1; only the push is skipped.
- Logs: counts per run (users considered, sent, skipped by hour, skipped by week); never titles.

Tests: `no push when the switch is off` · `no push outside ten to eight local time` · `never two pushes in a week` · `the payload carries no goal words` (scans the payload against the goal titles) · `a pushed check-in isn't pushed again` · the switch's door suite.

Watch out: sending a push is outward: the job flag stays off in production until the founder says so (rule 8).
