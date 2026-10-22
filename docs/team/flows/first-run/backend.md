# First run · backend cards

The backend engineer's cards for first run: the doors in `backend/` and the brain bytes in the agent repo. Full [byte cards](../../byte-card.md). Every door is built with the kit (BE0.1), passes the door suite (BE0.2: the nine tests, including "another user's id → not_found") and the invite gate (BE0.12). Every agent route gets a two-user PGlite test, run as `service_role` where it touches SQL (BEA.1's harness). Fixtures: every `fixtures/01/*.json` response file validates against its door's zod output schema (testing.md layer 4).

**Migrations** (house style from `backend/phase-0.md`: additive, header comment, RLS on, `REVOKE … FROM PUBLIC, anon, authenticated`, `GRANT … TO service_role`; files only, never applied to production by an agent). Already assigned: backend `010_entitlements.sql` (BE2.8a), `011_devices.sql` (BE2.6), `012_google_identity.sql` (BE2.4); agent `156_podcast_jobs.sql` (BE2.5a1). Assigned since: backend `021_invite_serial.sql` (BE2.0b; the card first said 013, but 013–018 were assigned in plans-consistency.md §3, 019 merged and 020 went to the BE0.12 follow-up). **Still needs the integrator's assignment:** agent `158_onboarding_answer_type.sql` (BE2.2a, only if `raw_content.content_type` has a check constraint).

**Order.** Beta 1: BE2.0a → BE2.0b (after BE0.12). Phase 2: BE2.2a → BE2.2b → BE2.3a → BE2.3b → BE2.10 → BE2.4 → BE2.5a1 → BE2.5a2 → BE2.5b → BE2.6 → BE2.7a → BE2.7b → BE2.8a → BE2.8b → BE2.1; BE2.9a–d only if the founder says Notion is in (D9). Two at most in review at once.

---

## Beta 1 · the invite ticket

### BE2.0a · Invite preview (public)                                                 size: S
Place in the tree: first run › the invite › preview › `GET /public/invites/:code`
Repo · branch: backend · `be/BE2.0a-invite-preview` (stacked on BE2.0b: the serial)
Needs: BE0.12, BE2.0b (the serial)        Unblocks: PL1.7d (preview), PI1 · T1 live

Why: when you open a friend's link before signing in, the screen can say "priya kept a place for you." without spending anything or telling a stranger whether a code works.

Inputs: contract 01 §2.1, fixtures `invite.preview.live.json`, `invite.preview.notlive.json`, `error.rate_limited.json`; BE0.12 (`invites`, `code_hash`, `GET /i/:code`'s rule: the inviter's first name only for a valid, unused code); BE2.0b's `TicketFace`.

Spec (as built):
- Migration `024_invite_preview.sql`: `invite_face(p_code_hash, p_now)` keeps its signature and, for a live code only, also returns `kind`, `serial` (021) and `created_at`; never `code_ciphertext`. The link page keeps working on the same function.
- Public route on the backend (`backend/src/invites/public.ts`, beside `/i/:code` and `/public/waitlist`), no token. Bucket `invitePreview`: 30 a minute per address (`DOOR_LIMITS.buckets`); over it `rate_limited` with `retryAfterSeconds` and `Retry-After`, the one error.
- Normalise as redeem does; **the lookup always runs** (a string that can't be a code looks up its own hash, which no row has), so timing says nothing. **Live** = exists, unused, not revoked, not expired → `{ live: true, face: { from, kind, serial, issuedOn } }`: `from` = the owner's first name (null for founder and review invites until `INVITE_FOUNDER_NAME` exists: founder Q10, BE2.0b Q4); `issuedOn` = the UTC date of `created_at` until `users.time_zone` is written (BE2.0b Q5).
- Not live (used, revoked, expired, unknown, malformed) → the identical `200 { live: false, face: null }`. `Cache-Control: no-store`, no cookies.
- Logging: the door log line `invites.preview` with status only; never the code, the name or the address.
- Accepted (review of #135): a database failure during the lookup answers `500 internal`, the one case beyond the contract's `rate_limited`; the link page's pre-existing skip of the lookup for a malformed code is on the polish list.

Acceptance: a live code returns its face; used, revoked, expired, unknown and malformed codes all return the identical body.

Tests (`backend/tests/invites-preview.test.ts`; * = fails when its rule is removed):
- `a live invite previews its inviter, serial and date: the contract fixture exactly` (and a review invite with no name)
- `a used, revoked, expired, unknown or malformed code all answer the same body` *
- `the preview never opens the sealed code` *
- `the preview is rate-limited per address, with the contract envelope` (its own bucket; the link page's is separate)
- fixtures validate against `PreviewResponse`.

Proof in the PR: test output; one safety test shown failing with its rule removed.

Watch out: this is a public enumeration surface; 65-bit codes make guessing hopeless, but the IP limit and the identical answers are still required.

---

### BE2.0b · Invite check, the serial, and redeem made idempotent for the redeemer    size: M
Place in the tree: first run › the invite › check and tear › `POST /v2/invites/check`, `POST /v2/invites/redeem` (amended)
Repo · branch: backend · `be/BE2.0b-invites-check`
Needs: BE0.12, BE0.1, BE0.2        Unblocks: PL1.7d, PI2 live, T03a's staging half, BE2.0a (the serial)

Why: the ticket prints only after sign-in and only what's true, and the code is spent at the tear, exactly once, even if the tear's response is lost.

Inputs: contract 01 §2.2–§2.3, fixtures `invite.check.*.json`, `invite.redeem.*.json`, `error.invite_*.json`; BE0.12's `redeem(userId, code)` single-statement update; contract 00 §4; the integrator's contract pass (`BE2.0b.md`, 22 Oct), whose leans this card now carries.

Spec (as built):
- Migration `021_invite_serial.sql`: `invites.serial bigint not null unique default nextval('invite_serial_seq')`, existing rows numbered in `created_at, id` order, the serial given at creation (so a code's number is the same on the link page, the preview, the check and the stub); `invites.redeemed_on date` (the tear's date in the redeemer's zone); `invites.redeem_key uuid` (the tear's `Idempotency-Key`, kept on the spent row; no separate idempotency store, since BE0.0 never built one). `redeem_invite` gets a new signature (key and date in; serial and date out on both the fresh and own-retry paths); new `invite_check`, STABLE, never selecting `code_ciphertext`.
- `POST /v2/invites/check` (`/v2`, token required; the gate lets `waitlisted` through like redeem): zod `{ code: string 1..64 }`; normalise (not a code → `invite_invalid`); then, in redeem's order:
  - no such code → `400 invite_invalid`
  - code used by **this** caller → `200 { usable: false, reason: "yours", face }` (before "already in": after the tear the caller is `approved`)
  - caller is `approved`/`member`/`staff` → `200 { usable: false, reason: "alreadyIn", face: null }`
  - revoked → `400 invite_invalid` (as on redeem; says less); used by someone else → `400 invite_used`; expired → `400 invite_expired`
  - live → `200 { usable: true, face }`; `face.issuedOn` is the UTC date of `created_at` until `users.time_zone` is written
  - buckets `inviteCheck` (20 per 10 minutes per user) and `inviteCheckAddress` (60 per address), its own, so checking never eats the tear's five; no agent call; spends nothing; never decrypts `code_ciphertext`.
- Redeem amendments (BE0.12's door): (1) the same caller redeeming a code they already redeemed → the same `200` with the stored `serial` and `redeemedOn` (the own-retry path; the update's `where used_by_user_id is null` stays the race guard); (2) `Idempotency-Key` (optional in Beta 1; a UUID when sent, else `invalid_request`): kept on the spent row; the same caller's same key with the same code → the stored answer before the code lookup; with a different normalised code → `409 idempotency_mismatch`; another person's key is theirs alone; a replay counts toward the limit (single flight plus a few retries stays under five); (3) the response adds `invite: { serial, redeemedOn } | null` (`null` only on `already_in`); `redeemedOn` = the tear's date in the zone of the validated `X-Time-Zone` header (`localDay`), UTC without one (nothing writes `users.time_zone` yet).
- Logging: the door log's `code` on refusals; nothing else (counts only; the app's `invite.check.<outcome>` analytics are contract 01 §2.4's).

Acceptance: check never changes a row; a tear retried after a lost response succeeds; two different people racing the same code: one `200`, one `invite_used`.

Tests (door suite, plus; * = fails when its rule is removed), `backend/tests/invites-check.test.ts`:
- `check never spends an invite or touches a row` * · `check never reads code_ciphertext` *
- `check says yours for the redeemer even after they are approved, and used for anyone else` *
- `check tells members and staff they are already in, with no face` · `check answers invalid for unknown, malformed and revoked codes, expired for expired ones`
- `check is rate-limited per user (20) and per address (60) on its own buckets, not redeem's`
- `redeeming twice as the same person returns the same serial and redeemedOn` *
- `a replayed key with the same code is the same 200; the same key with another code is idempotency_mismatch` *
- `another person's key is theirs alone` * · `already_in returns invite null and spends nothing`
- `redeemedOn follows X-Time-Zone, and UTC without it` *
- `migration 021 numbers existing invites in creation order and keeps serials unique`
- fixtures validate: `fixtures/00/redeem.response*.json` equal the live answers; every `fixtures/01/invite.*.json` matches the door's zod schema.

Proof in the PR: test output; one safety test shown failing with its rule removed.

Watch out: never write the plain code anywhere; `code_ciphertext` is cleared at redeem as BE0.12 says, and check must not decrypt it.

---

## Phase 2

### BE2.4 · Google sign-in                                                           size: M
Place in the tree: first run › sign in › Google › `POST /v2/auth/google`
Repo · branch: backend · `be/BE2.4-google-sign-in`
Needs: BE0.4, BE0.12; founder: a separate Google sign-in OAuth client (iOS), basic scopes only        Unblocks: PL1.4b, C43's Google button, P01

Why: founder decision D3: sign in with Apple or Google.

Inputs: contract 00 §3; `backend/later-phases.md` BE2.4 (kept decisions); backend-reference §0.5–§0.6 (the old auth).

Spec:
- Migration `012_google_identity.sql`: `users.apple_user_id` nullable; `users.google_user_id text unique`; a check that at least one is set.
- Verify the ID token with `jose` against `https://www.googleapis.com/oauth2/v3/certs` (cached JWKS): issuer `accounts.google.com` or `https://accounts.google.com`; audience = the iOS client id (`GOOGLE_SIGNIN_IOS_CLIENT_ID`); not expired; `nonce == sha256(rawNonce)` and single use via `auth_nonces` (BE0.4).
- Find or create by `google_user_id`; same response as Apple (contract 00 §3) including `access.state` (new users `waitlisted`). **Never auto-link to an Apple account by email** (takeover risk); linking is a later explicit action.
- Errors: a bad token → `401 invalid_credentials` (never 500); a reused nonce → `401 invalid_credentials`.
- Audit every reader of `apple_user_id` for null (auth middleware, `getOrCreateUser`, admin) in the PR.

Tests: `a valid Google token signs in a new person as waitlisted` · `a wrong audience, issuer or expiry is invalid_credentials` · `a reused nonce is refused` · `a Google account never links to an Apple account by email` · `every apple_user_id reader handles null` · fixtures for `auth.response.json` validate.

Proof in the PR: test output (JWKS stubbed); a staging sign-in with the founder's client.

Watch out: the Docs/Drive connector's Google client is a different client id; never accept its tokens here.

---

### BE2.2a · `onboarding_answer` counts as the person's own words (agent)             size: S
Place in the tree: first run › the questions › brain › "sent by the person"
Repo · branch: agent · `agent/BE2.2a-onboarding-answer-type`
Needs: —        Unblocks: BE2.2b

Why: what you tell Retro while setting up is treated like anything else you said: your own words, read and remembered.

Inputs: agent-api-reference §10.1 (content types; the "sent by the person" set at `src/planner/daily.ts:22`), §10.4 (`evidence_kinds.onboarding` weight 1.0).

Spec: add `onboarding_answer` to the "sent by the person" set; map it to evidence kind `onboarding` in ingest (where content types map to evidence kinds); if `raw_content.content_type` has a check constraint, migration `158_onboarding_answer_type.sql` adds the value. No new model calls; ingest reads it exactly like a journal entry.

Tests: `an onboarding answer is read as the person's own words` (two users) · `its evidence weight is the onboarding weight` · `the daily planner lists it with the person's entries`.

Proof in the PR: test output.

Watch out: never write `question_answers` from here (service role has SELECT only by design: those are the brain's conclusions).

---

### BE2.2b · Answers doors and `onboarding/complete`                              size: M
Place in the tree: first run › the questions › `POST|GET /v2/onboarding/answers`, `POST /v2/onboarding/complete`
Repo · branch: backend · `be/BE2.2b-onboarding-answers`
Needs: BE1.1 (shared `insertRawContent` and ingest hand-off), BE2.2a        Unblocks: PL3.3a, PL3.3d, PL1.9

Why: each answer is the person's own words, saved once even if sent twice, and the first home can show what they said.

Inputs: contract 01 §3, §4; fixtures `answer.*`, `answers.list*`, `onboarding.complete.response.json`; backend-reference §0.7 (the singleton idempotency bug: don't use `onboarding_profile`).

Spec:
- `POST /v2/onboarding/answers`: zod per contract §4; `Idempotency-Key` = `clientEntryId` (else `invalid_request`); `insertRawContent` with `content_type 'onboarding_answer'`, `metadata { question_key, given, client_entry_id }`, `content_date = createdAt`, `trust_class own_words`; new → hand off to ingest (as BE1.1) and `201`; replay → `200` same answer; same key with a different body → `409 idempotency_mismatch`. Skipped answers are stored (`text ""`) but not handed to ingest.
- `GET /v2/onboarding/answers`: the latest per `question_key`, skipped excluded, in first-given order; `count`.
- `POST /v2/onboarding/complete`: `approved` → `member` (one update with `where access = 'approved'`); `member`/`staff` → unchanged `200`; `waitlisted` → the gate's `invite_required`.
- Buckets: POST `write`, GET `read`; logs: door, user, status, ms, `question_key` (a fixed enum, allowed), never text.

Tests (door suite, plus): `an answer is saved once and read once` · `a retried answer returns the same row and no second read` · `a reused key with different text is idempotency_mismatch` · `a skipped answer is stored and not read` · `the list shows the latest answer per question` · `an unknown question key is refused` · `completing makes an approved person a member, once` · `a waitlisted person can't complete` · fixtures validate.

Proof in the PR: test output; staging run (counts only).

Watch out: `questionKey` values are a closed list shared with the app's strings table; adding a question is a contract change.

---

### BE2.3a · Understanding summary route (agent)                                   size: S
Place in the tree: first run › connect › knows-you › agent `GET /understanding/:userId/summary`
Repo · branch: agent · `agent/BE2.3a-understanding-summary`
Needs: BEA.2 (scoped reads)        Unblocks: BE2.3b

Why: the knows-you meter needs a cheap, honest count of what Retro has to go on.

Inputs: agent-api-reference §10.4 (`domain_coverage`, `current_answers`), §9.2 (`readUnderstanding`).

Spec: `GET /understanding/:userId/summary` → `{ connectedSources, answers, confidentAnswers, domainsCovered }`: active `integration_connections` count; the person's `onboarding_answer` rows that aren't skipped (their own words, not the brain's answers); `current_answers` with confidence ≥ the speak floor; domains with `answered > 0`. No model call; four count queries.

Tests: `the summary counts only this person's rows` (two users, as `service_role`) · `skipped answers don't count` · `inactive connections don't count`.

Proof in the PR: test output.

Watch out: "answers" here means the person's onboarding answers (what the meter promises), not `question_answers`.

---

### BE2.3b · Knows-you door                                                        size: S
Place in the tree: first run › connect › knows-you meter › `GET /v2/knows-you`
Repo · branch: backend · `be/BE2.3b-knows-you`
Needs: BE2.3a, BE0.1        Unblocks: PL3.3b, C36 live

Why: the meter on ON-6 moves from "a little" to "better" to "well" as you connect things and answer, and only when that's true.

Spec: calls BE2.3a (timeout 5 s, retry `read`), computes `level` with `KNOWS_YOU_THRESHOLDS` (one exported constant; founder Q2 lean: `little` below 1 source and 3 answers, `better` from there, `well` at ≥ 3 sources and ≥ 7 answers); returns `{ level, connectedSources, answers }`; bucket `read`.

Tests: door suite · `each threshold edge maps to its level` (table test) · fixtures `knows-you.*.json` validate.

Proof in the PR: test output.

Watch out: never cache across users; per-request only.

---

### BE2.10 · Sources doors for connect                                               size: M
Place in the tree: first run › connect › `GET /v2/sources`, `POST /v2/sources/:id/connect`
Repo · branch: backend · `be/BE2.10-sources`
Needs: BE0.1, BE0.2        Unblocks: PL3.3b, P04 live; contract 06's ST-3/ST-4 reuse them

Why: ON-6 lists what you can connect, in plain words, and connecting works through the same flows the app already trusts.

Inputs: contract 01 §5, fixtures `sources.*`, `source.connect.*`; `backend/src/routes/integrations.ts` (`GET /catalog` :68, `GET /` :75, `POST /:providerId/native-connected` :117, `POST /:providerId/connect/start` :399); `INTEGRATION_APP_REDIRECT_URL` (`retrospect://integration-connected`).

Spec:
- `GET /v2/sources?for=onboarding`: the catalogue joined with the person's connections → `Source[]`; `kind` from the provider's type (native → `onDevice`, oauth → `account`); `state`: connected/problem/available (`connecting` while an OAuth state row is fresh); `group` from a small server-side map (onboarding: calendar, health → `onThisIphone`; google (+ notion if D9) → `yourOtherApps`; others → `seeAll`); `hidden` providers (no working connector: github; notion until BE2.9) are left out; `purpose` from a new catalogue field (one plain line per provider; the founder's copy).
- `POST /v2/sources/:id/connect`: `account` → wrap `connect/start` → `{ authUrl }`; `onDevice` with `{ granted: true }` → wrap `native-connected` → `{ source }`; `Idempotency-Key` honoured; unknown or hidden id → `not_found`; provider start failure → `upstream_unavailable`.
- Buckets: GET `read`, POST `write`. Logs: provider id and outcome; never tokens or auth URLs.

Tests (door suite, plus): `hidden providers never appear` · `a connected source reads connected` · `an account connect returns an auth url` · `an on-device connect marks it connected` · `an unknown provider is not_found` · fixtures validate.

Proof in the PR: test output; a staging OAuth round trip with a test Google account.

Watch out: the OAuth callback stays the existing public route; don't move it under `/v2`.

---

### BE2.1 · Onboarding goals door                                                     size: S
Place in the tree: first run › the questions › goal candidates › `POST /v2/onboarding/goals`
Repo · branch: backend · `be/BE2.1-onboarding-goals`
Needs: BE2.2b, BEA.4 (spend counted)        Unblocks: contract 04's goal question cards (founder Q6: not in first run)

Why: the goals you named while setting up can come back as questions ("is this a goal?") without you repeating yourself.

Spec: builds `answersText` from the person's stored answers (latest per key, skipped excluded, each prefixed by its key's plain label); calls agent `POST /onboarding/goals` (timeout 30 s, no retry); maps `reasoning` → `because`; drops `cost` and `dropped`; at most 5; bucket `expensive`, counted against the spend cap (BEA.4). No answers → `{ goals: [] }` with no agent call. `spend_limited` when capped.

Tests: door suite · `no answers means no model call` · `reasoning is renamed and cost never passes` · `the spend cap refuses with spend_limited` · fixtures validate.

Proof in the PR: test output.

Watch out: the agent saves nothing; never write goals from this door.

---

### BE2.5a1 · Podcast jobs: the table and the runner (agent)                          size: M
Place in the tree: first run › the first episode › agent `podcast_jobs` + runner
Repo · branch: agent · `agent/BE2.5a1-podcast-jobs`
Needs: BEA.4, BEA.5, BEA.7, BEA.8        Unblocks: BE2.5a2, BE3.3 (weekly through the runner)

Why: making an episode takes minutes; the app needs a job it can watch, not a request that hangs, and never two first episodes.

Inputs: agent-api-reference §6.3–§6.4 (stages, `advance` synchronous for minutes), §7.1 (`runPodcast`, no idempotency, racy `episode_number`, `generation_type` always weekly); `backend/later-phases.md` BE2.5a (kept decisions).

Spec:
- Migration `156_podcast_jobs.sql`: `podcast_jobs(id uuid pk, user_id → users on delete cascade, kind text check in ('first','weekly','on_demand'), status text check in ('queued','running','made','quiet_week','nothing_safe_to_say','failed'), stage text check in ('reading','writing','voicing') null, episode_id uuid → podcast_episodes on delete set null, error_code text, attempts int default 0, created_at, started_at, finished_at)`; unique partial index on `(user_id)` where `status in ('queued','running')`; index on `(status, created_at)`.
- Runner (`src/jobs/podcast-runner.ts`): picks the oldest queued job with `for update skip locked`, sets `running`, runs `runPodcast` with a stage callback (writer start → `writing`, TTS start → `voicing`), records spend (BEA.4), ends `made` (with `episode_id`), `quiet_week` / `nothing_safe_to_say` (BEA.8's outcomes, not errors), or `failed` with `error_code`. A `running` job older than 20 minutes is marked `failed` and re-queued once (`attempts < 2`). Fix `generation_type` (`first` → `milestone` until the check allows `first`; lean: add `first` to the check) and compute `episode_number` inside the insert's transaction.
- The synchronous `POST /podcasts/generate` stays for the cron until X07.

Tests (PGlite, `service_role`): `only one queued or running job per person` · `two runners never take the same job` · `a quiet week ends quiet, not failed` · `a stuck job is failed and re-queued once` · `episode numbers don't collide under two inserts` · `spend is recorded per job` · two users.

Proof in the PR: test output; a local-staging run with `skipTTS` (no voice spend) and one with TTS on a test account (cost logged).

Watch out: never run TTS in tests; the runner must not start in the test process.

---

### BE2.5a2 · Job routes and the first-episode wiring (agent)                       size: S
Place in the tree: first run › the first episode › agent `POST /podcasts/jobs`, `GET /podcasts/jobs/:jobId`
Repo · branch: agent · `agent/BE2.5a2-podcast-job-routes`
Needs: BE2.5a1        Unblocks: BE2.5b

Spec: `POST /podcasts/jobs { userId, kind }` → the existing queued/running job or a new one (`first`: also the existing `made` first job); `GET /podcasts/jobs/:userId/:jobId` (scoped by user: another user's job is 404) → `{ id, kind, status, stage, episodeId, createdAt, startedAt }`; `GET /podcasts/jobs/:userId/first`; for `first` jobs, while the onboarding stage (`stageFor`) is `reading`/`understanding`, the route reports `stage: 'reading'` and the runner waits for `advance` (behind BEA.5's lock) before writing.

Tests: `creating twice returns one job` · `another person's job is not found` (two users) · `a first job reads as reading until onboarding has understood` · `the first job is found after it's made`.

Proof in the PR: test output.

Watch out: userId comes from the backend's session only (the door's job); the route trusts it, so it must never be exposed publicly.

---

### BE2.5b · Episode job and episode doors                                         size: M
Place in the tree: first run › the first episode › `POST /v2/episodes/jobs`, `GET /v2/episodes/jobs/first`, `GET /v2/episodes/jobs/:id`, `GET /v2/episodes/:id`
Repo · branch: backend · `be/BE2.5b-episode-doors`
Needs: BE2.5a2, BEA.7 (signed audio)        Unblocks: PL3.3c, P05, P06; podcasts' PC-1/PC-2 (contract 03 extends `GET /v2/episodes`)

Why: ON-10 watches honest steps, and ON-11 plays the episode from a private, expiring link.

Inputs: contract 01 §6, fixtures `job.*`, `episode.first*`; agent-api-reference §7.2 (`select('*')` ships embeddings: project columns).

Spec:
- `POST /v2/episodes/jobs { kind: "first" }`: `Idempotency-Key`; bucket `expensive`; spend cap (`spend_limited` before queuing); fire-and-forget nudge of `POST /onboarding/advance` while the stage is reading (5 s timeout, not awaited); → `202 { job }` (`200` for an existing one).
- Job mapping: `status queued|running` + `stage` → `step` (`reading`/`writing`/`voicing`), `stepIndex` 1/2/3; `made` → `ready` + `episodeId`; `quiet_week|nothing_safe_to_say` → `quiet`; `failed` → `failed { code, retryable: attempts < 2 }`; `estimateSeconds` from a per-stage median (a constant table, updated from staging measurements; omitted when unknown).
- `GET /v2/episodes/:id`: ownership (`podcast_episodes.user_id`); explicit columns (never `summary_embedding`, never `script` beyond the transcript lines); `audio` signed for 1 hour (BEA.7); `chapters` from BE3.0 when present else `[]`; `transcript` lines from the script's paragraphs (timings when BE3.0 measured them).
- Logs: job id, status, ms; never script text.

Tests (door suite, plus): `one first job per person even with two requests` · `steps map from the agent's stages` · `a quiet week is quiet, not an error` · `another person's job and episode are not found` · `the episode never carries the embedding` · `the audio link expires in an hour` · `a spend-capped person gets spend_limited and no job` · fixtures validate.

Proof in the PR: test output; staging run (counts and timings only).

Watch out: the advance nudge must never hold the request open (the agent can run for minutes).

---

### BE2.6 · Device tokens                                                             size: S
Place in the tree: first run › push permission › `POST /v2/devices`, `DELETE /v2/devices/:token`
Repo · branch: backend · `be/BE2.6-devices`
Needs: BE0.2        Unblocks: PL5.1, BE2.7a

Spec: migration `011_devices.sql` (`devices(id, user_id → users cascade, token text, environment text check in ('sandbox','production'), app_version, created_at, last_seen_at, revoked_at)`, unique `(token, environment)`); `POST` upserts (moves a token to the current user, bumps `last_seen_at`); token hex 64–200; `DELETE` idempotent `204`. Bucket `write`.

Tests: door suite · `registering again bumps last seen` · `a token moves to the person now using the phone` · `deleting twice is fine` · `a non-hex token is refused` · fixtures validate.

Proof in the PR: test output.

Watch out: never log tokens.

---

### BE2.7a · The APNs sender                                                          size: M
Place in the tree: platform › push › sender
Repo · branch: backend · `be/BE2.7a-apns-sender`
Needs: BE2.6; founder: the APNs `.p8` key (`APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY`, `APNS_TOPIC`)        Unblocks: BE2.7b, BE3.3, BE4.3

Why: Retro can tell your phone something is ready, without a word of your content passing through Apple.

Spec: `@parse/node-apn` 8.x pinned; token auth; one long-lived HTTP/2 connection per environment; the provider token reused and refreshed every 20–60 minutes (never per push); each token sent to its registered environment; headers `apns-push-type: alert`, `apns-topic`, `apns-expiration`, `apns-collapse-id`; 410 → delete the device only if Apple's timestamp is later than `last_seen_at`; 400 `BadDeviceToken` → delete; 429/5xx → back off and retry; `sendToUser(userId, payload)` with payloads from a closed builder (contract 01 §7 / contract 07): no free text; `mutable-content: 1` on every alert so the outside plan's Notification Service Extension writes the words.

Tests: `410 deletes only a stale token` · `a bad token is deleted` · `429 backs off` · `the provider token is reused` · `payloads carry no content` (builder test).

Proof in the PR: test output; a sandbox push to the founder's TestFlight build.

Watch out: never log payload bodies beyond `kind`.

---

### BE2.7b · The first-episode note (trigger only)                                 size: S
Place in the tree: first run › the first episode › push when ready
Repo · branch: backend · `be/BE2.7b-episode-ready-push`
Needs: BE2.7a, BE2.5b, the outside plan's note writer (contract 07)        Unblocks: PL5.3's end-to-end check

Spec (founder, 21 Oct: every notification is custom-written for the person and the moment; the outside plan owns the writer and the Notification Service Extension): a one-minute sweep (behind `ENABLE_JOB_PUSH`) reads first jobs that became `made` since the last sweep (a cursor table) and, once per job, **asks the outside plan's note writer** for an `episode_ready` note about this episode (its door and model call are contract 07's); when the writer returns a `noteId`, the sender (BE2.7a) sends the content-free payload of contract 01 §7 with `mutable-content: 1` and that `noteId`. If the writer fails or abstains, nothing is sent (no fixed-string fallback push from first run). Quiet and failed jobs send nothing.

Tests: `a made first job asks for one note and pushes once` · `no note means no push` · `quiet and failed jobs don't push` · `a restarted sweep doesn't push twice` · `the payload carries no words of the note`.

Proof in the PR: test output; a staging push.

Watch out: the lean from later-phases (backend watches; no agent → backend callback) keeps the shared secret one-directional.

---

### BE2.8a · Entitlements from RevenueCat (webhook and table)                         size: M
Place in the tree: first run › membership › `POST /public/revenuecat/webhook`
Repo · branch: backend · `be/BE2.8a-revenuecat-webhook`
Needs: BE0.2; founder: `REVENUECAT_WEBHOOK_SECRET`, `REVENUECAT_SECRET_KEY`        Unblocks: BE2.8b

Why: what you bought is known to the server, so paid work is given only to people who paid (fail closed).

Spec: migration `010_entitlements.sql` (`entitlements(user_id pk → users cascade, active, product_id, period_type normal|trial|intro, expires_at, will_renew, store, environment, updated_at, last_event_id)`); the webhook compares the authorization header in constant time; idempotent on event id; keyed on `app_user_id` (our user id, set by PL6.1); handles INITIAL_PURCHASE, RENEWAL, CANCELLATION, UNCANCELLATION, NON_RENEWING_PURCHASE, EXPIRATION, BILLING_ISSUE, PRODUCT_CHANGE, TRANSFER, SUBSCRIPTION_PAUSED; sandbox events never grant access on a production backend (`environment` stored; the beta backend's `ALLOW_SANDBOX_ENTITLEMENTS=true`).

Tests: `a bad secret is refused` · `a repeated event changes nothing` · `each event type updates the mirror` (table) · `sandbox never grants in production` · `an unknown app user is ignored and logged`.

Proof in the PR: test output; a sandbox purchase on staging.

Watch out: account deletion (BE0.7) must also ask RevenueCat to delete the subscriber.

---

### BE2.8b · Entitlement door and the paid gate                                      size: S
Place in the tree: first run › membership › `GET /v2/entitlement`
Repo · branch: backend · `be/BE2.8b-entitlement-door`
Needs: BE2.8a        Unblocks: PL6.2, P07 live

Spec: `GET /v2/entitlement` from the mirror; `?refresh=true` asks RevenueCat's REST API (`REVENUECAT_SECRET_KEY`) and updates the mirror, falling back to the mirror on failure (fail closed, `entitlement.refresh.failed` logged); bucket `read` (`write` with refresh). The paid gate (founder Q4): a kit option `requiresEntitlement` that returns `402 subscription_required` (added to contract 00 only on the founder's yes); on the lean, applied to no first-run door.

Tests: door suite · `refresh falls back to the mirror when RevenueCat is down` · `inactive by default` · fixtures `entitlement.*` validate.

Proof in the PR: test output.

Watch out: never trust the app's claim of a purchase; only the mirror and RevenueCat.

---

### BE2.9 · Notion (only if D9 says it's in)                 4 bytes: BE2.9a–d, each M
Place in the tree: first run › connect › Notion
Repo · branches: backend `be/BE2.9a-notion-oauth`; agent `agent/BE2.9b-notion-connector`, `agent/BE2.9c-notion-normalise`; backend `be/BE2.9d-notion-door`
Needs: founder decision D9; BE2.10        Unblocks: ON-6's Notion row

Why: if you live in Notion, Retro can read the pages you choose.

Spec: (a) OAuth start and callback in the backend (the existing PKCE pattern, Notion's public integration); (b) the connector in agent `src/connectors/` (pages and databases the person shared, incremental by `last_edited_time`); (c) normalisation into `source_items` and `raw_content` (`trust_class own_words` for pages they wrote); (d) the catalogue entry un-hidden in BE2.10. Brief: `docs/second-brain/brief-notion-import.md`.

Tests: per byte: `only pages the person shared are read` · `an incremental sync reads only changed pages` · `two users never see each other's pages` · door suite for (a).

Proof in the PR: staging connect with a test Notion workspace.

Watch out: if the founder says not in the beta, these four are dropped and ON-6 never shows the row (BE2.10 keeps it hidden).
