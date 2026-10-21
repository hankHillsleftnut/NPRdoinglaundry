# Backend · phase 0 cards: foundations

Every card follows [../byte-card.md](../byte-card.md). Read [../backend-engineer.md](../backend-engineer.md) §4 (the door), [../reference/backend-reference.md](../reference/backend-reference.md) and [../reference/agent-api-reference.md](../reference/agent-api-reference.md) before the first card. Line numbers are `origin/main` as of 21 Oct (backend `a679fec`, agent `a886060`); re-read the file before editing, because lines move.

**Migration numbers are assigned here so two bytes never collide.** Backend (`supabase/migrations/`, 3 digits): `005_sessions.sql` (BE0.4), `006_apple_tokens.sql` (BE0.5), `007_invites.sql` (BE0.12), `008_door_limits.sql` (BE0.9), `009_daily_costs.sql` (BE0.11), `010_entitlements.sql` (BE2.8), `011_devices.sql` (BE2.6), `012_google_identity.sql` (BE2.4). Agent (`supabase/migrations/`): `152_correction_writes.sql` (BEA.1), `153_spend_ledger.sql` (BEA.4), `154_podcast_audio_paths.sql` (BEA.7), `155_brief_audio.sql` (BE1.3b), `156_podcast_jobs.sql` (BE2.5a), `157_episode_chapters.sql` (BE3.0). A byte that needs a number not listed asks the integrator.

**Every migration in both repos follows the agent's house style:** additive (`CREATE TABLE IF NOT EXISTS`, `ADD COLUMN IF NOT EXISTS`), a header comment with the goal and why, RLS enabled, `REVOKE ALL … FROM PUBLIC, anon, authenticated`, an explicit `GRANT … TO service_role`. Files only: never applied to production by an agent.

---

### BE0.S · Local staging                                                size: M
Place in the tree: platform › environments › local staging
Repo · branch: both · `be/BE0.S-local-staging` (backend), `agent/BE0.S-local-staging` (agent)
Needs: founder action (a second Supabase project, `retrospect-staging`)      Unblocks: every proof, T08

Why: agents can test everything against real services without ever touching a real person's data, for free, and moving to Render staging later is configuration only (founder, 21 Oct).

Inputs:
- Reference: backend-reference §5 (config keys), §14 (`render.staging.yaml` variable names); agent-api-reference §12.2 (migrate script)
- Code anchors: `backend/src/utils/config.ts` (`requireEnv`, the 8 required variables), `backend/render.staging.yaml`, agent `scripts/migrate.ts`, agent `src/db/migrate.ts`, agent `render.staging.yaml`

Spec:
- `backend/.env.staging.example` and agent `.env.staging.example`: every variable **name** from the two `render.staging.yaml` files plus the ones this plan adds (`INVITE_CODE_KEY`, `APPLE_*`, `REVENUECAT_*`, `APNS_*`, `MIN_APP_VERSION`, `STAGING_DAILY_CAP_USD`), placeholder values that can't look like real keys (gitleaks). Real values live only in untracked `.env.staging` files on the Mac; confirm both `.gitignore` files cover `.env.staging` and add the line if not.
- Scripts: backend `"dev:staging": "tsx watch --env-file=.env.staging src/server.ts"` (after BE0.2; until then `src/index.ts`), port 3000; agent `"dev:staging"` the same pattern, port 3001; `AGENT_SERVICE_URL=http://localhost:3001`; `RETROSPECT_ENV=staging`; `NODE_ENV=development` so `/auth/dev/test-user` works locally; every agent cron flag off.
- Migrations onto the staging project, in order: backend `001…004` (Supabase SQL editor or `supabase db push` against the staging project, whichever the founder's setup allows; record which), then agent `100…151` via `npm run db:migrate -- --apply` with `DATABASE_URL` set to the staging project. The storage bucket `podcast-audio` is created by hand (no migration creates it): private, per BEA.7.
- `scripts/staging-seed.ts` (backend): creates staff test users through the dev route and inserts invented content: `fresh` (nothing), `day-one` (onboarding answers only), `month` (30 days of invented typed and voice entries, one brief, two guesses, one episode row with a placeholder audio path). All rows carry `metadata.test_account = true`. Never real text.
- `STAGING_DAILY_CAP_USD` (default 5): the agent refuses model calls once the whole staging project has spent it in 24 hours (wired in BEA.4).
- `docs/team/staging.md`: how to start both services, seed, reset (drop and re-seed test users), and the one-hour move to Render staging.

Steps: example env files → scripts → migrations applied to staging (record) → bucket → seed script → doc.

Acceptance:
- Both services start with `npm run dev:staging`; `GET /health` (backend) and agent `/health/ready` return 200.
- `POST /auth/dev/test-user` returns a token on local staging; the seed script creates the three accounts and can be re-run without duplicates.
- No real secret appears in any committed file (gitleaks green).

Tests:
- (layer 3) `the seed script is idempotent: running it twice leaves three test users`. (Against PGlite-free logic: the script's user-creation function is unit-tested with a fake client.)

Proof in the PR: terminal output of both health checks (no secrets), the applied-migration list, the seed run.

Watch out: the staging project's keys must never be pasted into a PR, a report or a log; `RETROSPECT_ENV=staging` must reach Sentry so staging errors don't look like production ones.

---

### BE0.0 · Runtime hygiene the doors depend on                         size: M
Place in the tree: platform › server › hygiene
Repo · branch: backend · `be/BE0.0-runtime-hygiene`
Needs: —      Unblocks: BE0.1, every door, PL2.2 (idempotency on every type)

Why: doors rely on knowing who the client is, on errors meaning what they say, and on retries never creating duplicates; today none of those hold (backend-reference §0 findings 1, 2, 6, 7, 9, 10).

Inputs:
- Reference: backend-reference §0, §2, §3, §4, §10, §13
- Code anchors: `src/index.ts:23` (no trust proxy), `:42-50` (global limiter), `:120-121` (timeouts); `src/routes/auth.ts:18-58`, `:101-130`; `src/middleware/auth.ts:90-136` (`getOrCreateUser`); `src/routes/admin.ts:13-24`; `src/utils/config.ts:67` (`ADMIN_SECRET` default); `src/services/content-insert.ts:72`; `src/routes/content.ts:73`; `package.json` `engines`; `render.yaml`, `render.staging.yaml`

Spec:
1. `app.set('trust proxy', 1)` right after `const app = express()`.
2. Global limiter: `skip: (req) => req.path === '/health' || req.path.startsWith('/v2')`. Doors have their own per-user limits (BE0.1).
3. Timeouts: `server.headersTimeout = 125_000` (above `keepAliveTimeout` 120 s).
4. Node: `engines.node` `">=22.12"`; add `NODE_VERSION` (value `22.12.0`) to both Render blueprints; ask the integrator to raise CI's `node-version` to 22 (workflows are theirs).
5. Apple errors: in `/auth/signin` and `/auth/refresh`, a `jose` verification error (`JWTExpired`, `JWSSignatureVerificationFailed`, `JWTClaimValidationFailed`, `JWKSNoMatchingKey`) returns `401 { success:false, error:'Invalid Apple identity token' }`; anything else stays 500 with the generic message.
6. `getOrCreateUser` becomes an upsert: `insert(…).onConflict('apple_user_id').ignore()` then select, or `upsert({ apple_user_id, email }, { onConflict: 'apple_user_id', ignoreDuplicates: false })` then select; the email update keeps its current rule.
7. Admin: delete the hard-coded default (`ADMIN_SECRET` becomes optional with no default; when absent, `/admin` and `/dashboard` are not mounted and the server logs one warning); accept the secret only from the `x-admin-secret` header; compare with `crypto.timingSafeEqual` over equal-length buffers; update `src/public/dashboard.html` to send the header instead of `?secret=`.
8. Idempotency: in `content-insert.ts`, enforce the key for every class when an explicit key is present (`enforce = derived.strategy === 'explicit_key' || derived.dedupClass !== 'singleton'`); reject keys over 128 characters with `400 'Idempotency-Key too long'`; on a duplicate by explicit key, compare a SHA-256 of `(contentType, content)` stored in `metadata.request_hash` at insert; a mismatch returns `409 { success:false, error:'Idempotency-Key reused with a different body' }`.

Steps: 1–4 → 5–6 → 7 (with the founder action below) → 8 → tests.

Acceptance:
- `req.ip` is the client's address behind a proxy (proven in a test with `X-Forwarded-For`).
- `/health` and any `/v2` path are never counted by the global limiter.
- A bad or expired Apple token gets 401, not 500; two concurrent first sign-ins for the same Apple id both succeed and return the same user id.
- `/admin` isn't mounted without `ADMIN_SECRET`; a `?secret=` query is ignored; the header works.
- An `onboarding_profile` upload repeated with the same key returns 200 `Idempotency-Replayed: true` and never a second row; a reused key with a different body gets 409.

Tests (layers 3, plus units):
- `trust proxy makes req.ip the forwarded client`
- `the global limiter ignores /health and /v2`
- `an expired Apple identity token is a 401, not a 500` (inject a verifier that throws `JWTExpired`)
- `two first sign-ins at once create one user` (fake client returning 23505 on the second insert)
- `admin routes are absent without a secret` · `the admin secret is read from the header only` · `admin secret comparison is constant-time` (assert `timingSafeEqual` is used through a spy)
- `an explicit key is enforced for singleton content` · `a reused key with a different body is a 409` · `a key over 128 characters is refused`

Proof in the PR: test output; the before/after route list (`/admin` present only with the secret).

Watch out: **founder action before this deploys:** set `ADMIN_SECRET` on Render, or admin stops working (the integrator raises it). Don't change the response shape of any existing route beyond what's listed: the old app depends on them.

---

### BE0.1 · Door kit, error envelope, structured log                     size: L (split if it grows: kit · limits · log)
Place in the tree: platform › doors › the kit
Repo · branch: backend · `be/BE0.1-door-kit`
Needs: BE0.0      Unblocks: every `/v2` door

Why: every app capability goes through one shape, so security, limits, errors and logs are right once instead of 35 times.

Inputs:
- Contract: `contracts/00-platform.md` §1–§2 (headers, envelope, error codes)
- Reference: backend-reference §7 (`CallLog`, the pattern to generalise), §16 (mount point, async errors)
- Code anchors: `src/services/claude-guard.ts:36-64`; `src/index.ts:82-84` (mount between these); `src/middleware/auth.ts:16-75`

Spec:
- `src/doors/errors.ts`: `type DoorErrorCode` = the contract's closed list (`invalid_request`, `invalid_credentials`, `unauthenticated`, `session_revoked`, `invite_required`, `suspended`, `not_found`, `idempotency_mismatch`, `update_required`, `rate_limited`, `spend_limited`, `upstream_timeout`, `upstream_unavailable`, `internal`, plus the invite codes from contract 00 §4); `class DoorError extends Error { code; status; retryAfterSeconds? }`; `sendError(res, err)` writes `{ success:false, error:{ code, message, retryAfterSeconds? } }` with a plain-words message per code (the contract's table); `fromAgentError(err)` maps agent failures: agent 400 → `invalid_request` (logged as a bug, never shown raw), 404 → `not_found`, 429 with `spentUsd` → `spend_limited`, other 429 → `rate_limited`, timeout → `upstream_timeout`, 5xx or network → `upstream_unavailable`. **Agent messages are never forwarded** (they carry raw Postgres text, agent-api-reference §11).
- `src/doors/limits.ts`: `interface Limiter { take(userId, bucket, now): { ok: true } | { ok: false, retryAfterSeconds } ; recordSpend(userId, usd, now): void; spentToday(userId, now): number }`; `MemoryLimiter` implementing it (rolling windows per bucket: `read` 120/min, `write` 30/min, `expensive` 10/min and 60/hour; spend window 24 hours), constants in one exported object so tests read them.
- `src/utils/log.ts`: `log.door({ door, userId, status, code?, ms, agentMs?, costUsd?, appVersion })`, one JSON line on stdout. The parameter type has no field that can carry text; add a lint-style unit test that the type's keys are exactly these.
- `src/doors/door.ts`: `createDoor<Req, AgentRes, Res>({ name, bucket, owns?: (ctx, req) => Promise<boolean>, request: ZodSchema<Req>, call: (ctx, req) => Promise<AgentRes>, map: (r: AgentRes, ctx) => Res })` returns an Express handler that: reads `req.user` (set by `authMiddleware`); validates `X-App-Version` presence (logged, not required until BE0.10); stores `X-Time-Zone` if it changed (needs `users.time_zone`, added in `005_sessions.sql`; until then, read only); validates with zod (`invalid_request` with no detail echoed); runs `owns` and returns `not_found` when false; takes the limiter; awaits `call` inside try/catch; maps; sends `{ success:true, data }`; logs. Every rejection reaches `sendError` (Express 4 doesn't catch async rejections).
- `src/doors/agent.ts`: a door-side agent client `agent.get/post/put(path, body, { timeoutMs, retry: 'none' | 'read' })` built on the same `X-Internal-Secret` header as `callAgent`, with injectable `fetch`; `read` retries once on timeout, 502, 503, 504; `none` never retries. The old `callAgent` stays untouched for old routes.
- `src/doors/router.ts`: `v2Router` with `GET /v2/ping` → `{ userId }` as the sample door; mounted in `index.ts` between lines 82 and 84 as `app.use('/v2', authMiddleware, v2Router)`; public `/v2` routes (auth, meta, public waitlist) are mounted before `authMiddleware` in later bytes.

Steps: errors → limits → log → agent client → door → router + mount → tests.

Acceptance:
- `/v2/ping` works through the kit and passes the nine door tests (backend-engineer §4) once BE0.2's harness exists; in this PR, the kit's units are tested directly.
- No existing route's behaviour changes (route list before and after identical except `/v2/ping`).

Tests (units):
- `the limiter allows exactly the bucket's limit per window and then reports retryAfter`
- `another user's usage never affects a user's limit`
- `spend over the daily cap is reported until the window rolls`
- `an agent 429 with spentUsd becomes spend_limited` · `an agent timeout becomes upstream_timeout` · `an agent 500 never leaks its message`
- `a door that throws asynchronously still answers with the envelope`
- `the door log type has no field that can carry text`
- `owns() false answers not_found, not forbidden`

Proof in the PR: test output; the route list.

Watch out: the global error handler writes a 500 JSON body; the kit must never fall through to it. Keep the kit free of Supabase imports (dependencies are passed in), or BE0.2 can't test it.

---

### BE0.2 · App factory and HTTP test harness                            size: M
Place in the tree: platform › doors › the harness
Repo · branch: backend · `be/BE0.2-app-factory-harness`
Needs: BE0.1      Unblocks: every door's tests (T07)

Why: today the server can't be loaded in a test without opening a port and needing eight secrets, so no route has ever been tested over HTTP (backend-reference §0 finding 3, §8, §16).

Inputs:
- Reference: backend-reference §2, §3, §8
- Code anchors: `src/index.ts:23-123`; `src/utils/supabase.ts:5-14`; `src/middleware/auth.ts:47-51`; `package.json` scripts; `tests/integration-contracts.test.js`

Spec:
- `src/app.ts`: `createApp(deps: { db: SupabaseClient; agent: AgentDoorClient; limiter: Limiter; now: () => number; users: UserLookup })` builds and returns the Express app with every mount from `index.ts` in the same order. `authMiddleware` takes its user lookup from `deps.users` (a factory `makeAuthMiddleware(users)`; the old named export stays, built from the default lookup, so old imports keep working).
- `src/server.ts`: builds the real deps, calls `createApp`, `listen`s, sets the timeouts. `index.ts` becomes `export { default } from './server.js'` so `npm start` (`node dist/index.js`) is unchanged; update `dev` to `tsx watch src/server.ts`.
- `tests/support/env.ts`: sets the eight required variables to obvious placeholders (`test-only-not-a-key`) before anything imports config; `npm test` becomes `tsx --test --import ./tests/support/env.ts $(find tests -name '*.test.ts')`.
- `tests/support/harness.ts`: `startHarness({ agentRoutes, users })` starts `createApp` on port 0 with an in-memory user table, a scripted fake agent (a local `http.createServer` whose handlers each test sets), the memory limiter and a controllable clock; returns `{ url, asUser(id) → token, request(method, path, body, headers), close() }`.
- The nine door tests (backend-engineer §4 step 10) written once as `tests/support/door-suite.ts` → `doorSuite({ method, path, validBody, otherUsersThing })`, so each door's test file calls it.
- Delete `tests/integration-contracts.test.js` and `jest` from devDependencies (it never ran), or port it; say which in the PR.

Acceptance:
- `npm test` runs with no env vars set outside the test setup, and no port is opened by importing `src/app.ts`.
- The route list from `createApp` equals the pre-refactor list (a test asserts the router stack paths).
- `/v2/ping` passes the full door suite.

Tests:
- `importing the app opens no port` · `the route list is unchanged by the refactor` · the nine door-suite tests on `/v2/ping`.

Proof in the PR: `npm test` output, the route list diff (empty).

Watch out: imports are hoisted, so env must come from `--import`, never from the test file body. Render's start command is unchanged; prove it by running `npm run build && node dist/index.js` locally against local staging.

---

### BE0.3 · Error-leak cleanup and speech limits                         size: S
Place in the tree: platform › server › hygiene
Repo · branch: backend · `be/BE0.3-error-leaks-speech`
Needs: BE0.1      Unblocks: BE1.3b (brief audio uses the speech pattern)

Why: raw database and provider messages reach the old app today, and speech has no per-user limit or timeout (backend-reference §11, §12).

Inputs:
- Code anchors: `src/routes/podcasts.ts` (500 with `err.message`), `src/routes/speech.ts:39-63, 95-97, 107`

Spec:
- `podcasts.ts` and `speech.ts`: 500 bodies become the generic message; details go to `console.error` and Sentry only.
- `speech.ts`: per-user limit through the BE0.1 limiter, bucket `expensive`; each chunk fetch gets an `AbortController` with 60 s; chunks synthesise with concurrency 3 (a small pool), then concatenate in order.

Acceptance: a forced provider error returns the generic message; the 11th request in a minute returns 429; a hung provider call ends at 60 s.

Tests: `a provider error never reaches the client` · `speech is limited per user` · `a hung chunk times out` · `chunks are concatenated in order with concurrency 3`.

Proof in the PR: test output.

Watch out: the old app reads `{ success:false, error }` here, so keep that shape on old routes (only the message text changes).

---

### BE0.4 · Sessions: short tokens, rotating refresh, nonces             size: L (split: tables + issuing · refresh/rotation · v2 sign-in)
Place in the tree: platform › sign-in › sessions
Repo · branch: backend · `be/BE0.4-sessions`
Needs: BE0.2      Unblocks: BE0.5, BE0.12, BE2.4, PL1.4, PL1.5

Why: people stay signed in for as long as they use the app, silently, and a copied pass stops working quickly (founder, 21 Oct: "why do logins only last 30 days?"; sign-out everywhere is v2).

Inputs:
- Contract: `contracts/00-platform.md` §3
- Reference: backend-reference §3, §4; the research summary in README §11 (RFC 9700 rotation, grace window)
- Code anchors: `src/middleware/auth.ts:78-87` (`generateToken`), `src/routes/auth.ts`, `src/services/apple-auth.ts`

Spec:
- Migration `005_sessions.sql`: `refresh_tokens (id uuid pk, user_id → users on delete cascade, family_id uuid not null, token_hash text unique not null, created_at, expires_at not null, absolute_expires_at not null, rotated_at, replaced_by uuid, revoked_at, device_label text)`, index on `(family_id)`; `auth_nonces (nonce_hash text pk, created_at, expires_at)`; `users.time_zone text`, `users.token_version int not null default 0`.
- Access JWT: HS256 with `JWT_SECRET`, 15 minutes, claims `{ sub: userId, ver: token_version, typ: 'access' }`, `iss: 'retrospect-api'`, `aud: 'retrospect-app'`. `authMiddleware` accepts both the old 30-day shape (`userId` claim, for old app versions until X07) and the new shape (checks `typ`, `iss`, `aud`, `ver` against the user row it already loads).
- Refresh token: 32 random bytes, base64url, stored as SHA-256; 60-day sliding `expires_at`, 180-day `absolute_expires_at`.
- `POST /v2/auth/refresh { refreshToken }` (public): in one transaction with `SELECT … FOR UPDATE` on the family's rows: unknown or expired → `session_revoked`; already rotated **within 30 seconds** → return the same successor pair (store the successor's plain token encrypted for those 30 seconds only, or keep the pair in memory keyed by hash for 30 s; prefer the database so it survives a restart: `refresh_grace (token_hash pk, access, refresh_ciphertext, expires_at)`); rotated earlier → revoke the whole family, `session_revoked`; valid → mark rotated, insert the successor, return the new pair.
- `POST /v2/auth/apple { identityToken, authorizationCode, rawNonce, fullName?, email? }` (public): `jose` verification (issuer, audience = `APPLE_CLIENT_ID`, RS256), `nonce` claim must equal `sha256(rawNonce)` hex, nonce accepted once (`auth_nonces`, 10-minute TTL); user keyed on `sub`; name and email saved on first sign-in only; returns contract 00 §3's `data` (with `access` from BE0.12 once it lands; until then `{ state: 'member' }` for everyone).
- `POST /v2/auth/signout { refreshToken }`: revokes that family. (Everywhere: v2.)

Acceptance: as the contract; an old 30-day token still works on old routes; nothing in old `/auth/*` changes.

Tests (layer 3, the door suite where it applies):
- `refresh rotates and the old token stops working`
- `a retry with the just-rotated token within 30 seconds gets the same successor`
- `reuse after the grace window revokes the whole family`
- `the absolute cap ends a session even when it's used daily`
- `a nonce can be used once` · `a token without the right nonce is refused`
- `two refreshes at once for one family produce one successor` (concurrency through the harness)
- `signout revokes this device only`
- `old 30-day tokens still pass old routes`

Proof in the PR: test output.

Watch out: never log a refresh token or its hash; `JWT_SECRET` is shared with the old tokens, so don't rotate it here.

---

### BE0.5 · Apple refresh token and revocation                            size: M
Place in the tree: platform › sign-in › account rights
Repo · branch: backend · `be/BE0.5-apple-revoke`
Needs: BE0.4; founder action (Sign in with Apple key: Team ID, Key ID, `.p8`)      Unblocks: BE0.7, BE0.13

Why: App Review requires that deleting an account also revokes Sign in with Apple (Guideline 5.1.1(v), Apple TN3194).

Inputs:
- Code anchors: `src/utils/config.ts:58-63` (`APPLE_TEAM_ID/KEY_ID/PRIVATE_KEY`, unused today)

Spec:
- Migration `006_apple_tokens.sql`: `users.apple_refresh_token_ciphertext text`, `users.apple_refresh_token_at timestamptz`.
- `src/services/apple-tokens.ts`: `clientSecret()` (ES256 JWT: `iss` Team ID, `sub` bundle id, `aud` `https://appleid.apple.com`, 180-day `exp`, cached and re-minted a day before expiry); `exchangeCode(code)` → POST `https://appleid.apple.com/auth/token` (`grant_type=authorization_code`) within the sign-in request; `revoke(refreshToken)` → POST `https://appleid.apple.com/auth/revoke` with `token_type_hint=refresh_token`.
- Encryption: AES-256-GCM with `TOKEN_ENCRYPTION_KEY` (32 random bytes, base64), a fresh IV per value, stored as `v1:<iv>:<tag>:<ciphertext>`.
- Behind the flag `APPLE_REVOKE_ENABLED` until the founder's key exists; sign-in still succeeds if the exchange fails (logged as a count).

Acceptance: sign-in stores Apple's refresh token encrypted when the code exchange works; `revoke` sends the right request; with the flag off nothing calls Apple.

Tests: `the client secret is a valid ES256 JWT with the right claims` (signed with a throwaway test key generated in the test) · `a failed code exchange doesn't fail sign-in` · `tokens are encrypted at rest and decrypt to the same value` · `revoke posts token_type_hint=refresh_token`.

Proof: test output.

Watch out: the authorization code lives about five minutes and works once: exchange it inside the sign-in request, never later.

---

### BE0.12 · Invite-only: waitlist, approval links, three invites each     size: L (split: tables + gate · redeem + links · admin)
Place in the tree: platform › access › invites
Repo · branch: backend · `be/BE0.12-invites`
Needs: BE0.4      Unblocks: PL1.7, the invite screens, M14

Why: Retrospect is invitation-only: you get in through a friend's link (or the founder's), which applies itself after sign-in; "you've just been given a gift" (founder, 21 Oct).

Inputs:
- Contract: `contracts/00-platform.md` §4
- The founder's rules (context.md §2): the founder approves each waitlister, which makes a link the founder sends personally; every approved person gets three single-use links, generated automatically; a member's link lets a friend straight in; existing users are grandfathered.

Spec:
- Migration `007_invites.sql`:
  - `users.access text not null default 'waitlisted' check (access in ('waitlisted','approved','member','staff','suspended'))`, then `update users set access = 'member'` for every existing row (in the same migration, before the default applies to new rows).
  - `invites (id uuid pk, code_hash text unique not null, code_ciphertext text, kind text check (kind in ('founder','member','review')), owner_user_id uuid → users on delete cascade, created_at, used_by_user_id uuid → users on delete set null, used_at, revoked_at, expires_at)`.
  - `waitlist (id uuid pk, source text check (source in ('app','web')), user_id uuid unique → users on delete cascade, email text, name text, reason text, status text default 'waiting' check (status in ('waiting','approved','declined')), invite_id uuid → invites, created_at, decided_at)`, unique index on `lower(email)` where `email is not null`.
- Codes: 13 Crockford base32 characters from `crypto.randomBytes` (65 bits), stored as `sha256(normalised)`; `code_ciphertext` (AES-GCM, `INVITE_CODE_KEY`) kept while unused so "your invites" can show the link again; cleared at use or revoke. Link: `${INVITE_BASE_URL}/i/${code}`.
- `src/services/invites.ts`: `issueInvitesFor(userId, n = 3)` (in the same transaction as the access change); `redeem(userId, code)` (one statement: `update invites set used_by_user_id=$u, used_at=now(), code_ciphertext=null where code_hash=$h and used_by_user_id is null and revoked_at is null and (expires_at is null or expires_at > now()) returning id, owner_user_id` → then set the user `approved` and issue their three); `approve(waitlistId)`.
- Doors (contract 00 §4): `GET /v2/access`, `POST /v2/waitlist`, `POST /v2/invites/redeem` (limit 5 per 10 minutes per user and per IP), `GET /v2/invites/mine`; public `POST /public/waitlist` (per-IP limit 5 per hour, honeypot `website` must be empty, always answers `{ received: true }`).
- **The gate:** the door kit checks `users.access` (loaded once per request by `authMiddleware`): `waitlisted` → 403 `invite_required` for every door except access, waitlist and redeem; `suspended` → 403 `suspended`.
- Link page and universal links: `GET /i/:code` (public) serves a static HTML page (the inviter's first name only if the code is valid **and** unused; otherwise a neutral page; never says which), the App Store button and the open-in-app link; `GET /.well-known/apple-app-site-association` (public, `application/json`, no redirect) declares `applinks` for `/i/*` with the app id `<TEAM_ID>.com.shauryanarang.Retrospect`. Served from this backend under `INVITE_BASE_URL` unless the founder's website hosts them (founder: the domain).
- Admin (admin-secret header from BE0.0): `GET /admin/waitlist?status=`, `POST /admin/waitlist/:id/approve` (creates a `founder` invite for that person; returns `{ code, link }` once), `POST /admin/waitlist/:id/decline`, `POST /admin/invites { count, kind: 'founder'|'review', expiresAt? }` (plain codes and links once), `GET /admin/invites` (who invited whom, used or not), `POST /admin/invites/:id/revoke`, `POST /admin/users/:id/invites { add }`, `POST /admin/users/:id/suspend`. A small section on `/dashboard` for approve (with copy link), invite usage and revoke.

Acceptance:
- Every existing user is `member` after the migration; a new sign-in is `waitlisted`.
- A link redeemed once works; the same link a second time is `invite_used`; two concurrent redemptions: one succeeds.
- Redeeming makes the person `approved` with exactly three unused invites; `GET /v2/invites/mine` shows their links.
- A waitlisted user gets 403 `invite_required` on `/v2/ping`.
- The public waitlist can't be used to learn whether an email exists.

Tests (door suite on each door, plus):
- `existing users are grandfathered as members` (migration test)
- `a single-use invite works once, even with two redemptions at once`
- `redeeming gives exactly three invites, and a retried redeem never gives six`
- `a revoked or expired invite can't be used`
- `the gate refuses waitlisted users everywhere but access, waitlist and redeem`
- `redeem is rate-limited per user and per IP`
- `the public waitlist answers the same for new and known emails`
- `the link page never reveals whether a code is valid`
- `approving a waitlister creates exactly one founder invite and returns its link once`
- `codes are stored only as hashes, and links decrypt only while unused`

Proof: test output; the apple-app-site-association response.

Watch out: never log a code, a link or an email (counts only); `INVITE_CODE_KEY` is a new secret for the founder to set; the page must not set cookies.

---

### BE0.13 · Sign in with Apple server notifications                     size: S
Place in the tree: platform › sign-in › account rights
Repo · branch: backend · `be/BE0.13-apple-notifications`
Needs: BE0.5, BE0.7      Unblocks: —

Why: when someone stops using Sign in with Apple for Retrospect from their Apple ID settings, we hear about it and act (Apple recommends it).

Spec: `POST /public/apple/notifications` verifies the signed payload with Apple's keys (`jose`, issuer Apple, audience the bundle id); `consent-revoked` → revoke all of the user's refresh-token families; `account-delete` → run account deletion (BE0.7); `email-disabled` / `email-enabled` → update the stored relay flag. Idempotent on the event's `jti`/time. Founder action: register the URL in the Apple Developer portal.

Acceptance and tests: `a forged payload is refused` · `consent-revoked ends sessions` · `account-delete runs deletion once, even if delivered twice`.

---

### BE0.6 · Delete everything: the agent's half                           size: M
Place in the tree: platform › account rights › deletion
Repo · branch: agent · `agent/BE0.6-user-delete`
Needs: —      Unblocks: BE0.7, BE0.8

Why: deleting an account removes everything, including files and connected-app grants, not just rows (Guideline 5.1.1(v)).

Inputs:
- Reference: backend-reference §9 (FK cascades; storage buckets don't cascade); agent-api-reference §7.3 (audio path), §11
- Code anchors: agent `src/routes/integrations.ts` (`accounts/revoke`), `src/pipelines/podcast-v2.ts:87-89` (audio path `podcasts/<userId>/…`), `src/db/tables.ts`

Spec:
- `POST /users/:userId/delete { confirm: 'delete' }` (internal secret): 1) revoke every OAuth grant (reuse the `accounts/revoke` engine); 2) delete storage objects under `{userId}/` in `integration-imports`, `integration-media`, `integration-evidence`, and `podcasts/{userId}/` (and `briefs/{userId}/` after BE1.3b) in `podcast-audio`, paging through `list()` 1,000 at a time; 3) return a report `{ grantsRevoked, grantsFailed, objectsDeleted: { bucket: n }, ok }`. Rows are **not** deleted here: the backend deletes the `users` row, and every foreign key cascades (41 in this repo, all `ON DELETE CASCADE`; the PR lists the check over `src/db/tables.ts`).
- Idempotent: a second call reports zeros and `ok: true`.

Tests (PGlite + a fake storage): `deleting one user's files leaves another's untouched` · `a second delete reports zeros` · `a failed grant revoke is reported, not hidden` · `every table in tables.ts cascades from users` (a migration test that deletes a seeded user and counts rows in every table, two users, proving isolation).

Watch out: storage `list()` returns at most 1,000; loop until empty. Never delete outside the user's prefix: build paths from the id, never from listed names alone.

---

### BE0.7 · Account deletion door                                          size: M
Place in the tree: platform › account rights › deletion
Repo · branch: backend · `be/BE0.7-account-deletion`
Needs: BE0.6, BE0.5, BE0.4      Unblocks: BE0.13, ST-9, R05

Why: one tap in settings deletes the account and everything in it.

Spec: `DELETE /v2/account { confirm: 'delete' }`: agent `POST /users/:id/delete` (timeout 120 s, retry `none`) → Apple revoke (BE0.5, if a token is stored) → RevenueCat subscriber delete (after BE2.8) → revoke all refresh tokens → `delete from users where id = $1` → `{ deleted: true }`. A `deletions (id, user_id, step, status, error_code, at)` log row per step (no content) lets a failed run resume; a repeated call continues from the first unfinished step. Bucket `write`; owns: the user themselves.

Tests (door suite + ): `deletion removes the user and every row` · `a failure mid-way resumes on retry` · `a deleted user's token stops working immediately`.

Watch out: deleting the account doesn't cancel an App Store subscription; the app says so (contract 06). Order matters: revoke grants and files before the row, or the paths are lost.

---

### BE0.8 · Delete my data, keep my account                                size: M
Place in the tree: platform › account rights › deletion
Repo · branch: agent then backend · `agent/BE0.8-delete-data`, `be/BE0.8-delete-data`
Needs: BE0.7      Unblocks: ST-5

Spec: agent `POST /users/:userId/delete-data`: the same files and grants as BE0.6, then deletes the user's rows in every content table (raw_content, assertions and evidence, entities, patterns and whys, question answers and evidence, briefs, episodes, hypotheses, conversation turns, integration data, reference items, traces) inside one transaction, keeping `users`, `user_preferences` reset to defaults. Backend `DELETE /v2/account/data { confirm: 'delete' }` calls it, keeps sessions, entitlement and invites, resets `access` from `member` to `approved` (onboarding runs again).

Tests: `delete-data keeps the account, sessions and subscription` · `every content table is empty for the user afterwards, and full for another user` · `the person goes back to onboarding`.

---

### BE0.9 · Shared limiter store                                           size: S
Place in the tree: platform › doors › limits
Repo · branch: backend · `be/BE0.9-limiter-store`
Needs: BE0.1      Unblocks: any second instance; the first ship gate

Spec: migration `008_door_limits.sql`: `door_limits (user_id, bucket, window_start, count, primary key (user_id, bucket, window_start))`, `door_spend (user_id, day date, usd numeric(10,4), primary key (user_id, day))`; `PostgresLimiter` implements `Limiter` with one upsert per `take`; `LIMITER=postgres|memory` (memory stays for tests and local).

Tests: the BE0.1 limiter tests run against both implementations (PGlite-free: a fake client for the Postgres one) · `a restart doesn't reset a user's limits`.

---

### BE0.10 · Minimum app version                                             size: S
Place in the tree: platform › releases › version floor
Repo · branch: backend · `be/BE0.10-version-floor`
Needs: BE0.1      Unblocks: PL1.6, X07

Spec: `MIN_APP_VERSION` (`1.0 (40)` format); the kit compares `X-App-Version` (build number) and returns 426 `update_required`; a missing header is allowed until `REQUIRE_APP_VERSION=true`; `GET /v2/meta` (public) returns `{ minVersion, latestVersion, serverTime, environment }` (contract 00 §5).

Tests: `an old build gets update_required` · `a missing header passes until required` · `meta is public`.

---

### BE0.11 · Cost per user, measured                                         size: M
Place in the tree: platform › observability › cost
Repo · branch: agent then backend
Needs: BEA.4      Unblocks: O02, every ship gate's "cost logged"

Spec: agent `GET /runs/costs?from=&to=` (internal) returns per user per day `{ userId, day, usd, byKind }` from the spend ledger (BEA.4); backend migration `009_daily_costs.sql` `daily_costs (user_id, day, usd, by_kind jsonb, is_test bool)` and a daily job behind `ENABLE_COST_ROLLUP` that copies yesterday's numbers, marking test accounts (`metadata.test_account`). Counts and money only.

Tests: `test accounts are marked and excluded from totals` · `a day with no spend writes nothing`.
