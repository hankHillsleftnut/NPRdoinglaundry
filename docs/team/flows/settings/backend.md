# Settings and account · backend cards (brain bytes and doors)

The tree for this side: **settings** › settings reads and writes (BE6.1a–i) › brief time (BE6.2a–c) › export (BE6.3a–c) › account summary (BE6.4) › sources (BE6.5a–d) › deletion amendments (BE6.6a–c) › notification settings (BE6.7). Contract: [../../contracts/06-settings.md](../../contracts/06-settings.md). The phase-0 deletion cards **BE0.5, BE0.6, BE0.7, BE0.8, BE0.13** are in [../../backend/phase-0.md](../../backend/phase-0.md) and are not repeated here; the BE6.6 cards are the changes this area needs of them (README §9).

Every door is built with the kit (BE0.1), passes the door suite (BE0.2: the nine tests, including "another user's id → 404"), and the invite gate (BE0.12). Every agent route gets a two-user PGlite test and, when it touches SQL, runs as `service_role` (BEA.1, testing.md layer 2). Fixtures: the backend validates every `fixtures/06/*.json` response against the door's zod output schema (layer 4). Logs: door, userId, status, ms, and enum values only; never a setting's free text, a source's error message, a link, or an export URL.

**Migration numbers** (proposed; the integrator confirms in phase-0.md): agent `158_user_settings.sql` (BE6.1a), `159_ambient_dial.sql` (BE6.1d), `160_data_exports.sql` (BE6.3a); backend `013_deletions.sql` (BE0.7's table, per BE6.6b). House style as phase-0: additive, header comment, RLS on, `REVOKE ALL … FROM PUBLIC, anon, authenticated`, `GRANT … TO service_role`. Files only; never applied to production by an agent.

Order (agent first, then its door): BE6.1a → BE6.1b, BE6.1d → BE6.1e → BE6.2a → BE6.1f, BE6.1g → BE6.1c → BE6.1h → BE6.1i → BE6.2b → BE6.5a → BE6.5b → BE6.5c → BE6.5d → BE6.3a → BE6.3b → BE6.3c → BE6.6c → BE6.2c. BE6.7 (notification settings) runs any time after BE6.1e. The App Store lane (BE6.4, BE6.6a, BE6.6b) runs first whenever the founder pulls it forward (README §6).

---

### BE6.1a · Brief and voice settings: columns and agent routes          size: M
Place in the tree: settings › brief, voice › agent `GET|PUT /settings/:userId/brief`, `GET|PUT /settings/:userId/voice`
Repo · branch: agent · `agent/BE6.1a-brief-voice-settings`
Needs: —      Unblocks: BE6.1e, BE6.1g, BE6.2a, BE6.2b, BE6.2c

Why: the time you pick for your brief, its length, your voice and its speed are remembered once, on the server, so a new phone or a reinstall keeps them.

Inputs:
- Contract: 06 §2 (`BriefSettings`, `VoiceSettings`)
- Reference: agent-api-reference §2.3 (`PUT /briefs/:userId/enabled`, "anything other than `true` becomes false"), §8.2 (settings routes' style), §10.7 (`users.voice_persona`, `daily_brief_enabled`)
- Code anchors: agent `src/routes/settings.ts:12-45` (the pattern to follow), `src/routes/briefs.ts:28-33`, `src/services/elevenlabs.ts` (`VOICE_PERSONAS`)

Spec:
- Migration `158_user_settings.sql`: `users.brief_time text not null default '08:00' check (brief_time ~ '^([01][0-9]|2[0-3]):(00|15|30|45)$')`, `users.brief_length text not null default 'standard' check (brief_length in ('short','standard','long'))`, `users.playback_speed numeric(3,2) not null default 1.00 check (playback_speed in (0.80, 1.00, 1.25, 1.50))`. `users.time_zone` comes from backend BE0.4 (same table): this migration reads it only, never adds it; the PR states which repo owns which column.
- `GET /settings/:userId/brief` → `{ enabled, time, length, timeZone }` (`timeZone` may be null until the app has sent one). `PUT /settings/:userId/brief { enabled?: boolean, time?: string, length?: 'short'|'standard'|'long' }`: strict validation (400 `{ error }` for anything else, including a non-boolean `enabled`), at least one field, a single `update … returning`.
- `GET /settings/:userId/voice` → `{ persona: 'thoughtful_friend'|'wise_mentor'|'energetic_host', speed }`; `PUT /settings/:userId/voice { persona?, speed? }` strict; writes `voice_persona` and `playback_speed`.
- Unknown user → 404 `{ error: 'user not found' }` on both PUTs (the existing routes return 200 for unknown users; these don't copy that).
- `nextAt` isn't computed here: the door computes it (BE6.2a) from `time` and `timeZone`, because the backend owns the request's time zone.

Steps: migration → routes → two-user tests → service_role test.

Acceptance: a brief time set to 08:30 reads back as 08:30; 08:10 is refused; a speed of 2 is refused; another user's settings never change.

Tests (layer 1–2):
- `brief settings round-trip and refuse times off the quarter hour`
- `voice settings round-trip and refuse an unknown persona or speed`
- `writing one user's settings leaves another's untouched` (two users)
- `an unknown user is 404 on every write`
- `the routes work as service_role` (BEA.1 harness)

Proof in the PR: test output; the migration's header.

Watch out: the CHECK on `brief_time` must match the door's regex exactly (one constant in the door, one in SQL; a test compares them via fixtures). Don't touch the 08:00 UTC cron here (BE6.2b).

---

### BE6.1b · "Picked by retro" in plain words                                size: S
Place in the tree: settings › straight and learned › agent `GET /settings/:userId/appetite` (`why`)
Repo · branch: agent · `agent/BE6.1b-appetite-why`
Needs: —      Unblocks: BE6.1e, BE6.1f, P28

Why: when Retro chose how straight to be, ST-6 can say why in one sentence you'd accept ("you answer the hard questions, and say 'not quite' when i'm wrong."), never an internal note like "stays at 0: 1 engagement signal(s)".

Inputs:
- Contract: 06 §2 (`Straightness.why`)
- Code anchors: agent `src/appetite/appetite.ts:12-17` (`LEVELS`), `:31-46` (`inferLevel` reasons), `:89-112` (`readSignals`: what counts as engaged or discomfort)

Spec:
- Store the signal **kinds** behind the last inference, not just the reason string: `inferLevel` returns `{ level, reasons, basis: { engagedKinds: Kind[], discomfortKinds: Kind[] } }` where `Kind` is `confirmedAnswer | recognisedGuess | ratedHigh | rejectedClaim | rejectedWhy | declinedGuess | ratedLow`; `refreshAppetite` saves `basis` beside `reasons`.
- `src/appetite/why.ts`: `plainWhy(reading, basis): string | null`, a pure template function, **no model**:
  - stated → `null` (the person chose; ST-6 shows no note);
  - inferred at 0 with no basis → `"i start with just what happened, until i know how you like it."`;
  - rose → names up to two engaged kinds in plain words ("you answer the hard questions", "you say 'not quite' when i'm wrong", "you said yes to something i wondered");
  - dropped → names the discomfort kind ("you turned down a guess of mine, so i've eased off.").
  - Copy is lowercase, at most 120 characters, with no numbers and no level names.
- `GET /settings/:userId/appetite` adds `why`. The door maps it (BE6.1e); existing fields stay.

Steps: basis in `inferLevel` → saved → `plainWhy` → route field → tests.

Acceptance: every combination of level and basis gives a sentence from the approved list, or null when stated.

Tests (layer 1): `a stated level has no why` · `a first reading says it starts with just what happened` · `a rise names what engaged, never a number` · `a drop names the discomfort` · `why never contains a level name or the word "signal"` (property test over every basis) · `old rows without basis still read` (backwards compatible).

Proof: test output, with the full table of sentences in the PR body for the founder.

Watch out: the founder approves the sentence list (copy); ship with the lean set and mark the PR "copy to confirm".

---

### BE6.1c · What i've learned, in sentences                                 size: M
Place in the tree: settings › straight and learned › agent `GET /settings/:userId/learning/summary`
Repo · branch: agent · `agent/BE6.1c-learning-summary`
Needs: —      Unblocks: BE6.1h, P30

Why: ST-8 tells you, in one sentence and one why, how Retro is adjusting its questions to you, and says "too early" instead of inventing a lesson.

Inputs:
- Contract: 06 §3
- Reference: agent-api-reference §8.2 (`ArmStat = { arm, asked, answered, rate, weight }`; arms `why`, `hypothesis:<framework>`, `answer:<domainId>`; `inUse` = `ENABLE_LEARNING`)
- Code anchors: agent `src/learning/reception.ts:15, 85` (`readLearning`), the eight domain labels (`src/understanding/…`, `domain_coverage` view, §10.4)

Spec:
- `src/learning/summary.ts`: `summarise(learning, inUse, domainLabels): { state, headline, why, lastChangedAt }`, pure:
  - `inUse === false` → `off`, all null.
  - no snapshot, or total `asked` < 5 → `tooEarly`.
  - else: `headline` from the `answer:<domainId>` arm with the highest rate and `asked ≥ 3`: "you answer questions about {label} most, {answered} of {asked}."; `why` from the lowest-rate arm with `asked ≥ 3` and `weight` below 1: "you skip ones about {label} ({answered} of {asked}), so i ask those less." When the `why` arm is the hypothesis or why arm, use "guesses about why" / "questions about why" (never a framework id).
  - `lastChangedAt` = the current snapshot's `at`.
- `GET /settings/:userId/learning/summary` returns it. No writes; no model.

Steps: summary function → route → tests.

Acceptance: real counts only; a person with 4 questions asked sees "too early"; `ENABLE_LEARNING` off reads `off`.

Tests: `fewer than five questions is too early` · `learning off reads off` · `the headline uses the best-answered area with at least three asked` · `framework ids never appear` · `numbers in the sentences equal the counts` · two-user isolation on the route.

Proof: test output; a table of example outputs (invented counts) in the PR.

Watch out: domain labels must be the person-facing lowercase names (the eight areas YO-5 uses), defined once; if YO-5's contract (05) names them differently, the integrator picks one list.

---

### BE6.1d · The founder's master ambient switch, as a dial                  size: S
Place in the tree: settings › privacy › agent `product_dials.ambient`
Repo · branch: agent · `agent/BE6.1d-ambient-dial`
Needs: —      Unblocks: BE6.1e, BE6.1f, BE6.1i

Why: the founder can stop (and restart) all background reading for everyone in one tap, without a redeploy ("have an on/off switch so I can turn off the ambient and turn on the ambient for every user", 20 Oct).

Inputs:
- Reference: agent-api-reference §3.5 (`product_dials`, read on every use, no cache)
- Code anchors: agent `src/ambient/switch.ts:16` (`masterOff` reads env `AMBIENT_MASTER`), `:19-33` (`ambientOffAmong`)

Spec:
- Migration `159_ambient_dial.sql`: insert `product_dials` row `('ambient', '{"master": "on"}', 'founder master switch for background reading')` on conflict do nothing.
- `masterOff(env, dial)`: off when **either** env `AMBIENT_MASTER=off` **or** the dial says `"off"` (env stays as the emergency brake). Read the dial once per job run (cache 60 s in memory) so a sweep over many users makes one read.
- Agent internal routes: `GET /dials/ambient` → `{ master: 'on'|'off', source: 'dial'|'env' }`, `PUT /dials/ambient { master }` (internal secret; the backend admin is the only caller).
- `GET /settings/:userId/ambient` adds `pausedForEveryone: masterOff()`.

Acceptance: turning the dial off makes `effective` false for every user within a minute and stops every ambient job at its next check; env off still wins over a dial that says on.

Tests: `the dial off pauses everyone` · `env off wins over the dial` · `a missing dial row means on` · `a sweep over 500 users reads the dial once` · `pausedForEveryone appears in the settings read`.

Proof: test output.

Watch out: every ambient job already calls `ambientOffAmong`; this byte changes only `masterOff`, so no job needs editing. Grep proves it in the PR.

---

### BE6.1e · `GET /v2/settings`                                               size: M
Place in the tree: settings › foundations › door `GET /v2/settings`
Repo · branch: backend · `be/BE6.1e-settings-read`
Needs: BE0.1, BE0.2, BE0.12, BE6.1a, BE6.1b, BE6.1d      Unblocks: PL3.7a, P23–P29 live

Why: opening settings shows every current value at once (ST-1's "8:30", "warm", "honest"), in one quick request.

Inputs:
- Contract: 06 §2; fixtures `settings.json`, `settings.minimal.json`, `settings.paused-for-everyone.json`
- Reference: agent-api-reference §8.2, §2.3
- Code anchors: backend `src/services/agent-client.ts:41-123` (`callAgent`; extend with `GET` as BE0.1 does)

Spec:
- Four agent reads in parallel (`/settings/:id/brief`, `/ambient`, `/appetite`, `/voice`), timeout 5 s each, retry `read` (one retry with jitter). Any failure → the whole door fails with `upstream_timeout` or `upstream_unavailable` (never a partial settings object).
- Mapping (one exported function per part, unit-tested):
  - brief: `nextAt` = the next instant at local `time` in `users.time_zone` (today's if still ahead, else tomorrow's); `null` when off or no time zone yet.
  - ambient: `{ enabled, effective, pausedForEveryone }`.
  - straightness: level 0..3 → `justWhatHappened | gentleQuestions | honestObservations | dontHoldBack`; `source` stated → `yours`, inferred → `picked`; `why` from BE6.1b (null when yours). The brain's `levels` texts and `suggested` are **not** passed (onboarding's, contract 01).
  - voice: persona ids → `warm | steady | bright` (one map; unknown → `unknown` and logged); `personas` in that order with lowercase names (Q3).
  - notifications: from the backend's own `notification_settings` row (BE6.7; defaults when absent). Until BE6.7 merges, the door returns the defaults.
- Bucket `read`; owner: the user from the token only.

Acceptance: the three fixtures are what the door returns for matching brain states; a slow brain answers `upstream_timeout` within 6 s.

Tests (door suite, plus): `nextAt is tomorrow when today's time has passed, in the person's zone` (UTC−8 at 23:00) · `nextAt is null when the brief is off` · `a stated level has source yours and no why` · `an unknown persona decodes as unknown and is logged` · `one failed part fails the whole read` · fixtures validate.

Proof: test output; a local-staging read for a test account (values only, no content).

Watch out: daylight-saving days: compute `nextAt` with a real zone library (`Intl` / `Temporal` polyfill already in the repo, or `date-fns-tz`; the PR names which), and test the spring-forward gap (02:30 doesn't exist).

---

### BE6.1f · `PUT /v2/settings/ambient` and `PUT /v2/settings/straightness`   size: S
Place in the tree: settings › privacy, straight › doors
Repo · branch: backend · `be/BE6.1f-ambient-straightness`
Needs: BE6.1e      Unblocks: PL3.7a, P27, P28 live

Why: the ambient switch and the four "how straight" choices apply the moment you tap them.

Inputs: contract 06 §2; fixtures `ambient.put.request.json`, `ambient.response.json`, `straightness.put.request.json`, `straightness.response.json`; agent `src/routes/settings.ts:12-17, 34-39`.

Spec:
- Ambient: zod `{ enabled: boolean }` strict → agent `PUT /settings/:id/ambient` (timeout 5 s, retry `none`; it's idempotent, but the app coalesces) → map as BE6.1e.
- Straightness: zod `{ level: enum | null }` → level number or null → agent `PUT /settings/:id/appetite` → map. The agent 500s for a user with no `user_preferences` row on insert races: the door maps any agent 5xx to `upstream_unavailable`.
- Bucket `write`.

Acceptance: both match their fixtures; `{ "enabled": "yes" }` is `invalid_request`; `level: null` returns `source: picked` with a why.

Tests (door suite): `ambient off then on reads back each time` · `straightness null hands back to retro` · `a non-boolean ambient is invalid_request` · fixtures validate.

Proof: test output.

Watch out: don't forward the agent's 400 text; it says "enabled (true/false) required" in its own words.

---

### BE6.1g · `PATCH /v2/settings/voice` and the voice samples                size: S
Place in the tree: settings › voice › doors
Repo · branch: backend · `be/BE6.1g-voice`
Needs: BE6.1a, BE6.1e; the three sample files (integrator records them once from the ElevenLabs voices, test spend logged)      Unblocks: PL3.7a, C44, P29 live

Why: you can hear each voice before you choose it, and pick how fast briefs and episodes play.

Inputs: contract 06 §2; fixtures `voice.patch.request.json`, `voice.response.json`, `voice.sample.json`; backend `src/services/voice-personas.ts` (the three persona voice ids), backend-reference §12 (speech ignores persona today).

Spec:
- `PATCH /v2/settings/voice { persona?, speed? }` → agent `PUT /settings/:id/voice` (contract names mapped back to persona ids) → `{ voice }`.
- `GET /v2/settings/voice/samples/:persona`: `persona` in the enum, else `not_found`; signs `voice-samples/<persona>.mp3` in a new private bucket `voice-samples` (created by the PR's migration-free setup script for staging; production creation is a founder-approved step, listed in the PR) for 1 hour; `durationSeconds` from a constant table checked in with the files' measured lengths.
- The sample files are not generated per request (no spend); the script that recorded them lives in `scripts/record-voice-samples.ts` and is run once by the integrator.
- Buckets: patch `write`, sample `read`.

Acceptance: the fixtures; a sample URL plays in a browser for an hour and then fails.

Tests: `persona names map both ways` · `an unknown persona sample is not_found` · `the sample link expires in an hour` · `speed outside the four values is invalid_request` · fixtures validate.

Proof: test output; the bucket's policy (private) in the PR.

Watch out: the old `PATCH /profile/persona` keeps writing the same column for old screens until X07; both are set-to-value, so the last write wins and neither breaks the other.

---

### BE6.1h · `GET /v2/settings/learned`                                       size: S
Place in the tree: settings › straight and learned › door
Repo · branch: backend · `be/BE6.1h-learned`
Needs: BE6.1c, BE0.1      Unblocks: PL3.7a, P30 live

Why: ST-8 shows what Retro has learned about your questions, or says plainly that it's too early.

Inputs: contract 06 §3; fixtures `learned.json`, `learned.too-early.json`, `learned.off.json`.

Spec: agent `GET /settings/:id/learning/summary` (timeout 5 s, retry `read`) → pass `state`, `headline`, `why`, `lastChangedAt` (dates normalised to contract 00's format). An unknown `state` → `unknown` and logged. Bucket `read`.

Acceptance and tests: the three fixtures; `an unknown state from the brain maps to unknown`; the door suite.

Proof: test output.

Watch out: never add text in the door; the sentences are the brain's (BE6.1c), so they're tested in one place.

---

### BE6.1i · The master switch on the founder's dashboard                    size: S
Place in the tree: settings › privacy › admin
Repo · branch: backend · `be/BE6.1i-ambient-master-admin`
Needs: BE6.1d, BE0.0 (the hardened admin secret)      Unblocks: Q6's honest line on ST-5

Why: the founder turns background reading off or on for everyone from the dashboard, and sees which source (dial or the env brake) is in charge.

Inputs: backend-reference §13 (admin auth; header only after BE0.0), `/dashboard` (`public/dashboard.html`).

Spec: `GET /admin/ambient` → the agent's `GET /dials/ambient`; `POST /admin/ambient { master: 'on'|'off' }` → agent `PUT /dials/ambient`; a small dashboard section: current state, source, one toggle with a confirm ("this pauses background reading for every person"). The action is logged as an admin event (who: "founder", what: on/off, when). No per-user data shown.

Acceptance: the toggle changes `pausedForEveryone` for every account within a minute.

Tests: `admin ambient needs the admin secret` · `posting off reaches the agent dial` · `an invalid value is refused`.

Proof: test output; a screenshot of the dashboard section on local staging.

Watch out: the admin secret never travels in a query string (BE0.0 removed that); the dashboard sends the header.

---

### BE6.2a · `PATCH /v2/settings/brief`                                       size: S
Place in the tree: settings › brief › door
Repo · branch: backend · `be/BE6.2a-brief-settings`
Needs: BE6.1a, BE6.1e      Unblocks: PL3.7a, P24 live

Why: turning the brief on, picking 8:30 and choosing its length all save at once.

Inputs: contract 06 §2; fixtures `brief.patch.request.json`, `brief.response.json`; contract 02 §3 (`PUT /v2/briefs/enabled`, BE1.3).

Spec:
- zod: at least one of `enabled` (boolean), `time` (the regex constant shared with BE6.1a's test), `length` (enum). → agent `PUT /settings/:id/brief` → map (`nextAt` as BE6.1e).
- BE1.3's `PUT /v2/briefs/enabled` is changed in this PR to call the same service function, so the two can't drift (a test calls both).
- Bucket `write`.

Acceptance: the fixtures; `{}` is `invalid_request`; turning on then reading `GET /v2/briefs/latest` shows `enabled: true`.

Tests: `an empty patch is invalid_request` · `08:10 is invalid_request` · `the journal's switch and this patch write the same field` · `nextAt follows the person's zone` · fixtures validate.

Proof: test output.

Watch out: a person with no `time_zone` yet (an old app never sent `X-Time-Zone`) gets `nextAt: null`, not a UTC guess.

---

### BE6.2b · The brief at your time: a per-minute local scheduler            size: M
Place in the tree: settings › brief › agent `src/jobs/daily-brief.ts`
Repo · branch: agent · `agent/BE6.2b-brief-at-your-time`
Needs: BE6.1a, BE1.3 (local-day `brief_date`), BEA.4      Unblocks: the outside plan's brief notification (it fires when the brief is made), the journal's "ready by 8:30"

Why: your brief is ready at the time you chose, in your time zone, once a day, never twice.

Inputs:
- Reference: agent-api-reference §2.2 (`POST /briefs/generate`), §2.4 (`daily_briefs` unique `(user_id, brief_date)`), cron at `src/index.ts:99-104` (08:00 UTC, `ENABLE_DAILY_BRIEF`)
- Code anchors: agent `src/jobs/daily-brief.ts:7-25` (spend-cap skip), `src/briefs/run-daily-brief.ts:93-146`

Spec:
- Replace the fixed cron with a minute tick (still behind `ENABLE_DAILY_BRIEF`): select users with `daily_brief_enabled`, a `time_zone`, and whose local wall time is within `[brief_time − 30 min, brief_time)` and who have no `daily_briefs` row for their **local** today. Start making it 30 minutes early so it's ready at `brief_time` (constant `LEAD_MINUTES = 30`).
- `brief_date` is the person's local date (this is where contract 02's "local day" becomes true; BE1.3 maps it unchanged).
- At most `BRIEF_CONCURRENCY = 4` briefs at once; a per-user advisory lock so two ticks never start the same brief; failures retry once at the next tick, then wait for tomorrow (logged as a count).
- Users without a `time_zone` fall back to 08:00 UTC (today's behaviour) until the app sends one.
- Spend cap and ambient rules unchanged (`spend-guard.ts`; ambient off still allows a brief from what the person sent).

Acceptance: a person in Los Angeles with 06:45 gets one brief dated their local day, made between 06:15 and 06:45 local; a restart mid-minute makes no duplicate.

Tests (layer 1–2, injected clock): `a brief starts thirty minutes before the chosen time, in the person's zone` · `two ticks in the same minute make one brief` · `the brief date is the local day across midnight UTC` · `no time zone falls back to 08:00 UTC` · `a person over the spend cap is skipped` · `daylight saving: the spring-forward day still makes one brief` · `two users' briefs never mix` (two users).

Proof: test output; a local-staging run with three test accounts in three zones (counts only).

Watch out: production switch-on is the founder's decision D10; the PR doesn't change the env. Index the select (`daily_brief_enabled`, `brief_time`) so the tick is cheap.

---

### BE6.2c · Brief length in the writer                                     size: S (only if Q1 = build)
Place in the tree: settings › brief › agent brief writer
Repo · branch: agent · `agent/BE6.2c-brief-length`
Needs: BE6.1a, BE1.3b (audio length is measured)      Unblocks: ST-2's length caption is true

Why: "short" really is short (about 2 minutes), "standard" about 4, "long" about 6.

Inputs: agent `src/briefs/run-daily-brief-v2.ts` (the writer's word budget), `src/services/elevenlabs.ts` (`estimateDuration`, 150 words a minute).

Spec: `BRIEF_WORDS = { short: 300, standard: 600, long: 900 }` passed to the v2 writer as its target, with the guard unchanged (a quiet day is still one line whatever the length). v1 briefs take the item count instead (`short` 2, `standard` 3, `long` 5). The measured duration (BE1.3b) is checked in a test against ±25%.

Acceptance: three test briefs land within ±25% of their target length.

Tests: `each length sets the writer's budget` · `a quiet day ignores length` · `an unknown length falls back to standard`.

Proof: test output; measured lengths of three staging briefs (test spend logged).

Watch out: cost per user (track-cost-per-user): add "long brief" to `cost-per-user.md` in the PR body as a lever.

---

### BE6.3a · Export my data: the builder                                    size: M
Place in the tree: settings › privacy › download my data › agent export job
Repo · branch: agent · `agent/BE6.3a-export-builder`
Needs: BEA.2 (every read scoped to the user)      Unblocks: BE6.3b, BE6.3c

Why: you can take a complete copy of everything Retrospect holds about you, in a form you can open.

Inputs:
- Contract: 06 §5
- Reference: agent-api-reference §10 (tables), backend-reference §9 (storage buckets and prefixes), BE0.6's bucket list
- Code anchors: agent `src/db/tables.ts`, `src/db/paged.ts` (`chunks`)

Spec:
- Migration `160_data_exports.sql`: `data_exports (id uuid pk, user_id → users on delete cascade, state text check in ('preparing','ready','failed','expired'), requested_at, ready_at, expires_at, size_bytes bigint, storage_path text, error_code text, idempotency_key text, unique (user_id, idempotency_key))`, partial unique index: one `preparing` per user.
- Agent `POST /users/:userId/export { idempotencyKey }` → creates or returns the row; a runner (same pattern as the integration jobs) builds the zip with a streaming zip writer into the private bucket `exports` at `<userId>/<exportId>.zip`:
  - `README.txt` (what each file is, in plain words), one JSON file per kind: `entries.json` (raw_content the person sent, with dates and kinds), `facts.json` (assertions + evidence ids), `answers.json`, `patterns.json`, `goals.json`, `briefs.json` (through-line / items as shown), `episodes.json` (title, date, script), `guesses.json`, `sources.json` (connections + what each read, as items), `settings.json`; audio: `audio/voice/…`, `audio/episodes/…`, `audio/briefs/…` copied from storage.
  - Every query pages 1,000 rows at a time and names its columns (never `select('*')`); **no embeddings**, no `pipeline_run_traces`, no internal metadata (`user_preferences.metadata` is excluded except the person's stated settings).
- `GET /users/:userId/exports/latest` → the row.

Acceptance: an export for a seeded user contains every kind listed and nothing of a second seeded user; the zip opens on macOS.

Tests: `an export holds every kind of the person's data` · `another user's rows and files never appear` (two users, same names) · `asking twice with one key returns one export` · `one preparing export per person` · `embeddings are never exported` (scan the zip) · `a very large account pages without loading everything into memory` (10,000 seeded rows, memory bound asserted).

Proof: test output; the file list of a staging export (names and counts only).

Watch out: storage `list()` returns 1,000 at most (loop). Build paths from the user id, never from listed names (BE0.6's rule).

---

### BE6.3b · Export lifecycle and the deletion sweep                       size: S
Place in the tree: settings › privacy › download my data › cleanup
Repo · branch: agent · `agent/BE6.3b-export-lifecycle`
Needs: BE6.3a, BE0.6      Unblocks: BE6.3c, the delete-account promise

Why: your export disappears after a week, and when you delete your data or your account, exports and brief audio go too.

Spec:
- Daily job: `ready` exports past `expires_at` → delete the file, mark `expired`; `preparing` older than 2 hours → `failed` (`error_code 'timeout'`).
- Extend BE0.6's `POST /users/:userId/delete` and BE0.8's `delete-data` sweeps with `exports/<userId>/` and `podcast-audio/briefs/<userId>/` (whichever path BE1.3b settled), and `voice-samples` is explicitly **not** swept (shared files).

Tests: `an export older than seven days is deleted and marked expired` · `deleting the account removes its exports and brief audio, and another user's stay` (two users) · `a stuck export fails after two hours`.

Proof: test output.

Watch out: if BE0.6 hasn't merged when this starts, add the paths in BE0.6's PR instead and close this half (tell the integrator).

---

### BE6.3c · Export doors                                                   size: M
Place in the tree: settings › privacy › download my data › doors
Repo · branch: backend · `be/BE6.3c-export-doors`
Needs: BE6.3a, BE6.3b, BE0.1      Unblocks: PL3.7c, C47, P27 live

Why: one tap starts your export, and when it's ready you save it from the app.

Inputs: contract 06 §5; fixtures `export.create.response.json`, `export.latest.ready.json`, `export.latest.none.json`, `error.rate_limited.json`.

Spec:
- `POST /v2/account/export` (Idempotency-Key required, UUID) → agent `POST /users/:id/export` → `{ export }` (201 new, 200 replay). A new export within 24 hours of the last `ready` or `preparing` one → `rate_limited` with `retryAfterSeconds`. Bucket `expensive`.
- `GET /v2/account/export/latest` → `{ export }`; when `ready`, `url` is a fresh 24-hour signed link from `exports`; otherwise `url: null`.
- When an export turns `ready`, the door emits an `export.ready` event for the outside plan's notification writer and sender (contract 07; founder, 21 Oct: every notification is written for the person and the moment, no generic copy), with `path: "/settings/privacy"`. Until that sender exists, nothing is sent and the page shows it next time.

Acceptance: the fixtures; a second request the same day is rate-limited; the URL works for 24 hours.

Tests (door suite): `a repeated request with one key returns the same export` · `a new export within a day is rate_limited` · `the link is fresh on every read and absent until ready` · `another person's export is not_found` · fixtures validate.

Proof: test output; a staging download (size only).

Watch out: never log the signed URL.

---

### BE6.4 · `GET /v2/account`                                                size: S
Place in the tree: settings › account › door (App Store lane)
Repo · branch: backend · `be/BE6.4-account-summary`
Needs: BE2.8 (entitlements), BE0.5 (stored Apple token), BE2.4 (Google identity, for `signedInWith`)      Unblocks: PL3.7d, PL3.7g, P31 live

Why: ST-9 shows your plan as Apple has it (renews or ends, trial, billing problem), how you signed in, and whether deleting needs one more step with Apple.

Inputs: contract 06 §6; fixtures `account.json`, `account.minimal.json`; later-phases BE2.8 (`entitlements` columns).

Spec:
- `signedInWith`: `apple` when `apple_user_id` is set, else `google` when `google_user_id` is set (BE2.4), else `unknown`.
- `plan`: `null` when no `entitlements` row; else `active`, `period` from the product id (`…monthly` / `…yearly`, one map with the founder's product ids), `trial` (`period_type` trial|intro), `renews` (`will_renew`), `renewsOrEndsAt` (`expires_at`), `billingIssue` (the last event BILLING_ISSUE and not resolved), `store`.
- `deletion.needsAppleConfirmation`: `signedInWith == apple && apple_refresh_token_ciphertext is null`.
- Never a price. Bucket `read`.

Acceptance: the fixtures; a lapsed trial reads `active: false, renews: false`.

Tests: `no entitlement reads plan null` · `a trial reads trial true` · `an Apple account without a stored token needs Apple confirmation` · `a Google account never needs Apple confirmation` · fixtures validate · door suite.

Proof: test output.

Watch out: sandbox entitlements never show as active in production (BE2.8's rule); the door doesn't re-check, it reads the mirror.

---

### BE6.5a · Revoke one source's grant                                       size: S
Place in the tree: settings › sources › agent `POST /integrations/connections/:id/revoke`
Repo · branch: agent · `agent/BE6.5a-revoke-one`
Needs: —      Unblocks: BE6.5c

Why: when you disconnect a source, Retrospect gives back its permission at the provider, not just stops using it.

Inputs: agent `src/routes/integrations.ts:223-233` (`/accounts/revoke` → `revokeAccountGrants(userId)`), the credentials store (`storeIntegrationCredentials`).

Spec: factor `revokeAccountGrants` into `revokeConnectionGrant(userId, connectionId)` (used by both); new route `POST /integrations/connections/:connectionId/revoke { userId }`: checks the connection belongs to that user (404 otherwise), revokes at the provider (Google: `https://oauth2.googleapis.com/revoke`; others by their adapter; providers with no revoke endpoint report `notSupported`), deletes the stored credentials, writes an `integration_audit_events` row (`event_type 'grant_revoked'`, no token). Returns `{ result: 'revoked'|'notSupported'|'failed' }`. A Google aggregate grant (docs, gmail, youtube, calendar share one consent) revokes for every member connection and the route says which ones.

Tests: `revoking one connection leaves the person's others` · `another user's connection is 404` · `a provider failure is reported, credentials still deleted` · `a shared google grant disconnects every member` · `the token never appears in the audit row`.

Proof: test output.

Watch out: the Google aggregate is the trap: revoking calendar alone revokes docs, gmail and youtube too. BE6.5c's dialog must say so (it reads `members` from this route's answer).

---

### BE6.5b · `GET /v2/sources`, with the copy in the catalogue              size: M
Place in the tree: settings › sources › door
Repo · branch: backend · `be/BE6.5b-sources`
Needs: BE0.1, BE0.2      Unblocks: BE6.5c, BE6.5d, PL3.7b1, P25, P26 live

Why: ST-3 shows what Retro reads, each with what it's for and whether it's working, and ST-4 says in plain sentences what one source gives it.

Inputs: contract 06 §4; fixtures `sources.json`, `sources.minimal.json`; backend-reference §11 (`GET /integrations`, `/integrations/connections`, catalogue fields, statuses `connected | action_required | disconnected`).

Spec:
- Catalogue: add `name`, `purpose`, `reads`, `helpsMeSee` (lowercase strings, founder copy; placeholders marked `copy to confirm`) to each entry in `src/integrations/integration-catalog.ts`. A test fails if any `available` entry lacks them.
- Read: the user's `integration_connections` joined with `integration_sync_states` and running `integration_jobs` (one query, named columns). Map status per contract 06 §4 (one exported `sourceStatus()` with a table test). `problem` from the failure **kind** and the day ("stopped reading on monday"), never `last_error` text. `hasData`: any `source_items` or `raw_content` from that connection (an `exists` query).
- The aggregate `google` provider is shown as its members (calendar, docs, gmail, youtube), never as "google".
- Order: connected, needs you, then catalogue order; `comingSoon` only when `?include=all` (P25a).
- Bucket `read`.

Acceptance: the fixtures; no `last_error` string ever reaches the app.

Tests (door suite): `status maps from every connection and sync state` (table) · `three failures in a row read needs you` · `the problem line never contains the provider's error text` · `coming soon only with include=all` · `every available source has its copy` · fixtures validate.

Proof: test output.

Watch out: old `GET /integrations` stays for the old screens (X07 removes it).

---

### BE6.5c · Sync, disconnect, delete what it read                          size: M
Place in the tree: settings › sources › ST-4 › doors
Repo · branch: backend · `be/BE6.5c-source-actions`
Needs: BE6.5a, BE6.5b      Unblocks: PL3.7b1, P26 live

Why: from one source's page you can read it now, stop it (and give back its permission), or remove everything it gave Retro.

Inputs: contract 06 §4; fixtures `source.sync.response.json`, `source.disconnect.response.json`, `source.delete-data.request.json`, `source.delete-data.response.json`; backend `src/routes/integrations.ts:151-183, 426-468`.

Spec:
- `POST /v2/sources/:id/sync` → ownership by `(user, provider id)` → `requestAgentIntegrationSync` → `{ source }` (syncing). Limit 6 per hour per source (`rate_limited`). Bucket `write`.
- `DELETE /v2/sources/:id` → mark `disconnected` (as today) **and** call BE6.5a for account sources → `{ source, grant }` (`revoked`, `notNeeded` for on-phone, `failed` when the provider refused; logged as a count). For the Google aggregate, the response lists every member now disconnected (`affected`, contract 06 §4); `GET /v2/sources` carries `sharedGrant: "google"` on each member so the dialog can name them first.
- `DELETE /v2/sources/:id/data { confirm: 'delete' }` → `requestAgentIntegrationDataDeletion` → `{ source }` with `hasData` true until the job finishes (the app polls `GET /v2/sources` every 5 s while ST-4 shows "deleting").
- Not found or not yours → `not_found`.

Acceptance: the fixtures; disconnect then sync is `not_found`-free but returns `notConnected`.

Tests (door suite): `disconnect revokes the grant and keeps the data` · `disconnecting calendar also disconnects docs, gmail and youtube, and says so` · `a refused revoke still disconnects` · `delete what it read needs confirm` · `sync is limited per source` · fixtures validate.

Proof: test output; a staging disconnect with a test Google account (counts only).

Watch out: on-phone sources: the server can only stop accepting their batches; the app stops sending (PL3.7b1).

---

### BE6.5d · Connect, connected, imports (shared with ON-6)                 size: M
Place in the tree: settings › sources › add a source, reconnect, import a file › doors
Repo · branch: backend · `be/BE6.5d-connect-import`
Needs: BE6.5b      Unblocks: PL3.7b2, P25a, ON-6 (contract 01)

Why: you can add or reconnect a source and bring in an export file, from settings or from onboarding, through the same doors.

Inputs: contract 06 §4; fixtures `source.connect.browser.json`, `source.connect.on-phone.json`, `import.create.request.json`, `import.create.response.json`, `import.complete.response.json`; backend `src/routes/integrations.ts:117-149, 251-398`.

Spec:
- `POST /v2/sources/:id/connect`: account sources → the existing PKCE start (`connect/start`), `{ mode: 'browser', authorizationUrl }`; on-phone → `{ mode: 'onPhone' }`; `comingSoon` or unconfigured → `not_found` (never a half-working browser page). Also used for reconnect.
- `POST /v2/sources/:id/connected` (on-phone only) → the existing `native-connected` upsert → `{ source }`.
- `POST /v2/imports` (Idempotency-Key) and `POST /v2/imports/:id/complete { sha256 }` wrap today's import routes; only `file` sources; `byteSize ≤ 1 GB`; `contentType` from an allow-list (zip, json, html, txt); the same key returns the same import.
- Buckets: connect `write`, import create `write`, complete `expensive` (it queues a read).

Acceptance: the fixtures; an import of 2 GB is `invalid_request` before any upload.

Tests (door suite): `a browser source returns an authorization url` · `an on-phone source asks the phone` · `a coming-soon source can't be connected` · `an import is idempotent by key` · `complete needs the right sha256` · fixtures validate.

Proof: test output.

Watch out: the callback (`/integrations/:providerId/connect/callback`) stays where it is; only the start moves behind `/v2`.

---

### BE6.6a · Deleting an Apple account with no stored token                  size: S
Place in the tree: settings › account › delete account › Apple revoke (amends BE0.7) · App Store lane
Repo · branch: backend · `be/BE6.6a-apple-code-at-deletion`
Needs: BE0.5, BE0.7      Unblocks: PL3.7g, T06's deletion test

Why: everyone who signed in with Apple before we started keeping Apple's token can still delete their account properly: Apple is told, as App Review requires (TN3194).

Inputs: contract 06 §6, §8; fixtures `account.delete.request.json`, `error.apple_confirmation_required.json`; phase-0 BE0.5 (`exchangeCode`, `revoke`), BE0.7.

Spec:
- `DELETE /v2/account` accepts `appleAuthorizationCode?: string` (≤ 1,000 chars). Order inside BE0.7's Apple step:
  1. a stored token → revoke it (BE0.5);
  2. else a code → `exchangeCode(code)` → revoke the refresh token it returns (and the access token if no refresh token comes back);
  3. else, for an Apple-signed account → **409 `apple_confirmation_required`**, before any step runs (nothing deleted).
- A code that fails to exchange → `invalid_credentials` (the app asks Apple again); a revoke that Apple refuses after a good exchange → logged, deletion continues (the person asked us to delete; we never keep data over a provider error, as #13 did).
- `APPLE_REVOKE_ENABLED` off (no founder key yet) → the 409 is never sent and the step is skipped and logged; T06 can't pass until the key exists (the ship gate checks it).

Tests: `no token and no code is 409 and deletes nothing` · `a fresh code is exchanged and revoked` · `a bad code is invalid_credentials` · `a Google account never gets the 409` · `the code is never logged`.

Proof: test output; a sandbox Apple deletion on staging (integrator).

Watch out: the authorization code lives five minutes and works once: the app gets it right before sending, never earlier.

---

### BE6.6b · Deletion answers 202 and finishes in the background             size: S
Place in the tree: settings › account › delete account › resumable (amends BE0.7) · App Store lane
Repo · branch: backend · `be/BE6.6b-deletion-async`
Needs: BE0.7      Unblocks: PL3.7g, BE0.13's `account-delete`

Why: deleting your account is never half-done, even if you close the app or lose signal the second you tap it, and you aren't held on a spinner for two minutes.

Inputs: contract 06 §8; fixture `account.delete.response.json`; phase-0 BE0.7 (steps, `deletions` log), BE0.13.

Spec:
- Migration `013_deletions.sql` (if BE0.7 hasn't created it; else an `alter`): `deletions (id uuid pk, user_id uuid not null` **without** a foreign key, `step text, status text, error_code text, at timestamptz)`, index on `(user_id, at)`.
- The door, inside one transaction: revoke every refresh-token family, bump `token_version`, set `users.access = 'suspended'` (no door answers anything but 401/403 from here), write the `requested` row; then answer **202** `{ deletion: { id, state: 'deleting' } }` and run BE0.7's steps on a background worker.
- A sweeper every minute resumes any deletion whose last row isn't `done` and is older than 2 minutes (from the first unfinished step; each step idempotent as BE0.7 says). After the `users` row is gone, the log keeps the counts for 30 days, then the sweeper removes it.
- A repeated `DELETE /v2/account` while deleting returns 202 with the same id (if the token still works); BE0.13's `account-delete` event enters the same path.

Tests: `the door answers 202 after locking and every token stops working at once` · `a crash between steps resumes from the first unfinished step` · `the log survives the user row` · `a second request returns the same deletion` · `Apple's account-delete notification uses the same path`.

Proof: test output.

Watch out: `access = 'suspended'` reuses an existing state so the gate needs no change; the app never sees it, because its tokens are already dead.

---

### BE6.6c · Delete my data keeps your choices                              size: S (only if Q10 = keep)
Place in the tree: settings › privacy › delete my data (amends BE0.8)
Repo · branch: agent · `agent/BE6.6c-delete-data-keeps-choices`
Needs: BE0.8      Unblocks: PL3.7f

Why: starting again doesn't undo your own choices (brief time, background reading, how straight, voice), only what Retro learned.

Inputs: contract 06 §8; phase-0 BE0.8 (resets `user_preferences` to defaults).

Spec: in the agent's `delete-data`, instead of resetting `user_preferences` wholesale: keep `metadata.appetite.stated` (drop `inferred`, `reasons`, `basis`, `suggested`), drop `metadata.learning`, drop `directives`, `focus_areas`, `avoid_topics`, `tone`, `trusted_voice_description` (all learned or written from episodes). `users` columns (brief, ambient, voice, speed) are untouched.

Tests: `delete-data keeps a stated straightness and drops the inferred one` · `learning and directives are gone` · `brief and voice settings survive` · `another user's preferences are untouched`.

Proof: test output.

Watch out: if Q10 is B (reset everything), this byte is dropped and BE0.8 stands as written.

---

### BE6.7 · Notification settings: per kind, and hiding the words on the lock screen   size: S
Place in the tree: settings › notifications › door and storage
Repo · branch: backend · `be/BE6.7-notification-settings`
Needs: BE6.1e, BE2.6 (devices)      Unblocks: PL3.7j, P23a live, the outside plan's sender (it must honour these)

Why: you choose which kinds of notification Retro sends you, and you can keep their words off your lock screen, while every notification stays written for you and the moment (founder, 21 Oct).

Inputs: contract 06 §2 (`NotificationSettings`), fixtures `notifications.patch.request.json`, `notifications.response.json`; contract 07 (the outside plan owns the notification writer and delivery; this byte only stores the person's choices and exposes them).

Spec:
- Migration `014_notification_settings.sql` (backend; number to confirm with the integrator): `notification_settings (user_id uuid pk → users on delete cascade, brief boolean not null default true, episode boolean not null default true, questions boolean not null default true, hide_words_on_lock_screen boolean not null default false, updated_at)`; a missing row means the defaults.
- `PATCH /v2/settings/notifications { brief?, episode?, questions?, hideWordsOnLockScreen? }` (strict booleans, at least one) → `{ notifications }`; `GET /v2/settings` (BE6.1e) adds `notifications` from the same table (one read, no agent call).
- `src/services/notification-settings.ts` exports `notificationSettingsFor(userId)`: the one function the outside plan's sender calls before writing and sending. It returns the kinds allowed and `hideWordsOnLockScreen`. With `hideWordsOnLockScreen`, the sender asks its writer for a **private** notification (contract 07 defines it; lean: a title written for the moment with nothing personal in it, and the words only inside the app when it opens), so the words never reach Apple's servers or the lock screen.
- The brief kind applies only when the brief itself is on (the brief switch stays the brief's master).
- Bucket `write` (patch).

Acceptance: the fixtures; a new account reads every kind on and hide off.

Tests (door suite): `a new person gets every kind on and words shown` · `a patch changes only what it names` · `a non-boolean is invalid_request` · `deleting the account removes the row` (cascade) · `notificationSettingsFor returns the defaults with no row` · fixtures validate.

Proof: test output.

Watch out: this byte never sends or writes a notification; the outside plan does. Keep `notificationSettingsFor` the only reader so the sender can't drift from what the page shows.
