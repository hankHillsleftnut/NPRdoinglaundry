# Backend · phases 2–7: outline cards

Detail near, outline far (README §5). Each card below carries its header, why, place in the tree and dependencies, plus every decision and trap already known, so nothing is lost. The integrator fills each into a full byte card (byte-card.md) **before its phase starts**, once its contract is merged. Migration numbers are pre-assigned in phase-0.md.

---

## Phase 2 · First run (contract [01-first-run.md](../contracts/01-first-run.md), draft)

Tree: **first run** › sign in (BE2.4) › questions (BE2.1, BE2.2) › connect + knows-you (BE2.3, BE2.9) › getting ready + first episode (BE2.5a/b, BEA.5, BEA.8) › push permission (BE2.6, BE2.7) › paywall (BE2.8).

### BE2.1 · Onboarding doors                                                size: M
Place: first run › questions, getting ready · `POST /v2/onboarding/interpret`, `GET /v2/onboarding/readiness`, `POST /v2/onboarding/advance`, `POST /v2/onboarding/goals`
Repo: backend · Needs: BEA.4, BEA.5, contract 01 · Unblocks: P02–P05
Why: the questions, the "getting ready" wait and the first goals reach the real brain.
Known: `advance` is synchronous for minutes in the agent (§6.4); the door must not hold the request: it calls `readiness` on every poll and fires `advance` without awaiting (fire-and-forget behind BEA.5's lock, door timeout 5 s, the agent keeps running). `readiness.facts` is debugging, never passed to the app; the door maps `stage` to the contract's three ON-10 steps. `goals` saves nothing (§6.2): the app shows the candidates, and accepting one goes through BE4.1. `interpret` is the **legacy** Cook 0 path (§6.1, nothing in v2 reads it): confirm with the founder whether ON-10/ON-11 need it at all before building it (question for the founder, contract 01 §7). Cost lines are stripped. Buckets: readiness `read`, advance and goals `expensive`.

### BE2.2 · Onboarding answers as structured entries                        size: M
Place: first run › questions › one answer · `POST /v2/onboarding/answers`
Repo: backend (+ agent if the read side needs it) · Needs: BE1.1 · Unblocks: P02, the setup-recap card (ON-13)
Why: each answer is the person's own words, saved once, and the recap on ON-13 can show what they told Retro.
Known: today the app sends one `onboarding_profile` singleton blob (`content-insert.ts:72`). New: one `raw_content` row per answer (`content_type 'onboarding_answer'`, `metadata { question_key, given: voice|typed|skipped, client_entry_id }`, `trust_class own_words`), idempotent per `clientEntryId`; evidence kind `onboarding` (weight 1.0, §10.4) already exists in the question store. **Don't write `question_answers` directly** (service role has SELECT only, by design: answers there are the brain's conclusions, not the person's words). Add `onboarding_answer` to the agent's "sent by the person" set (`src/planner/daily.ts:22`) in a small agent PR. `GET /v2/onboarding/answers` returns the recap (count + the answers in order).

### BE2.3 · Knows-you                                                      size: M
Place: first run › connect › knows-you meter · `GET /v2/knows-you`
Repo: agent then backend · Needs: BEA.2 · Unblocks: P04 (ON-6), C-knows-you meter
Why: the meter on ON-6 moves from "a little" to "better" to "well" as you connect things and answer.
Known: agent `GET /understanding/:userId/summary` → `{ connectedSources, answers, confidentAnswers, domainsCovered }` from `integration_connections` (active), `domain_coverage` view (§10.4); no model call. The door computes `level: 'little' | 'better' | 'well'` with thresholds in one exported constant (founder decision: contract 01 §7). Cheap (`read`).

### BE2.4 · Google sign-in                                                 size: M
Place: first run › sign in › Google · `POST /v2/auth/google`
Repo: backend · Needs: BE0.4, BE0.12, founder action (a separate Google sign-in OAuth client, `openid email profile` only) · Unblocks: PL1.4, the splash
Why: founder decision D3: Apple and Google.
Known: migration `012_google_identity.sql`: `users.apple_user_id` becomes nullable, `users.google_user_id text unique`, a check that at least one is set. Verify the ID token with `jose` against `https://www.googleapis.com/oauth2/v3/certs`: issuer `accounts.google.com` or `https://accounts.google.com`, audience = the **iOS client id**, expiry, nonce (`sha256(rawNonce)`, single use via `auth_nonces`). Same response and invite gate as Apple. **Never auto-link to an existing Apple account by email** (account takeover); linking is a later explicit action. Deletion (BE0.7) revokes a stored Google token if any. Every place that reads `apple_user_id` (auth middleware, `getOrCreateUser`, admin) is audited for null in the PR.

### BE2.5a · Podcast job, agent side                                       size: L (split: table + runner · status route)
Place: first run › getting ready › the first episode · agent `POST /podcasts/jobs`, `GET /podcasts/jobs/:jobId`
Repo: agent · Needs: BEA.4, BEA.5, BEA.7, BEA.8 · Unblocks: BE2.5b, BE3.3
Why: making an episode takes minutes; the app needs a job it can watch, not a request that hangs.
Known: migration `156_podcast_jobs.sql`: `podcast_jobs(id, user_id → users cascade, kind: first|weekly|on_demand, status: queued|running|made|quiet_week|nothing_safe_to_say|failed, stage: reading|writing|voicing|null, episode_id, error_code, created_at, started_at, finished_at)`, unique partial index: one `queued|running` job per user (founder rule "one episode per onboarding, never two"). The runner picks queued jobs (lock per job), reports stage as the pipeline moves, records spend (BEA.4). Restart-safe: a `running` job older than 20 minutes is marked failed and may be re-queued once. Fix `generation_type` (always `weekly` today) and the racy `episode_number` (compute inside a transaction). The synchronous route stays for the cron until X07.

### BE2.5b · Episode doors                                                 size: M
Place: first run › getting ready; podcasts › list, one episode · `POST /v2/episodes/jobs`, `GET /v2/episodes/jobs/:id`, `GET /v2/episodes`, `GET /v2/episodes/:id`
Repo: backend · Needs: BE2.5a, BEA.7 · Unblocks: P05, P06, PC-1, PC-2
Known: bucket `expensive` for job creation (and the spend cap). **Name every column**: `GET /podcasts` today does `select('*')`, shipping the 3,072-float `summary_embedding` and full script for 50 rows (§7.2). The list returns metadata only; the script, plan-derived chapters (BE3.0) and a signed audio URL (1 hour) come with `GET /v2/episodes/:id`. `ready` only in lists; jobs report `quiet_week` as a state, not an error.

### BE2.6 · Push: device tokens                                            size: S
Place: first run › push permission · `POST /v2/devices`, `DELETE /v2/devices/:token`
Repo: backend · Needs: BE0.2 · Unblocks: PL push registration, BE2.7
Known: migration `011_devices.sql`: `devices(id, user_id → users cascade, token text, environment: sandbox|production, app_version, created_at, last_seen_at, revoked_at)`, unique `(token, environment)`; re-registering moves a token to the current user (a phone changes hands) and bumps `last_seen_at`. Token validated as hex, 64–200 chars. Idempotent.

### BE2.7 · Push: sender and "episode ready"                              size: M
Place: platform › push sender · first run › first episode ready
Repo: backend · Needs: BE2.6, BE2.5a, founder action (APNs `.p8` key) · Unblocks: BE3.3, BE4.3
Known: `@parse/node-apn` 8.x, token-based (`APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY`, `APNS_TOPIC`); one long-lived HTTP/2 connection per environment; provider token reused, refreshed every 20–60 minutes (never per push: `TooManyProviderTokenUpdates`); each token sent to the environment it registered with. 410: delete only if Apple's timestamp is later than `last_seen_at`; 400 `BadDeviceToken`: delete; 429/5xx: back off and retry. Headers `apns-push-type`, `apns-topic`, `apns-expiration`, `apns-collapse-id`. **Payloads are content-free** ("this week's episode is here.") plus an id and a deep-link path; nothing personal passes through Apple. How the agent tells the backend an episode is made: the backend polls job state, or the agent calls an internal backend route with the shared secret (decide in the full card; lean: the backend's job door already watches the job, plus a minute-cron sweep for weekly episodes).

### BE2.8 · Entitlement mirror from RevenueCat                              size: M
Place: first run › paywall; settings › subscription · `POST /public/revenuecat/webhook`, `GET /v2/entitlement`
Repo: backend · Needs: BE0.2, founder action (RevenueCat webhook secret and secret API key) · Unblocks: PL6.x, P07
Why: founder decision D6: $19.99 a month; $199.99 a year with the first month free; the app shows Apple's localized price, never a typed-in one.
Known: migration `010_entitlements.sql`: `entitlements(user_id PK → users cascade, active, product_id, period_type normal|trial|intro, expires_at, will_renew, store, environment, updated_at, last_event_id)`. Webhook: authorization header compared in constant time (`REVENUECAT_WEBHOOK_SECRET`), idempotent on event id, keyed on `app_user_id` (our user id, set by `Purchases.logIn`); handles INITIAL_PURCHASE, RENEWAL, CANCELLATION, UNCANCELLATION, NON_RENEWING_PURCHASE, EXPIRATION, BILLING_ISSUE, PRODUCT_CHANGE, TRANSFER, SUBSCRIPTION_PAUSED; sandbox events never grant production access. `GET /v2/entitlement` refreshes from RevenueCat's REST API (`REVENUECAT_SECRET_KEY`) when asked right after a purchase. **Fail closed.** Deletion (BE0.7) asks RevenueCat to delete the subscriber. Which doors require an active entitlement (the paid gate) is a contract 01 question for the founder.

### BE2.9 · Notion                                                         size: L ×4 (OAuth · connector · normalise · door)
Place: first run › connect › Notion
Repo: agent ×3 + backend · Needs: founder decision D9 · Unblocks: ON-6's Notion tile
Known: OAuth start/callback in the backend (the existing PKCE pattern); connector in agent `src/connectors/`; normalisation into `source_items`; brief at `docs/second-brain/brief-notion-import.md`. If the founder says not in the beta, the UI hides the tile and this byte is dropped.

---

## Phase 3 · Podcasts (contract 03, later)

Tree: **podcasts** › list and player (BE2.5b) › chapters (BE3.0) › why this is here (BE3.1) › feedback (BE3.2) › weekly push (BE3.3).

### BE3.0 · Loose chapters and real duration                              size: M
Place: podcasts › player › chapter ticks · Repo: agent · Needs: BEA.7 · Unblocks: M09, PC-2
Why: founder decision D14: loose chapters, one per topic as the narrator moves on.
Known: no chapter or timing data exists anywhere (§7.3); `durationSeconds` is words/150. Migration `157_episode_chapters.sql`: `podcast_episodes.chapters jsonb default '[]'` (`[{ title, startSeconds }]`), `duration_measured bool`. The writer already plans sections: label each with a short title, synthesise per section (BE1.3b's per-part synthesis and measuring, shared as one helper), store measured duration. **No new model calls.**

### BE3.1 · Why this is here                                                size: M
Place: podcasts › one claim › evidence sheet · agent `GET /evidence/:userId/:kind/:id`, door `GET /v2/evidence/:kind/:id`
Needs: BEA.2 (`walkEvidence` scoped) · Known: walk backward from the claim to entries with excerpts; excerpts are the person's own words, shown only to them, never logged.

### BE3.2 · Episode feedback                                                size: S
Place: podcasts › after an episode · `POST /v2/episodes/:id/feedback`
Needs: BEA.2 · Known: ownership via `podcast_episodes.user_id`; the agent's GET stays internal (unscoped before BEA.2). Feedback folds into `user_preferences.directives`, so BEA.3's merge must land first.

### BE3.3 · Weekly episode push                                            size: S
Place: podcasts › the weekly episode · Needs: BE2.7, BE2.5a · Known: the weekly cron runs through the job runner; on `made`, the content-free "episode ready" push; on `quiet_week`, nothing (or the founder's quiet line: contract 03 question).

---

## Phase 4 · Goals (contract 04, later)

Tree: **goals** › list and one goal (BE4.1) › evidence, said vs did (BE4.2) › check-ins (BE4.3).

### BE4.1 · Goal doors                                                     size: M
Place: goals › list, one goal, yes / not quite · `GET|POST|PATCH|DELETE /v2/goals…`
Known: re-expose the existing backend `/goals` routes through the kit with the contract's shapes; status from 139 (`active|quit|achieved|expired|merged`); the agent's reads filter on `is_active` (not `status`) (§9.2): reconcile in the contract. Accepting an onboarding goal candidate (BE2.1) creates a goal here.

### BE4.2 · Goal evidence                                                  size: M
Place: goals › one goal › said vs did · agent `GET /goals/:userId/:goalId/evidence` over `readSaidVsDid` (§9.5); door `GET /v2/goals/:id/evidence`. Needs BEA.2.

### BE4.3 · Check-in push                                                  size: M
Place: goals › check-ins · Needs: BE2.7, BEA.4 · Known: a scheduled per-goal check-in using `POST /notifications/generate` (§8.4) for copy, behind a flag; the push payload stays content-free, the copy lives in the app after open. Respect quiet hours (contract 04 question).

---

## Phase 5 · You (contract 05, later)

Tree: **you** › people (BE5.1) › portrait (BE5.2) › what I know, by area (BE5.3) › search (BE5.4).

### BE5.1 · People                                                         size: M
Agent `GET /people/:userId` over `pulls.significantPeople`; door `GET /v2/people` plus the existing held-pair routes (`/people/:userId/held…`) through the kit. Needs BEA.2.

### BE5.2 · Portrait                                                       size: M
Agent `GET /portrait/:userId` over `buildPortrait` (§9.1); door `GET /v2/portrait`. No model calls; cacheable per user per day.

### BE5.3 · What I know, by area, with sureness                           size: M
Agent `GET /understanding/:userId` over `readUnderstanding` (§9.2) grouped by the 8 areas, with confidence → sureness (the BE1.6 constant), `silent` domains omitted with their label, "moved this week" from `moves`. Door `GET /v2/understanding`. Also the missing route for confirming or rejecting an answer (`record_answer_verdict`, §10.4 gap): `POST /v2/understanding/answers/:id { verdict }`.

### BE5.4 · Search                                                         size: M (split: sources · answer)
Doors `POST /v2/search/sources` (`read`), `POST /v2/search/answer` (`expensive`), `GET /v2/search/source/:kind/:id` (ownership). Founder shape ([search-v1-shape]): written synthesis on top, inspectable sources below, abstains when empty: the door passes the abstain state as a first-class outcome.

---

## Phase 6 · Settings and account (contract 06, later)

Tree: **settings** › brief time (BE6.2) › voice, how straight, ambient, what I've learned (BE6.1) › export (BE6.3) › subscription (BE6.4) › delete data / account (BE0.7, BE0.8).

### BE6.1 · Settings doors                                                 size: M (split: existing routes · voice)
Doors over `GET|PUT /settings/:userId/ambient | appetite`, `GET /settings/:userId/learning`, `PATCH /preferences/:userId` (BEA.3; never `PUT`), and a new agent `PUT /settings/:userId/voice { persona, speed, mode }` writing `users.voice_persona` plus new columns. The founder's master ambient switch ([ambient-switch]) stays an admin control, never a door.

### BE6.2 · Brief time per user                                            size: M
Replace the fixed 08:00 UTC cron with a per-minute scheduler that picks users whose local brief time has come (`users.time_zone` + `users.brief_time`), idempotent per user per local day (unique `(user_id, brief_date)` where `brief_date` becomes the local day: this is where contract 02's "local day" becomes true). Honour `daily_brief_enabled` (D7: off by default). Production switch-on is founder decision D10.

### BE6.3 · Export my data                                                 size: L (split: agent zip job · door + link)
Agent `POST /users/:userId/export` builds a zip (JSON per table, audio files) in a private bucket under `exports/<userId>/`; door `POST /v2/account/export` returns a job; `GET /v2/account/export/:id` gives a signed link that expires in 24 hours; the zip is deleted after 7 days; a content-free push when ready. Paginates every table (never `select('*')` without limits); excludes embeddings.

### BE6.4 · Manage subscription                                            size: S
`GET /v2/entitlement` already carries renewal and trial state; close this byte unless contract 06 asks for more.

---

## Phase 7 · Retire the old (after the version floor passes)

### X07 · Remove the old routes                                            size: M (one PR per route group)
Remove `/claude/generate`, `/pipeline/*`, `/goals/extract*`, the synchronous podcast route, the old `/auth/signin` 30-day JWT and `/auth/refresh`, `POST /graph/assertions/:id/feedback`, and `audio_url` writes; each only after 14 days with no calls from supported versions (proved from the door and access logs, counts only). Then the founder-approved step: make `podcast-audio` private (BEA.7).
Needs: BE0.10 floor raised (`REQUIRE_APP_VERSION` on), the integrator's go.

### X08 · Retire legacy brain tables                                      size: M
Agent: drop the legacy `observations` / `insights` tables and the Cook 0 `user_understanding` path (if BE2.1 confirmed nothing reads it), after a backup the founder confirms. A migration that only drops after checking nothing in `src/` references them (a test greps the code).
