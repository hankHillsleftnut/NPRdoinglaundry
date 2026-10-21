# Backend · phase A cards: agent hardening

Bugs a door would otherwise carry straight to the app (agent-api-reference, "Read this first" and §1–§11). Each is one agent PR whose test **fails before the change and passes after**; the PR shows both runs. Agent repo, branches `agent/BEA.n-<slug>`. Next migration number and assignments: see phase-0.md.

---

### BEA.1 · Corrections can write, the way the brain intends              size: M
Place in the tree: brain › corrections › applying a correction
Needs: —      Unblocks: BE1.7 ("not right")

Why: correcting an answer fails in production today, after part of the correction has already been written, so "not right" would half-work.

Inputs:
- Reference: agent-api-reference §4.3 (what applying writes), §10.4 (question store; service role SELECT only), §12.1 (PGlite runs as superuser)
- Code anchors: `src/corrections/apply.ts:74-108`; `supabase/migrations/121_question_answers.sql:428-433` (the comment says "No direct writes from anyone, including the backend's service key" and grants service_role SELECT only); `record_answer(jsonb)` and `record_answer_verdict(user, answer, verdict)` (121); `tests/migrations.test.ts` (the only test that uses `SET ROLE service_role`)

Spec:
- **Don't grant UPDATE** (it would break 121's design that every answer write goes through a function). Add migration `152_correction_writes.sql` with two `SECURITY DEFINER` functions, owned like `record_answer`, `search_path` pinned, executable by `service_role` only: `retire_answer(p_user uuid, p_answer uuid, p_reason text, p_reject boolean)` (sets `status='retired'`, `retired_at`, `retirement_reason`, and when `p_reject` the verdict `rejected` via the same rules as `record_answer_verdict`) and `retire_answer_evidence(p_user uuid, p_evidence_ids uuid[])` (sets `retired_at`); both scoped by `p_user` and no-ops on rows of other users.
- `apply.ts`: replace the direct `.update()` calls on `question_answers` and `answer_evidence` with these RPCs; run the whole application in one transaction (an RPC `apply_correction(jsonb)` that wraps the steps, or ordering that writes `claim_rejections` last), so a failure leaves nothing half-applied.

Acceptance: correcting an answer under `service_role` succeeds and retires exactly the planned claims; a forced failure in the middle leaves no partial writes.

Tests:
- `correcting an answer works under service_role` (`SET ROLE service_role` before the call; fails on main today with 42501)
- `a failure halfway leaves the correction unapplied`
- `retire_answer can't touch another user's answer`
- `rejecting an answer keeps it retired if a writer recreates it` (148's trigger still holds)

Proof: the failing run on main and the passing run, in the PR.

Watch out: production must get migration 152 before BE1.7's door ships; the integrator sequences that with the founder.

---

### BEA.2 · Every query scoped to its user                                size: M
Place in the tree: brain › isolation
Needs: —      Unblocks: BE1.6, BE1.7, BE3.1, BE3.2, BE5.x

Why: four routes and two engine functions can read or act on another person's data if handed their ids.

Inputs:
- Reference: agent-api-reference §4.2 (confirm doesn't check ownership), §8.1 (feedback GET unscoped, POST unchecked), §9.3 (`factsAbout` interpolates `entityId`; several sub-queries unscoped), §9.4 (`walkEvidence` has no user filter)
- Code anchors: `src/routes/feedback.ts:11-37`; `src/routes/corrections.ts:27-32`, `src/corrections/retract.ts:39`; `src/brain/lineage.ts:31-64`; `src/brain/pulls.ts:123-140` (`factsAbout`, the `.or()` string at `:131`), `:248-249`, `:377-379`, `:417-428`

Spec:
- Feedback: `GET` requires `userId` and filters by it; `POST` checks the episode belongs to the user first (404 otherwise).
- `corrections/confirm`: check the target claim belongs to the user before planning; otherwise 404 `{ error: 'not found' }`.
- `walkEvidence(claim, db?, userId)`: a required `userId`; the starting claim must belong to the user; every step filtered by `user_id`.
- `factsAbout`: validate `entityId` as a UUID and use parameterised filters (`.eq` / `.in`), never string interpolation into `.or()`.
- The `pulls.ts` sub-queries listed: add `user_id` filters (defence in depth, even where ids came from user-scoped rows).

Tests (two users each): `a user can't read another user's episode feedback` · `feedback can't be attached to someone else's episode` · `confirming another user's claim is not found and retires nothing` · `walking evidence from another user's claim returns nothing` · `factsAbout refuses a non-UUID entity id` · `pulls sub-queries only see the user's rows`.

---

### BEA.3 · Preferences merge instead of replacing                         size: S
Place in the tree: brain › settings › preferences
Needs: —      Unblocks: BE6.1

Why: saving one preference today wipes the others, including the episode feedback folded into `directives` (agent-api-reference §8.3).

Spec: `PATCH /preferences/:userId` with merge semantics over `tone`, `trusted_voice_description`, `focus_areas`, `avoid_topics`, `directives` (validated with zod: lengths, array caps); `GET` returns the row without `metadata` (internal appetite and learning state). `PUT` stays for compatibility.

Tests: `patching tone keeps directives` · `the GET no longer exposes internal metadata` · `invalid shapes are a 400`.

---

### BEA.4 · Every model call counted, and the cap enforced                 size: M
Place in the tree: brain › cost › spend ledger
Needs: —      Unblocks: BE0.11, every `expensive` door, BE0.S's staging cap

Why: the per-user daily cap (default $15) only sees podcasts and research; conversation, search, corrections, briefs over HTTP, onboarding and notifications aren't counted (agent-api-reference "Read this first", spend cap).

Inputs: `src/pipelines/spend-guard.ts:20-43`, `src/pipelines/trace.ts:345-359` (`CostLine`), each route's `usage` handling (stripped in conversation, corrections, search answer).

Spec:
- Migration `153_spend_ledger.sql`: `spend_ledger (id, user_id → users cascade, at timestamptz, kind text, usd numeric(10,6), model text, is_test bool default false)`; index `(user_id, at)`.
- A `recordSpend(userId, kind, costLines)` helper called by every model-calling path (the routes above, the brief jobs, onboarding interpret/goals/advance, notifications); `spend-guard` sums the ledger plus the existing two sources.
- Enforcement: model-calling routes check the cap first and return `429 { error: 'spend_limited', spentUsd, capUsd }`. **Reads are never refused** (founder rule). `STAGING_DAILY_CAP_USD` adds a project-wide cap when `RETROSPECT_ENV=staging`.
- `POST /briefs/generate` honours `users.daily_brief_enabled` (a 409 `{ error: 'briefs are off for this person' }` when off and not a dry run).

Tests: `every model-calling route records its cost` (a table-driven test over the routes with injected models) · `over the cap a model route is refused and a read is not` · `briefs/generate respects the switch` · `the staging cap stops everyone in staging only`.

---

### BEA.5 · One first pass at a time                                        size: S
Place in the tree: brain › onboarding › advance
Needs: —      Unblocks: BE2.1

Why: "one episode per onboarding, never two" (founder rule); today an app poll and the cron can both run a first pass or an episode at once (agent-api-reference §6.4).

Spec: a database advisory lock per user (`pg_try_advisory_xact_lock(hashtext('onboarding:' || user_id))`) shared by the route and the cron (`src/jobs/onboarding-pipeline.ts:18`'s in-process lock stays as a fast path); when the lock is taken the route returns `{ stage, action: 'already_running' }`.

Tests: `two advances at once run one first pass` · `the cron and the route never both make an episode`.

---

### BEA.6 · Bad JSON is a 400                                                 size: S
Place in the tree: brain › server
Spec: the global error handler (`src/index.ts:74-79`) honours `err.status` / `err.type === 'entity.parse.failed'` (400 `{ error: 'invalid json' }`) and `entity.too.large` (413), and never returns raw Postgres messages (log them, answer `{ error: 'internal' }`).
Tests: `malformed JSON is a 400` · `a database error message never reaches the caller`.

---

### BEA.7 · Private audio, signed links                                     size: M
Place in the tree: brain › audio storage
Needs: —      Unblocks: BE1.3b, BE2.5b, BE3.x

Why: episode audio is a public, permanent URL with the user's id in the path (agent-api-reference §7.3).

Spec:
- Migration `154_podcast_audio_paths.sql`: `podcast_episodes.audio_path text` (the object path); backfill from `audio_url` by stripping the public prefix.
- Pipelines (`src/pipelines/podcast.ts:522-532`, `podcast-v2.ts:87-89`) store `audio_path` and stop calling `getPublicUrl`; `audio_url` stays written for old app versions until X07.
- A helper `signedAudioUrl(path, ttlSeconds = 3600)` used by every route that returns audio to the backend (episodes, briefs).
- **Founder-approved production step** (listed in the PR, done by the integrator with the founder): switch the `podcast-audio` bucket to private after the old app no longer needs public URLs (sequenced with X07), or immediately if the old app's playback is retired first.

Tests: `new episodes store a path, not a public URL` · `the backfill derives the right path` · `signed links expire`.

---

### BEA.8 · Quiet weeks are a state, not an error                           size: S
Place in the tree: brain › podcasts › generate
Spec: `runPodcastV2` returns `{ outcome: 'quiet_week' | 'nothing_safe_to_say' | 'made', … }`; the route returns 200 with `outcome` and no episode for the first two (today they're 500s, agent-api-reference §7.1); the v2 response includes `outlineV2`'s replacement (`plan`) and the guard stats.
Tests: `a quiet week is a 200 with outcome quiet_week` · `a fully cut script is nothing_safe_to_say` · `a made episode still returns its id and plan`.
