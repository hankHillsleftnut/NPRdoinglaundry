# Backend reference — retrospect-main/backend at origin/main

Snapshot: `origin/main` = `a679fec` (2026-10-21 12:18 -0700). Includes e1f16b9 (ElevenLabs proxy). The local working branch `redesign/integrations-page-theme` is BEHIND origin/main for backend (it lacks `tsconfig.test.json`, `tests/status-writer.test.ts` and ~1,700 lines) — always read with `git show origin/main:<path>`.
Agent repo cross-references: `/Users/shauryanarang/Projects/retrospect-agent` at `origin/main` = `a886060` (fetched 2026-10-21).
All line numbers are origin/main. No secret values are reproduced here.

Sections
0. Top findings (read first)
1. package.json, tsconfig.json, tsconfig.test.json
2. src/index.ts — structure, middleware order, mounts, timeouts, Sentry
3. src/middleware/auth.ts
4. src/routes/auth.ts (+ services/apple-auth.ts)
5. src/utils/config.ts (+ utils/supabase.ts, .env.example)
6. src/services/agent-client.ts
7. src/services/claude-guard.ts (+ routes/claude.ts)
8. Test conventions (claude-guard.test.ts in full + others)
9. Schema: users, raw_content, dedup, storage buckets, FK cascades
10. src/routes/content.ts — Idempotency-Key / dedup
11. podcasts.ts, integrations.ts — response shapes, provider ids
12. speech.ts
13. admin.ts
14. render.yaml / render.staging.yaml
15. .github/workflows
16. Conflicts for a `/v2` router and SSE

---

## 0. Top findings (read first)

1. **No `trust proxy`** (index.ts has none). Render terminates TLS at a proxy, so `req.ip` is the proxy's address. The global `express-rate-limit` (index.ts:42-50, default 100 req / 15 min, keyed by IP) therefore very likely buckets many users together. express-rate-limit 7.5.1 also runs a validation that logs `ERR_ERL_UNEXPECTED_X_FORWARDED_FOR` when X-Forwarded-For is present and trust proxy is false. Any per-user limiter, invite gate or SSE must not depend on `req.ip` until `app.set('trust proxy', 1)` is added.
2. **The global limiter covers everything**, including `/health`, `/admin`, `/auth` and any future `/v2` SSE route, because it is `app.use(limiter)` at index.ts:50, before every route. Each SSE connect or reconnect counts as one request. 100 per 15 min per IP is small for an app that polls.
3. **Importing index.ts has side effects.** It calls `app.listen` at import time (index.ts:114) and does `export default app` (index.ts:123). `config.ts` throws on a missing required env var at import (`requireEnv`, config.ts:5-11). `supabase.ts` builds the service-role client at import (supabase.ts:5-14). `routes/claude.ts:6` holds a module-level `CallLog`. **No app factory exists**: an HTTP harness needs a `createApp(deps)` split from `listen`, plus env set before any `src/` import.
4. **Module system: the code is CommonJS, not ESM.** package.json has **no `"type"` field**. tsconfig uses `module`/`moduleResolution: NodeNext`, so tsc emits CJS. Source imports carry `.js` suffixes, and index.ts:53 uses `__dirname`, which is CJS-only. `jose@6.2.3` is ESM-only (`"type":"module"`, its exports have only `default`), so `require('jose')` in dist relies on Node's require(esm): unflagged in Node ≥20.19 / ≥22.12. `engines` says `>=18.0.0` and render.yaml pins no Node version. Pin `engines.node` (local is v22.16.0; CI uses 20). Because of hoisting, a test cannot set `process.env` above its `import` lines: tsx compiles the test to CJS and the imports are hoisted. Use a setup module imported first, or `--import`/`--require`, or dynamic `await import()`.
5. **The Apple JWT is the only session.** `generateToken` signs `{userId, appleUserId}` with HS256 `JWT_SECRET`, `expiresIn: '30d'` (config.ts:52-55). There is no refresh token, no `jti`, no token version and no revocation. `/auth/refresh` (auth.ts:101-130) is not a refresh. It needs a fresh Apple identity token and the full SignInSchema, and it only re-signs. The auth middleware checks only signature and that the user row exists (auth.ts:47-59), so deleting the user row is the only kill switch today. `apple.teamId/keyId/privateKey` are read in config.ts:58-63 but **never used**: no client-secret JWT, no `/auth/token` code exchange and no `/auth/revoke`. The iOS client sends only `identityToken`, not `authorizationCode`, so Apple revocation needs a schema change.
6. **Errors from Apple verification return 500, not 401.** `verifyAppleIdentityToken` throws on a bad, expired or wrong-audience token. That exception lands in the catch at auth.ts:51/123 and comes back as `500 'Failed to sign in'` / `'Failed to refresh token'`. Only a subject mismatch gives 401.
7. **The Idempotency-Key is ignored for `onboarding_profile`.** content-insert.ts:72 sets `enforce = derived.dedupClass !== 'singleton'`. The class comes from the content type, not from the strategy. So an explicit key on a singleton type yields `strategy: 'explicit_key'`, but the row is written **unkeyed**, and a replay inserts again (and starts a second ingest). Keys are also scoped per `(userId, contentType)`: the same key with a different type does not collide. The header has no length cap. The server does not compare the replayed body with the original, so a reused key with different content silently returns the old row.
8. **`GET /podcasts` returns `select('*')` (podcast-db.ts:11,31,43).** The agent repo adds `podcast_episodes.summary_embedding vector(3072)` (agent migration 100_agent_extensions.sql:45), so every listed episode ships a ~3,072-float vector plus the full `script`. A v2 shape should project columns explicitly.
9. **The admin auth is weak.** admin.ts:15-22 accepts the secret from `?secret=` (the dashboard sends it in the query string, dashboard.html:1405, so it lands in access logs) or from `x-admin-secret`, with a plain `!==` compare (not constant-time). config.ts:67 has a **hard-coded default** for `ADMIN_SECRET`, and **neither render.yaml nor render.staging.yaml declares `ADMIN_SECRET`**. Unless it was set by hand in the Render dashboard, prod falls back to the default. Admin exposes every user's raw content (`GET /admin/content?userId=`), creates users, and triggers paid podcast and ingest runs.
10. **Timeouts:** `server.timeout = 300_000` and `keepAliveTimeout = 120_000` (index.ts:120-121). `server.timeout` is socket inactivity, so an SSE stream with heartbeats under 5 min survives it. Node's default `requestTimeout` (300 s) covers only receiving the request. `headersTimeout` is left at its default (60 s), which is below `keepAliveTimeout`. That inversion is a known source of 502s behind proxies, so it is worth setting `headersTimeout > keepAliveTimeout` when touching this. Agent calls run up to 450 s (agent-client.ts:38), longer than `server.timeout`, but the socket is idle only from the client's point of view. Watch this on long synchronous routes such as `/podcasts/generate`.
11. **The 404 handler is the last middleware** (index.ts:104-109), with the error handler just before it (index.ts:85-101). A `/v2` mount must go between line 82 and line 84. The error handler always responds with JSON `{success:false,error}`. That is fatal for SSE after headers are flushed (`res.status` after `res.write` throws ERR_HTTP_HEADERS_SENT), so a v2 stream must handle its own errors. Express 4.22 does **not** forward rejected promises from async handlers; every route here wraps its body in try/catch by convention.
12. **CI runs on a self-hosted macOS runner with no env vars** (`[self-hosted, macOS, retrospect]`, Node 20): `npm ci && npm run build && npm run typecheck && npm test` in `backend/` (quality.yml:9-26). Every test today imports only pure modules. Any test that touches `config.ts` or `supabase.ts` must supply dummy env itself (pattern: tests/integration-contracts.test.js:1-28). That file is a **Jest** file using `require('../dist/...')`, and `npm test` never runs it (the glob is `*.test.ts`). `jest` sits in devDependencies unused. There is no lint step in CI and no ESLint config file in the backend.

Other notable items:
- No compression middleware, so SSE needs no flush workaround. `cors()` runs with defaults (`*`). Helmet 7.2.0 has a custom CSP and otherwise defaults; nothing in it blocks `text/event-stream`. `express.json({ limit: '10mb' })` is global.
- `config.anthropic.model` (config.ts:28) is unused by `/claude`, which reads `process.env.CLAUDE_MODEL || 'claude-sonnet-4-6'` (claude.ts:30). `CLAUDE_MODEL` is not in render.yaml.
- The speech route ignores persona. It always uses `config.elevenlabs.voiceId` (speech.ts:96), and chunks are synthesized in parallel with `Promise.all` and concatenated.
- Account deletion: all 41 agent-repo FKs to `users(id)` and every backend FK are `ON DELETE CASCADE`. Exceptions: `raw_content.source_id → data_sources` with no action, and `insight_units.raw_content_id`/`observations.raw_content_id` with SET NULL. **Storage objects do not cascade**: buckets `integration-imports`, `integration-media`, `integration-evidence` (paths are prefixed `{userId}/…`) and `podcast-audio` (public URLs). Agent-side credentials are stored through the agent API, not here.
- No table, column or code exists today for refresh tokens, invites, device or APNs tokens, StoreKit or entitlements, or account deletion. Grep found nothing in either repo's backend schema.

---

## 1. package.json / tsconfig

`backend/package.json` (60 lines):
- `"name": "retrospect-api"`, `"version": "1.0.0"`, `"main": "dist/index.js"`, `"license": "MIT"`. **No `"type"` field, so CommonJS.**
- scripts (lines 6-18):
  - `dev`: `tsx watch src/index.ts`
  - `build`: `tsc && cp -r src/public dist/public`
  - `start`: `node dist/index.js`
  - `lint`: `eslint src/**/*.ts` (no eslint config in repo; not run in CI)
  - `test`: `tsx --test $(find tests -name '*.test.ts')`
  - `db:migrate`: `supabase db push`
  - `cron:daily|cron:weekly|cron:pipeline|cron:podcasts`: no-op `node -e "console.log('legacy … disabled …')"`
  - `typecheck`: `tsc -p tsconfig.test.json`
- dependencies (lines 27-49), as declared → locked version from package-lock:
  - `@anthropic-ai/sdk` ^0.74.0 → 0.74.0
  - `@sentry/node` ^10.58.0 → 10.58.0
  - `@supabase/supabase-js` ^2.39.0 → 2.94.1 (engines node >=20)
  - `@types/cors` ^2.8.17, `@types/express` ^4.17.21 → 4.17.25, `@types/jsonwebtoken` ^9.0.5, `@types/node` ^20.10.5 → 20.19.31, `@types/node-cron` ^3.0.11, `@types/uuid` ^9.0.7 (types sit in `dependencies`, not dev)
  - `cors` ^2.8.5 → 2.8.6
  - `dotenv` ^16.3.1
  - `express` ^4.18.2 → 4.22.1
  - `express-rate-limit` ^7.1.5 → 7.5.1
  - `helmet` ^7.1.0 → 7.2.0
  - `jose` ^6.2.3 → 6.2.3 (ESM-only)
  - `jsonwebtoken` ^9.0.2 → 9.0.3
  - `node-cron` ^3.0.3 (unused; crons disabled)
  - `openai` ^4.24.0 → 4.104.0
  - `typescript` ^5.3.3 → 5.9.3 (in dependencies, because Render's build runs `tsc`)
  - `uuid` ^9.0.1
  - `zod` ^3.22.4 → 3.25.76
- devDependencies (lines 50-56): `@typescript-eslint/eslint-plugin` ^6.15.0, `@typescript-eslint/parser` ^6.15.0, `eslint` ^8.56.0, `jest` ^29.7.0 (unused by `npm test`), `tsx` ^4.7.0 → 4.21.0.
- No `supertest` or other HTTP test dependency. No `compression`.
- `engines`: `{ "node": ">=18.0.0" }` (lines 57-59).

`backend/tsconfig.json` (26 lines): `target ES2022`, `module NodeNext`, `moduleResolution NodeNext`, `lib ["ES2022"]` (no DOM lib; `fetch` types come from @types/node 20), `outDir ./dist`, `rootDir ./src`, `strict true`, `esModuleInterop true`, `skipLibCheck true`, `forceConsistentCasingInFileNames true`, `resolveJsonModule true`, `declaration true`, `declarationMap true`, `sourceMap true`, `noImplicitAny true`, `noImplicitReturns true`, `noFallthroughCasesInSwitch true`, **`noUncheckedIndexedAccess true`** (hence the `req.params.id!` style), `exactOptionalPropertyTypes false`, `noPropertyAccessFromIndexSignature false`. `include ["src/**/*"]`, `exclude ["node_modules","dist","**/*.test.ts"]`.

`backend/tsconfig.test.json` (16 lines, JSONC with comments): `extends ./tsconfig.json`, `compilerOptions { rootDir ".", noEmit true }`, `include ["src/**/*","tests/**/*"]`, `exclude ["node_modules","dist"]`. Its purpose is to typecheck tests (CI step `npm run typecheck`). Note that `tests/integration-contracts.test.js` is `.js` and is not typechecked.

## 2. src/index.ts (123 lines)

Import order:
```
1  import express from 'express';
2  import { captureException } from './services/telemetry.js';   // Sentry.init runs here, at import
3  import cors from 'cors';
4  import helmet from 'helmet';
5  import rateLimit from 'express-rate-limit';
6  import path from 'path';
8  import { config } from './utils/config.js';                    // requireEnv throws here
9  import { authMiddleware } from './middleware/auth.js';
10 authRouter  11 contentRouter  12 goalsRouter  13 pipelineRouter  14 adminRouter
15 podcastsRouter  16 profileRouter  17 claudeRouter  18 speechRouter
19 import { integrationOauthCallbackRouter, integrationsRouter } from './routes/integrations.js';
20 graphRouter
```
Middleware / mount order:
| line | what |
|---|---|
| 23 | `const app = express();` (no `app.set('trust proxy', …)`, no `x-powered-by` disable; helmet removes the header) |
| 26-37 | `helmet({ contentSecurityPolicy: { directives: { defaultSrc ['self'], scriptSrc ['self','unsafe-inline'], scriptSrcAttr ['unsafe-inline'], styleSrc ['self','unsafe-inline'], imgSrc ['self','data:'], connectSrc ['self'] } } })` |
| 38 | `app.use(cors());` (defaults, `Access-Control-Allow-Origin: *`) |
| 39 | `app.use(express.json({ limit: '10mb' }));` (global; no urlencoded/raw parsers) |
| 42-50 | `rateLimit({ windowMs: config.rateLimit.windowMs, max: config.rateLimit.maxRequests, message: { success:false, error:'Too many requests, please try again later' } })` → `app.use(limiter)`. Global, keyed by `req.ip` |
| 53-54 | `publicDir = path.join(__dirname,'public')`; `app.use('/public', express.static(publicDir))` |
| 57-59 | `GET /dashboard` → sendFile dashboard.html |
| 62-64 | `GET /health` → `{ status:'ok', timestamp }` (no auth, but rate-limited) |
| 67 | `app.use('/admin', adminRouter)` (admin secret, see §13) |
| 70 | `app.use('/auth', authRouter)` (no auth) |
| 71 | `app.use('/integrations', integrationOauthCallbackRouter)` (no auth; only `GET /:providerId/connect/callback`) |
| 74 | `/content` authMiddleware contentRouter |
| 75 | `/goals` authMiddleware goalsRouter |
| 76 | `/pipeline` authMiddleware pipelineRouter |
| 77 | `/podcasts` authMiddleware podcastsRouter |
| 78 | `/profile` authMiddleware profileRouter |
| 79 | `/claude` authMiddleware claudeRouter |
| 80 | `/speech` authMiddleware speechRouter |
| 81 | `/integrations` authMiddleware integrationsRouter |
| 82 | `/graph` authMiddleware graphRouter |
| 85-101 | error handler `(err, req, res, next)`: `console.error`, `captureException(err,{path,method})`, `500 { success:false, error: isProduction ? 'Internal server error' : err.message }` |
| 104-109 | 404 `{ success:false, error:'Endpoint not found' }` |
| 111 | log "Legacy backend crons are disabled…" |
| 114-117 | `const server = app.listen(config.server.port, …)` (at import) |
| 120 | `server.timeout = 300_000; // 5 minutes` (comment: "Podcast generation with v3 TTS can take several minutes") |
| 121 | `server.keepAliveTimeout = 120_000;` |
| 123 | `export default app;` |

- No `headersTimeout` or `requestTimeout` override. No graceful shutdown or SIGTERM handler. No request ID or response-time middleware, no morgan or request logging.
- Sentry: `src/services/telemetry.ts:3-11` runs `Sentry.init` only if `SENTRY_DSN` is set, with `environment = RETROSPECT_ENV ?? NODE_ENV ?? 'development'`, `release = RENDER_GIT_COMMIT`, `tracesSampleRate = Number(SENTRY_TRACES_SAMPLE_RATE ?? 0.1)`, `sendDefaultPii: false`. It exports only `captureException(error, context?)` → `Sentry.captureException(error, { extra: context })`. There is no `Sentry.setupExpressErrorHandler` and no auto-instrumentation import ordering: it is imported second, after express.
- No compression. CORS is default. Trust proxy is not set.

## 3. src/middleware/auth.ts (136 lines)

```ts
// 7-14
declare global { namespace Express { interface Request { user?: AuthUser; } } }
```
`AuthUser` (types/index.ts:496-500): `{ id: string; appleUserId: string; email?: string }`.
`JWTPayload` (types/index.ts:502-507): `{ userId: string; appleUserId: string; iat: number; exp: number }`.

`authMiddleware(req,res,next): Promise<void>` (16-75):
- Requires `Authorization: Bearer <jwt>`. Otherwise `401 { success:false, error:'Missing or invalid authorization header' }`.
- `jwt.verify(token, config.jwt.secret) as JWTPayload` (37). Default algorithms; any HS-family algorithm for that secret is accepted. On failure: `401 'Invalid or expired token'`.
- DB: `supabaseAdmin.from('users').select('id, apple_user_id, email').eq('id', payload.userId).single()` (47-51). If there is no row: `401 'User not found'`. **One DB round trip per authenticated request.**
- Sets `req.user = { id, appleUserId: user.apple_user_id, email: user.email ?? undefined }`, then `next()`.
- On any other throw: `500 'Authentication error'`.

`generateToken(user: AuthUser): string` (78-87): `jwt.sign({ userId: user.id, appleUserId: user.appleUserId }, config.jwt.secret, { expiresIn: config.jwt.expiresIn /* '30d' */ })`. HS256 by default. No `iss`, `aud` or `jti`.

`getOrCreateUser(appleUserId, email?) : Promise<AuthUser>` (90-136):
- `select('id, apple_user_id, email').eq('apple_user_id', appleUserId).single()`
- if found and `email && email !== existing.email` → `update({ email }).eq('id', id)`
- else `insert({ apple_user_id, email }).select('id, apple_user_id, email').single()`. Throws `'Failed to create user'`. Not race-safe: two concurrent first sign-ins hit the UNIQUE on apple_user_id, and the second one throws, which becomes a 500.
- Columns read/written: `users.id`, `users.apple_user_id`, `users.email` only.

## 4. src/routes/auth.ts (130 lines) + services/apple-auth.ts (19 lines)

```ts
// 11-15
const SignInSchema = z.object({
  appleUserId: z.string().min(1),
  email: z.string().email().optional(),
  identityToken: z.string().min(1),
});
```
- `POST /auth/signin` (18-58): safeParse, else `400 { success:false, error:'Invalid request body', details: zodErrors }`. Then `verifyAppleIdentityToken(identityToken)`; if `verified.appleUserId !== appleUserId`, `401 'Apple identity token subject mismatch'`. Then `getOrCreateUser(verified.appleUserId, verified.email ?? email)` and `generateToken`. Response: `200 { success:true, data:{ token, user:{ id, email } } }`. Catch: `500 'Failed to sign in'` (this includes an invalid or expired Apple token).
- `POST /auth/dev/test-user` (65-98): if `config.server.isProduction`, `404 'Endpoint not found'`. Otherwise it creates `getOrCreateUser('dev-test-user:<uuid>', 'dev+<8>@retrospect.test')` and returns the same shape as signin `{ token, user:{id,email} }`. Note that **staging sets NODE_ENV=production**, so this route is 404 on staging too.
- `POST /auth/refresh` (101-130): reuses **SignInSchema** (it needs `appleUserId` and a fresh `identityToken`). 400 `'A fresh Apple identity token is required'`, 401 on mismatch. Response: `200 { success:true, data:{ token } }` (no user). Catch: `500 'Failed to refresh token'`.
- apple-auth.ts: `createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'))` at module scope (line 4), so the JWKS is cached by jose. `jwtVerify(identityToken, appleKeys, { issuer:'https://appleid.apple.com', audience: config.apple.clientId })`. Returns `{ appleUserId: payload.sub, email? }`. No nonce check, no `email_verified` / `is_private_email` handling.

## 5. src/utils/config.ts (122 lines) — names only

- line 3: `dotenv.config()` at import.
- `requireEnv(key)` (5-11): throws `Error('Missing required environment variable: KEY')` if the value is unset or empty.
- `optionalEnv(key, default)` (13-15): `process.env[key] ?? default` (an empty string is kept as empty).
- `config` (17-120, `as const`; `export type Config = typeof config`):

| path | env var | required? / default |
|---|---|---|
| supabase.url | SUPABASE_URL | required |
| supabase.serviceKey | SUPABASE_SERVICE_KEY | required |
| supabase.anonKey | SUPABASE_ANON_KEY | required |
| anthropic.apiKey | ANTHROPIC_API_KEY | required |
| anthropic.model | — | literal `'claude-sonnet-4-20250514'` (unused by /claude) |
| openai.apiKey | OPENAI_API_KEY | required |
| openai.embeddingModel | — | `'text-embedding-3-large'` |
| perplexity.apiKey | PERPLEXITY_API_KEY | default `''` |
| perplexity.model | — | `'sonar-pro'` |
| elevenlabs.apiKey | ELEVENLABS_API_KEY | default `''` |
| elevenlabs.voiceId | ELEVENLABS_VOICE_ID | has a public default voice id (the "Adam" voice) |
| elevenlabs.model | — | `'eleven_v3'` |
| elevenlabs.maxCharsPerRequest | — | `4800` |
| jwt.secret | JWT_SECRET | required |
| jwt.expiresIn | — | `'30d'` |
| apple.clientId | APPLE_CLIENT_ID | default = app bundle id `com.shauryanarang.Retrospect` |
| apple.teamId / keyId / privateKey | APPLE_TEAM_ID / APPLE_KEY_ID / APPLE_PRIVATE_KEY | default `''`. **Unused anywhere in src** |
| admin.secret | ADMIN_SECRET | **has a hard-coded non-empty default (value intentionally not printed)** |
| agent.serviceUrl | AGENT_SERVICE_URL | required |
| agent.internalSecret | INTERNAL_API_SECRET | required |
| integrations.oauthCallbackBaseUrl | INTEGRATION_OAUTH_CALLBACK_BASE_URL | default = prod onrender URL |
| integrations.appRedirectUrl | INTEGRATION_APP_REDIRECT_URL | default `retrospect://integration-connected` |
| integrations.googleClientId/Secret | GOOGLE_OAUTH_CLIENT_ID / GOOGLE_OAUTH_CLIENT_SECRET | `''` |
| integrations.spotifyClientId/Secret | SPOTIFY_CLIENT_ID / SPOTIFY_CLIENT_SECRET | `''` |
| integrations.redditClientId/Secret | REDDIT_CLIENT_ID / REDDIT_CLIENT_SECRET | `''` |
| integrations.pinterestClientId/Secret | PINTEREST_CLIENT_ID / PINTEREST_CLIENT_SECRET | `''` |
| integrations.tiktokClientKey/Secret | TIKTOK_CLIENT_KEY / TIKTOK_CLIENT_SECRET | `''` |
| integrations.linkedinClientId/Secret | LINKEDIN_CLIENT_ID / LINKEDIN_CLIENT_SECRET | `''` |
| integrations.xClientId/Secret | X_CLIENT_ID / X_CLIENT_SECRET | `''` |
| server.port | PORT | `3000` (parseInt) |
| server.nodeEnv | NODE_ENV | `'development'` |
| server.isProduction | NODE_ENV === 'production' | |
| rateLimit.windowMs | RATE_LIMIT_WINDOW_MS | `900000` |
| rateLimit.maxRequests | RATE_LIMIT_MAX_REQUESTS | `100` |
| patterns.* | — | minInsightsForCorrelation 5, minConfidenceThreshold 0.6, similarityThreshold 0.7, connectionStrengthThreshold 0.5 |
| embeddings.* | — | dimensions 3072, batchSize 100 |

Env read outside config: `SENTRY_DSN`, `RETROSPECT_ENV`, `NODE_ENV`, `RENDER_GIT_COMMIT`, `SENTRY_TRACES_SAMPLE_RATE` (telemetry.ts); `ANTHROPIC_API_KEY`, `CLAUDE_MODEL` (claude.ts:11,30).

Minimum env for importing anything that pulls config: SUPABASE_URL, SUPABASE_SERVICE_KEY, SUPABASE_ANON_KEY, ANTHROPIC_API_KEY, OPENAI_API_KEY, JWT_SECRET, AGENT_SERVICE_URL, INTERNAL_API_SECRET.

`src/utils/supabase.ts` (77 lines): `supabaseAdmin: SupabaseClient = createClient(url, serviceKey, { auth:{ autoRefreshToken:false, persistSession:false } })` at import (5-14); `createUserClient(accessToken)` (17-25, anon key + bearer); `Tables` const map (28-69): USERS 'users', DATA_SOURCES, CATEGORIES, RAW_CONTENT 'raw_content', INSIGHT_UNITS, INSIGHT_CONNECTIONS, PATTERNS, PATTERN_INSIGHTS, PROCESSING_QUEUE, ANALYTICS_CACHE, GOALS, OBSERVATIONS, INSIGHTS, PIPELINE_RUNS, PODCAST_EPISODES 'podcast_episodes', USER_UNDERSTANDING, GOAL_CANDIDATES, INTEGRATION_CONNECTIONS, INTEGRATION_SYNC_STATES, INTEGRATION_JOBS, INTEGRATION_IMPORTS, SOURCE_ASSETS, INTEGRATION_AUDIT_EVENTS, INTEGRATION_OAUTH_STATES, INTEGRATION_SYNC_RUNS, SOURCE_PAYLOADS, SOURCE_ITEMS, SOURCE_ITEM_RELATIONS, ANALYSIS_UNITS, EVIDENCE_LINKS, INTEGRATION_TEST_RUNS, ASSERTIONS, ASSERTION_EVIDENCE, ASSERTION_RELATIONS, ENTITIES, ENTITY_RESOLUTION_CANDIDATES, IDENTITY_INFERENCES. `handleSupabaseError(error): never` (72-77).

`backend/.env.example` names: SUPABASE_URL, SUPABASE_SERVICE_KEY, SUPABASE_ANON_KEY, ANTHROPIC_API_KEY, OPENAI_API_KEY, ELEVENLABS_API_KEY, ELEVENLABS_VOICE_ID, JWT_SECRET, APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY, APPLE_CLIENT_ID, ADMIN_SECRET, AGENT_SERVICE_URL, INTERNAL_API_SECRET, INTEGRATION_OAUTH_CALLBACK_BASE_URL, INTEGRATION_APP_REDIRECT_URL, the 14 provider client vars, PORT, NODE_ENV, RATE_LIMIT_WINDOW_MS, RATE_LIMIT_MAX_REQUESTS.

## 6. src/services/agent-client.ts (205 lines)

Constants: `AGENT_TIMEOUT_MS = 450_000` (38; comment: below the iOS client's 480 s), `AGENT_MAX_ATTEMPTS = 3` (39).

`async function callAgent<T>(path: string, body: Record<string, unknown>, timeoutMs = AGENT_TIMEOUT_MS, method: 'POST' | 'PUT' = 'POST'): Promise<T>` (41-123), **not exported**:
- url = `config.agent.serviceUrl.replace(/\/+$/,'') + path`.
- Per attempt: a new `AbortController` and `setTimeout(abort, timeoutMs)`. `fetch(url, { method, headers: { 'Content-Type':'application/json', 'X-Internal-Secret': config.agent.internalSecret }, body: JSON.stringify(body), signal })`.
- Reads `response.text()`, then `clearTimeout`.
- **Retries only on 429** (73-82). Delay = `Retry-After` seconds × 1000 if present and > 0, else `attempt * 2000` ms. Logs `console.warn`. Never retries 5xx or timeouts (comment: `/ingest/run` is non-idempotent).
- Non-JSON body → throws `Agent request failed (<path>): HTTP <status> — non-JSON response: "<200-char snippet>"`.
- `!response.ok` → throws `Agent request failed (<path>): <payload.error | HTTP status>`.
- ok → `console.log('[agent] <path> -> ok in <ms>ms (attempt n)')` and returns `payload as T` (an empty body gives `{}`).
- AbortError → throws `Agent request timed out (<path>) after <ms>ms`.
- After 3×429 → throws `… rate limited (429) after 3 attempts`.
- No injection seam: it uses global `fetch` and `config` directly. Tests would have to stub `globalThis.fetch`.

Exported wrappers:
| function | path | method | timeout | body |
|---|---|---|---|---|
| `runAgentIngest({userId, rawContentIds?, daysBack?, notes?})` → AgentIngestResponse | `/ingest/run` | POST | 450 s | `{ userId, rawContentIds, daysBack: daysBack ?? 1, notes: notes ?? 'Triggered by retrospect-api /content upload' }` |
| `getAgentOnboardingGoals(userId, answersText)` → `{ goals: AgentStatedGoal[]; dropped }` | `/onboarding/goals` | POST | 90 s | `{ userId, answersText }` |
| `generateAgentPodcast({userId, daysBack?, skipTTS?, persona?, notes?})` → AgentPodcastResponse | `/podcasts/generate` | POST | 450 s | `{ userId, daysBack: ?? 14, skipTTS: ?? false, persona, notes: ?? 'Triggered by retrospect-api /podcasts/generate' }` |
| `applyAgentCorrection({userId, kind:'fact', id, note?, mode:'wrong'|'changed'})` → `{ outcome; retired }` | `/corrections/confirm` | POST | 30 s | body as given |
| `processAgentIntegrationBatch(body)` → AgentIntegrationResponse | `/integrations/process` | POST | 450 s | body |
| `enqueueAgentIntegrationBatch(body)` → `{ jobId; status }` | `/integrations/enqueue-device-batch` | POST | 30 s | body |
| `queueAgentIntegrationImport(body)` → `{ jobId; status }` | `/integrations/queue-import` | POST | 30 s | body |
| `requestAgentIntegrationSync(connectionId, userId)` | `/integrations/connections/${id}/sync` | POST | 30 s | `{ userId }` |
| `requestAgentIntegrationDataDeletion(connectionId, userId)` | `/integrations/connections/${id}/delete-data` | POST | 30 s | `{ userId }` |
| `storeAgentIntegrationCredentials(connectionId, body)` → void | `/integrations/connections/${id}/credentials` | **PUT** | 30 s | body |

Response interfaces (3-32): `AgentIngestResponse { traceId; observations_created; insights_created; goal_candidates_created; raw_content_processed; processingNotes? }`; `AgentPodcastResponse { traceId; episodeId; title; description; mood; durationSeconds; audioUrl }`; `AgentIntegrationResponse { syncRunId; ingestionTraceId; itemsSeen; itemsCreated; itemsUpdated; itemsSkipped; itemsFailed; rawContentIds; failures[] }`; `AgentStatedGoal { title; description; reasoning; quote }` (exported).
There is no agent call for user deletion or for streaming.

Related: `services/agent-handoff.ts` (41 lines) `handOffToAgent(run, args, log?)`. It never throws and has no DB client (see agent-handoff.test.ts).

## 7. src/services/claude-guard.ts (128 lines) — the limiter to generalise

```ts
export const CLAUDE_LIMITS = { perHour: 30, perDay: 120, maxInputChars: 200_000, maxImages: 10,
  maxImageBase64Chars: 20_000_000, maxOutputTokens: 8192, defaultOutputTokens: 2000 } as const;   // 11-21
export type Turn = { role: 'user' | 'assistant'; content: string | Array<TextBlock | ImageBlock> }; // 25
export type GuardResult =
  | { ok: true; messages: Turn[]; system?: string; maxTokens: number; at: number }
  | { ok: false; status: number; error: string };                                                 // 28-30
export class CallLog {                                                                             // 36-64
  record(userId: string, now: number): void        // sweep, keep last-DAY timestamps, push now
  refund(userId: string, at: number): void          // remove lastIndexOf(at)
  private sweep(now: number): void                  // at most hourly; drops users with no call in a DAY
  size(): number
  count(userId: string, now: number, window: number): number
}
export function guardClaudeRequest(userId: string | undefined, body: unknown, log: CallLog, now: number = Date.now()): GuardResult  // 66-128
```
Pattern: a pure function plus an injected `CallLog` plus an injected `now`, which makes it testable without a clock. The order is 401 (no user), then 429 (hour or day cap), then 400 (shape), then 413 (size). It records only on success and returns `at` so the route can `refund` on a provider failure (claude.ts:39-43). Counts are in memory per instance; the header comment says one Render instance today, with a shared store promised later ("B1.10").

`routes/claude.ts` (53 lines): module-level `callLog` (6) and a lazy Anthropic client from `process.env.ANTHROPIC_API_KEY` (8-16). `POST /claude/generate` → `{ success:true, data:{ text } }`; model `process.env.CLAUDE_MODEL || 'claude-sonnet-4-6'`. Non-streaming (`MessageCreateParamsNonStreaming`). Error → `500 'Claude generation failed'`.

## 8. Test conventions

Runner: `node:test` via `tsx --test` (not Jest). Assertions: `import assert from 'node:assert/strict'`. Imports from `../src/...` with `.js` suffix. One `test('plain-English sentence', () => {...})` per behaviour, no `describe`. The house style is a comment above each test naming the bug or finding it guards. Fakes are hand-written objects that satisfy a narrow interface (no mocking library). Time is injected as a number.

`backend/tests/claude-guard.test.ts` in full:
```ts
import assert from 'node:assert/strict';
import test from 'node:test';
import { CallLog, CLAUDE_LIMITS, guardClaudeRequest } from '../src/services/claude-guard.js';

const ok = { userMessage: 'hi' };

test('signed-out callers are refused', () => {
  const r = guardClaudeRequest(undefined, ok, new CallLog());
  assert.equal(r.ok, false);
  assert.equal(!r.ok && r.status, 401);
});

test('each user is capped per hour, and others are unaffected', () => {
  const log = new CallLog();
  const now = 1_000_000_000_000;
  for (let i = 0; i < CLAUDE_LIMITS.perHour; i++) assert.equal(guardClaudeRequest('a', ok, log, now + i).ok, true);
  const blocked = guardClaudeRequest('a', ok, log, now + 100);
  assert.equal(!blocked.ok && blocked.status, 429);
  assert.equal(guardClaudeRequest('b', ok, log, now + 100).ok, true, 'another user still works');
  assert.equal(guardClaudeRequest('a', ok, log, now + 61 * 60 * 1000).ok, true, 'the hour rolls over');
});

test('the daily cap holds even when spread across hours', () => {
  const log = new CallLog();
  const start = 2_000_000_000_000;
  let allowed = 0;
  for (let h = 0; h < 24; h++) for (let i = 0; i < CLAUDE_LIMITS.perHour; i++) {
    if (guardClaudeRequest('a', ok, log, start + h * 3_600_000 + i).ok) allowed++;
  }
  assert.equal(allowed, CLAUDE_LIMITS.perDay);
});

test('journal image analysis (text + base64 image blocks) still works', () => {
  const r = guardClaudeRequest('a', { messages: [{ role: 'user', content: [
    { type: 'image', source: { type: 'base64', media_type: 'image/jpeg', data: 'AAAA' } },
    { type: 'text', text: 'describe' },
  ] }] }, new CallLog());
  assert.equal(r.ok, true);
});

test('only user/assistant turns with text or base64 images get through', () => {
  const tool = guardClaudeRequest('a', { messages: [{ role: 'user', content: [{ type: 'tool_use', id: 'x' }] }] }, new CallLog());
  assert.equal(!tool.ok && tool.status, 400);
  const url = guardClaudeRequest('a', { messages: [{ role: 'user', content: [{ type: 'image', source: { type: 'url', url: 'http://x' } }] }] }, new CallLog());
  assert.equal(!url.ok && url.status, 400);
  const sys = guardClaudeRequest('a', { messages: [{ role: 'system', content: 'x' }] }, new CallLog());
  assert.equal(!sys.ok && sys.status, 400);
});

test('oversized input is refused and output is capped', () => {
  const big = guardClaudeRequest('a', { userMessage: 'x'.repeat(CLAUDE_LIMITS.maxInputChars + 1) }, new CallLog());
  assert.equal(!big.ok && big.status, 413);
  const capped = guardClaudeRequest('a', { userMessage: 'hi', maxTokens: 999_999 }, new CallLog());
  assert.equal(capped.ok && capped.maxTokens, CLAUDE_LIMITS.maxOutputTokens);
});

test('a provider failure gives the call back', () => {
  const log = new CallLog();
  const now = 3_000_000_000_000;
  for (let i = 0; i < CLAUDE_LIMITS.perHour - 1; i++) guardClaudeRequest('a', ok, log, now + i);
  const last = guardClaudeRequest('a', ok, log, now + 50);
  assert.equal(last.ok, true);
  log.refund('a', now + 50);
  assert.equal(guardClaudeRequest('a', ok, log, now + 60).ok, true, 'the refunded slot is usable again');
});

test('users idle for a day are forgotten', () => {
  const log = new CallLog();
  const now = 4_000_000_000_000;
  guardClaudeRequest('a', ok, log, now);
  guardClaudeRequest('b', ok, log, now + 25 * 3_600_000);
  assert.equal(log.size(), 1);
});
```
Fake-client style (tests/content-insert.test.ts:1-60): `fakeClient(opts)` returns an object typed `InsertClient` with chained `from().insert().select().single()` returning `{data,error}` with Postgres codes (`'23505'`, `'42703'`), plus a reset hook exported from the module (`resetMissingMigrationWarningForTests`). Async style (agent-handoff.test.ts): `await assert.doesNotReject(handOffToAgent(async () => { throw … }, args, (_m, e) => logged.push(e)))`, with the dependency (the agent call) passed as a function argument.
Env-setting style (only in the unrun Jest file tests/integration-contracts.test.js:1-28): a `requiredEnv` object of dummy values and `process.env[key] = process.env[key] || value`, followed by `require('../dist/...')` inside each test, which avoids import hoisting.
Test files on origin/main: agent-handoff, assertion-feedback, claude-guard, content-insert, dedup-key, goal-dedupe, goal-lifecycle, goal-revival, oauth-providers, status-writer (`.test.ts`), plus integration-contracts.test.js (Jest, not run).

## 9. Schema

### users
backend `supabase/migrations/001_initial_schema.sql:11-17` (same in combined_migration.sql:14-20):
| column | type |
|---|---|
| id | UUID PK DEFAULT uuid_generate_v4() |
| apple_user_id | TEXT UNIQUE NOT NULL |
| email | TEXT |
| created_at | TIMESTAMPTZ DEFAULT NOW() |
| updated_at | TIMESTAMPTZ DEFAULT NOW() (trigger `update_users_updated_at`, 001:223-224) |
| voice_persona | TEXT DEFAULT 'thoughtful_friend' (backend 004:7-8; agent 123); CHECK `users_voice_persona_check IN ('thoughtful_friend','wise_mentor','energetic_host') NOT VALID` (004:15-16) |
| daily_brief_enabled | BOOLEAN NOT NULL DEFAULT false (agent 128_daily_briefs.sql:11) |
| ambient_enabled | BOOLEAN NOT NULL DEFAULT TRUE (agent 141_ambient_switch.sql:4) |
Index `idx_users_apple_user_id` (001:19). RLS is enabled (001:240) with policies `id = auth.uid()` for SELECT and UPDATE (001:251-256). The backend uses the service role, so RLS is moot. No columns exist for invite status, deletion, token version, push token or entitlement.

### raw_content
backend 001:55-67: `id UUID PK`, `user_id UUID NOT NULL → users ON DELETE CASCADE`, `content_type TEXT NOT NULL`, `content TEXT NOT NULL`, `content_date TIMESTAMPTZ`, `metadata JSONB DEFAULT '{}'`, `processing_status TEXT DEFAULT 'pending' CHECK IN ('pending','processing','completed','failed')`, `processing_error TEXT`, `source_id UUID → data_sources(id)` (no ON DELETE), `created_at`, `processed_at`. Indexes: user_id, processing_status, content_type, created_at DESC (001:69-72).
Agent-repo additions: `embedding vector(3072)` (100:28-29); `source_item_id UUID → source_items ON DELETE SET NULL`, `processing_started_at TIMESTAMPTZ` (106:178-179); `attempt_count INT NOT NULL DEFAULT 0`, `next_attempt_at TIMESTAMPTZ`, `failure_kind TEXT` (114:19-25; CHECK widened in 116 to `'transient','terminal','not_applicable'`); `authorship TEXT CHECK IN ('self','other','unknown')` default 'unknown' (115:30-61, 124:26); `dedup_key TEXT`, `dedup_strategy TEXT CHECK IN ('explicit_key','provider_object_id','sync_day','content_hash','content_hash_day','singleton')` (117:45-58).
**Unique index** (agent 117:60-62): `CREATE UNIQUE INDEX IF NOT EXISTS raw_content_user_dedup_key_uniq ON raw_content (user_id, dedup_key) WHERE dedup_key IS NOT NULL;` Partial: old unkeyed rows never collide. Agent migrations are applied **by hand** (content-insert.ts:52-57).

### dedup-key.ts logic (src/services/dedup-key.ts, 247 lines)
- `CONTENT_TYPE_CLASS` (58-87): human = journal_entry, voice_journal, voice_recording, text_entry, video_entry; singleton = onboarding_profile; machine = google_docs, healthkit, calendar, screen_time, twitter_bookmarks, apple_music, photos, contacts, gmail, spotify, youtube, reddit, x, tiktok. Unknown types count as machine (`classOf`, 95-97).
- `deriveDedupKey(input)` (~204-247), precedence:
  0. explicit = trimmed `Idempotency-Key` header, else `metadata.client_event_id` → `sha256(userId \0 contentType \0 'explicit:'+key)`, strategy `explicit_key`
  1. singleton → `…'singleton'`
  2. machine → `metadata.provider_object_id` → `'object:'+id`; else `metadata.sync_day` → `'day:'+d`; else `'content:'+sha256(content)` (date excluded)
  3. human → `'content:'+sha256(normalizeForDedup(content))+':day:'+localDay(contentDate|now, timeZone)`. Normalisation is NFC, trim, collapse whitespace, lowercase. `timeZone` is never supplied today, so the day is the UTC day.
- `DedupInput { userId, contentType, content, contentDate?, metadata?, idempotencyKey?, timeZone?, now? }`.

### Storage buckets
- Backend code: `supabaseAdmin.storage.from('integration-imports').createSignedUploadUrl(path)` (integrations.ts:269-271, path `${userId}/${providerId}/${importId}${ext}`); `.from('integration-media').createSignedUploadUrl(path)` (integrations.ts:310, path `${userId}/${providerId}/${assetId}`).
- Agent migration 108:514-519 creates private buckets `integration-imports` (1 GiB), `integration-evidence` (1 GiB), `integration-media` (5 GiB).
- The agent also writes `podcast-audio` (src/pipelines/podcast.ts and podcast-v2.ts:89 `getPublicUrl`). That bucket is not created by any migration and is evidently public.

### FK cascade (for account deletion)
Every backend table FK to users is `ON DELETE CASCADE`. In the agent repo, all 41 `REFERENCES users(id)` in migrations 1xx are `ON DELETE CASCADE` (grep found none without it). So `DELETE FROM users WHERE id=…` removes DB rows. Storage objects and any provider-side OAuth grants are not removed.

## 10. src/routes/content.ts (386 lines) — Idempotency-Key

- `POST /content` (41-192). Body `UploadContentSchema` (types/index.ts:105-110): `{ contentType: ContentTypeSchema, content: string.min(1), contentDate?: string.datetime() (Z only, no offsets), metadata?: record }`. ContentTypeSchema (types 29-52) = voice_recording, voice_journal, text_entry, journal_entry, video_entry, google_docs, healthkit, calendar, screen_time, twitter_bookmarks, onboarding_profile, apple_music, photos, contacts, gmail, spotify, youtube, reddit, x, tiktok.
- 63-67: looks up `data_sources.id` by `name = contentType`.
- 72: `effectiveDate = contentDate || new Date().toISOString()`.
- **73: `const idempotencyKey = req.header('Idempotency-Key') ?? null;`**
- 77-99: `insertRawContent(supabaseAdmin as unknown as InsertClient, 'raw_content', {user_id, content_type, content, content_date, metadata, source_id, processing_status:'pending'}, {userId, contentType, content, contentDate, metadata, idempotencyKey})`.
- Insert throw → `500 { success:false, error:'Failed to store content' }` (100-107).
- **Duplicate (109-134)**: header `Idempotency-Replayed: true`, **200**:
  `{ success:true, data:{ rawContentId, deduplicated:true, dedupReason:<strategy>, insightIds:[], insightCount:0, observationsCreated:0, insightsCreated:0, goalCandidatesCreated:0, agentTraceId:null, processingError:null }, message:'Already stored; returning the existing entry' }`. No ingest is run.
- New row: a best-effort upsert of `integration_connections` when contentType is in the catalog (140-161, `onConflict 'user_id,provider_id'`). Then **202**:
  `{ success:true, data:{ rawContentId, insightIds:[], insightCount:0, observationsCreated:0, insightsCreated:0, goalCandidatesCreated:0, agentTraceId:null, processingError:null }, message:'Content stored; agent ingestion running in background' }`. Then `setImmediate(() => handOffToAgent(runAgentIngest, {userId, rawContentIds:[id]}))` (182-184).
- insertRawContent (content-insert.ts:65-109): it inserts and branches on the result. On `23505` it reads the winner by `(user_id, dedup_key)` → duplicate; if there is no winner it throws. On `42703` (migration missing) it warns once and inserts unkeyed. `enforce = dedupClass !== 'singleton'` (72): **an explicit key is not enforced for onboarding_profile.**
- Other routes: `GET /content` (195) `?limit≤100 (default 50)&offset&status` → `{ success, data:[{id,content_type,content_date,processing_status,created_at}], pagination:{total,limit,offset,hasMore} }`; `GET /content/:id` (246) → `{ success, data:{ ...row(*), insights:[{id,content,primary_category,is_inferred,sentiment}] } }`; `POST /content/:id/reprocess` (292) runs the agent synchronously → `{ success, data:{ insightIds:[], insightCount, observationsCreated, insightsCreated, goalCandidatesCreated, agentTraceId } }`; `DELETE /content/:id` (356) → `{ success:true, message:'Content deleted' }`.

## 11. podcasts.ts / integrations.ts

### GET /podcasts (podcasts.ts:21-46)
`?limit` (default 20, **no max**) and `?offset`. Uses `listPodcastEpisodes` (podcast-db.ts:4-23): `select('*', {count:'exact'}).eq('user_id').eq('status','ready').order('created_at', desc).range(...)`.
Response: `{ success:true, data: DbPodcastEpisode[], pagination:{ total, limit, offset, hasMore: offset+limit<total } }`. 500 → `{ success:false, error: err.message }` (this leaks DB messages).
`DbPodcastEpisode` (types 444-468): id, user_id, title, description|null, script, audio_url|null, duration_seconds|null, mood|null, generation_type ('weekly'|'on_demand'|'milestone'), status ('generating'|'ready'|'failed'), insight_ids[], goal_ids[], research_citations[], outline, episode_number|null, covers_period_start|null, covers_period_end|null, previous_episode_id|null, topics_covered[], error_message|null, metadata, created_at, updated_at. **At runtime, `select('*')` also returns the agent columns `summary` and `summary_embedding` (vector 3072).**
Also: `GET /podcasts/latest` (52) → `{success, data: episode}` or 404 `'No podcast episodes found'`; `GET /podcasts/:id` (79) → episode or 404 `'Episode not found'`; `POST /podcasts/generate` (108) body `{ daysSince?, daysBack?, skipTTS?, persona? }` is synchronous (waits up to 450 s on the agent) → `{ success, data: episode }`.

### GET /integrations/catalog (integrations.ts:68-73)
`{ success:true, data: INTEGRATION_CATALOG }`. It is under authMiddleware (the router is mounted at index.ts:81). Entry type (integration-catalog.ts:9-17):
```ts
{ id: string; displayName: string; collectionMode: 'native_ios'|'oauth_api'|'data_export';
  availability: 'available'|'in_development'|'approval_required'|'verification_required'|'export_import'|'access_review';
  intelligenceDomains: string[]; statusLabel?: string; setupRequirement?: string }
```
Catalog provider ids (integration-catalog.ts:20-38), as id / displayName / collectionMode / availability:
- healthkit / Apple Health / native_ios / available
- screen_time / Screen Time / native_ios / in_development
- google_docs / Google Docs / oauth_api / available
- calendar / Apple Calendar / native_ios / in_development
- google_calendar / Google Calendar / oauth_api / available
- apple_music / Apple Music / native_ios / in_development
- photos / Photos / native_ios / in_development
- contacts / Contacts / native_ios / in_development
- spotify / Spotify / oauth_api / in_development
- youtube / YouTube / oauth_api / in_development
- reddit / Reddit / oauth_api / in_development
- gmail / Gmail / oauth_api / verification_required (setupRequirement set)
- tiktok / TikTok / oauth_api / approval_required (setupRequirement)
- x / X / oauth_api / approval_required (setupRequirement)
- linkedin / LinkedIn / oauth_api / approval_required (setupRequirement)
- grok / Grok / data_export / export_import (setupRequirement)
- netflix / Netflix / data_export / export_import
- chatgpt / ChatGPT / data_export / export_import
- claude / Claude / data_export / export_import

That is 19 entries. The catalog has no "connect mode" field beyond `collectionMode`, and no per-user status: status comes from `GET /integrations`. OAuth provider keys (oauth-providers.ts:55-160): google_docs, gmail, youtube, google_calendar, **google** (aggregate, `memberProviderIds = GOOGLE_COMBINED_MEMBERS = ['google_docs','gmail','youtube','google_calendar']`, line 51), spotify, reddit, **pinterest** (OAuth provider with no catalog entry), tiktok, linkedin, x.

### GET /integrations (75-98)
`select('id, provider_id, collection_mode, status, granted_scopes, provider_account_label, connected_at, last_verified_at, metadata')` from integration_connections for the user. Response: `{ success:true, data: INTEGRATION_CATALOG.map(p => ({ ...p, connection: row | null })) }`. Connection `status` values written in this file are `'connected'`, `'action_required'` and `'disconnected'`.

### Other integration routes
- `GET /integrations/connections` (100): connections joined with `integration_sync_states(last_attempt_at,last_success_at,last_error,consecutive_failures)` and `integration_jobs(id,status,job_type,created_at,completed_at)`.
- `GET /integrations/readiness` (113): `listOAuthProviderReadiness()` → `[{ providerId, configured, missing:['client_id'|'client_key','client_secret'], scopes, supportsPkce, tokenAuth }]`, excluding aggregates.
- `POST /:providerId/native-connected` (117) → upsert, status `action_required`.
- `DELETE /:providerId` (151), `DELETE /connections/:connectionId` (172) → `{success:true}` (soft disconnect).
- `POST /:providerId/items` (185) and `/:providerId/device-batches` (224) take `IngestIntegrationItemsSchema` with optional `idempotencyKey` (min 8, max 500, types:132). When absent it defaults to `legacy:`/`device:` + sha256(body). They call `enqueueAgentIntegrationBatch` → 202 `{success, data:{jobId,status}}`.
- `POST /:providerId/imports` (251) `{filename, contentType, byteSize ≤ 1 GB}` → 201 `{ importId, storagePath, uploadToken, signedUrl }`.
- `POST /:providerId/assets` (290) → 201 `{ assetId, signedUrl, uploadToken }`, or 409 on duplicate.
- `POST /assets/:assetId/complete` (336) and `POST /imports/:importId/complete` (358) require `sha256`. Imports then queue `queueAgentIntegrationImport` with `idempotencyKey: archive:<id>` → 202.
- `POST /:providerId/connect/start` (399) → `{ success, data:{ authorizationUrl } }`. Errors are **400** with `readiness`. PKCE state is stored hashed in integration_oauth_states, TTL 10 min.
- `POST /connections/:id/sync` (426), `/reconnect` (441), `DELETE /connections/:id/data` (455) → 202 `{data: job}`.
- Unauthenticated `GET /integrations/:providerId/connect/callback` (470-543): exchanges the code, marks state consumed, fans out over `memberProviderIds`, stores credentials via the agent and requests a sync, then redirects to `INTEGRATION_APP_REDIRECT_URL?provider=…&status=syncing|error`.

## 12. src/routes/speech.ts (110 lines)

- `POST /speech/synthesize` with body `{ text: string }`. Auth is required (index.ts:80).
- No API key → `503 'ELEVENLABS_API_KEY is not configured on the server'` (71-77). Empty text → 400 `'text is required'`. Text over `MAX_TEXT_CHARS = 20_000` (9) → 400.
- `chunkScript(text, config.elevenlabs.maxCharsPerRequest /*4800*/)` (15-37) splits at the last `'. '`, `'! '`, `'? '` or `'.\n'` inside each 4,800-char window, else hard-cuts.
- `synthesizeChunk(text, voiceId, apiKey)` (39-63): `POST https://api.elevenlabs.io/v1/text-to-speech/${voiceId}` with headers `xi-api-key`, `Content-Type: application/json`, `Accept: audio/mpeg` and body `{ text, model_id: 'eleven_v3', voice_settings:{ stability:0.5, similarity_boost:0.75 } }`. A non-ok response throws `ElevenLabs TTS failed (<status>): <300 chars>`.
- All chunks run **in parallel** (`Promise.all`, 95-97), then `Buffer.concat` into a single MP3 response: `Content-Type: audio/mpeg`, `Content-Length` (100-102). Not streamed.
- **Voice id**: always `config.elevenlabs.voiceId` (env `ELEVENLABS_VOICE_ID`, with a default). The request cannot choose a voice, and the user's `voice_persona` is not used. Persona voice ids live in `services/voice-personas.ts` (thoughtful_friend, wise_mentor, energetic_host, each with an ElevenLabs voiceId and a stability).
- There is no per-user limiter on speech (only the global IP limiter), unlike `/claude`.
- Error → 500 `{ success:false, error: err.message }`.

## 13. src/routes/admin.ts (658 lines)

- Auth (13-24): `adminAuth` reads `req.query.secret || req.headers['x-admin-secret']` and compares with `!==` against `config.admin.secret`; on failure, `403 'Invalid admin secret'`. Then `adminRouter.use(adminAuth)`. A default secret exists in config (value not reproduced), and ADMIN_SECRET is absent from both render blueprints. dashboard.html:1405 builds `…/admin<path>?secret=<encoded>`.
- Endpoints: `GET /admin/users` (31; id, email, apple_user_id, created_at for all users); `POST /admin/users` (46; creates a test user); `POST /admin/users/:userId/backfill` (70; `runAgentIngest` with daysBack); `GET/POST /admin/goals` (91/106); `POST /admin/goals/extract` (121); `POST /admin/goals/extract-and-save` (136); `GET /admin/content?userId=` (161; **returns `content` text**); `POST /admin/content` (186; inserts raw_content for any user); `GET /admin/observations` (219); `GET /admin/insights` (244); `GET /admin/insights/:id` (265); `POST /admin/pipeline/observations` (290), `/pipeline/observations/:contentId` (314), `/pipeline/insights` (338), `/pipeline/run` (362); `GET /admin/pipeline/runs` (387); `POST /admin/diagnose` (414; multi-step per-user diagnosis); `GET /admin/podcasts` (580); `POST /admin/podcasts/generate` (595; paid); `GET /admin/stats` (631; counts of users, raw_content, goals, observations, insights, pipeline_runs, podcast_episodes).
- `/dashboard` and `/public/*` are served without auth; the dashboard prompts for the secret.

## 14. Render blueprints

`backend/render.yaml` (76 lines): `services[0]`: `type: web`, `name: retrospect-api`, `env: node`, `region: oregon`, `plan: starter`, `autoDeploy: false`, `buildCommand: npm install && npm run build`, `startCommand: npm start`, `healthCheckPath: /health`. **No `rootDir`, no `numInstances`, no Node version.**
envVars:
- `NODE_ENV` value production
- `PORT` value 3000
- `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`, `SUPABASE_ANON_KEY`, `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `ELEVENLABS_API_KEY`, `ELEVENLABS_VOICE_ID`, `AGENT_SERVICE_URL`, `INTERNAL_API_SECRET`: all `sync: false`
- `JWT_SECRET`: `generateValue: true`
- `RATE_LIMIT_WINDOW_MS` value 900000; `RATE_LIMIT_MAX_REQUESTS` value 100
- `APPLE_CLIENT_ID` value (bundle id); `INTEGRATION_OAUTH_CALLBACK_BASE_URL` value (prod onrender URL)
- `GOOGLE_OAUTH_CLIENT_ID/SECRET`, `SPOTIFY_CLIENT_ID/SECRET`, `REDDIT_CLIENT_ID/SECRET`, `PINTEREST_CLIENT_ID/SECRET`, `TIKTOK_CLIENT_KEY/SECRET`, `LINKEDIN_CLIENT_ID/SECRET`, `X_CLIENT_ID/SECRET`, `SENTRY_DSN`: all `sync: false`
- **Missing:** ADMIN_SECRET, APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY, INTEGRATION_APP_REDIRECT_URL, PERPLEXITY_API_KEY, CLAUDE_MODEL, RETROSPECT_ENV, SENTRY_TRACES_SAMPLE_RATE.

`backend/render.staging.yaml` (40 lines): `name: retrospect-api-staging`, `env: node`, `region: oregon`, `plan: starter`, **`autoDeploy: true`**, same build, start and healthCheckPath. envVars:
- `NODE_ENV` value production; **`RETROSPECT_ENV` value staging**
- SUPABASE_URL, SUPABASE_SERVICE_KEY, SUPABASE_ANON_KEY, ANTHROPIC_API_KEY, ELEVENLABS_API_KEY, ELEVENLABS_VOICE_ID, OPENAI_API_KEY, AGENT_SERVICE_URL, INTERNAL_API_SECRET: `sync:false`
- JWT_SECRET `generateValue:true`
- APPLE_CLIENT_ID value (bundle id)
- `INTEGRATION_OAUTH_CALLBACK_BASE_URL` `sync:false`
- the same 14 provider vars and SENTRY_DSN, all `sync:false`
- No RATE_LIMIT_* (defaults apply), no PORT and no ADMIN_SECRET.

## 15. .github/workflows on origin/main

`quality.yml` ("Quality"), triggers `pull_request` (all paths) and `push: branches [main]`:
- job `api`: `runs-on: [self-hosted, macOS, retrospect]`, `defaults.run.working-directory: backend`. Steps: `actions/checkout@v4`; `actions/setup-node@v4` with `node-version: 20`, `cache: npm`, `cache-dependency-path: backend/package-lock.json`; `npm ci`; `npm run build`; `npm run typecheck`; `npm test`. **No env block**, so there is no dummy env.
- job `changes`: same runner. `checkout@v4` with `fetch-depth: 0`. Step `changed` sets `app=true` if there is no base sha or if `git diff --name-only "$base" HEAD | grep -qE '^Retrospect/'`. Output `app`.
- job `ios`: `needs: changes`, `if: needs.changes.outputs.app == 'true'`, same runner, `xcodebuild -project Retrospect/Retrospect.xcodeproj -scheme Retrospect -sdk iphonesimulator -configuration Debug -derivedDataPath "$RUNNER_TEMP/dd" CODE_SIGNING_ALLOWED=NO build`.

`secrets.yml` ("secrets"), on `pull_request`: job `gitleaks`, same runner, `env GITLEAKS_VERSION: 8.30.1`. Steps: checkout with `fetch-depth: 0`; verify `gitleaks version | grep -qx "${GITLEAKS_VERSION}"`; `gitleaks git --no-banner --redact --log-opts="${{ github.event.pull_request.base.sha }}..${{ github.event.pull_request.head.sha }}" .` Test fixtures with fake secrets must not look like real keys.

`design-system.yml`, on `pull_request` with paths `design-system/**`, `Retrospect/Retrospect/DesignSystemV2/**`, `Retrospect/Retrospect/Features/**`: job `tokens-and-literals` on the same runner, Node 20; `node design-system/tokens/validate.mjs`; `node design-system/tokens/to-swift.mjs && git diff --exit-code Retrospect/Retrospect/DesignSystemV2/Generated/Tokens.swift`; `node design-system/tools/check-swift-literals.mjs`.

`swift-quality.yml`, on `pull_request` with paths `Retrospect/**/*.swift`, `.swiftlint.yml`, `.swiftformat`, `.github/workflows/swift-quality.yml`: job `lint-and-format` on the same runner, env `SWIFTLINT_VERSION 0.65.1`, `SWIFTFORMAT_VERSION 0.64.0`. It verifies pinned versions and symlinks into `tools/`; `tools/swiftlint lint --strict --reporter github-actions-logging`; `tools/swiftformat --lint` over DesignSystemV2 and Features (excluding Generated).

No workflow deploys to Render. Prod has `autoDeploy: false`; staging auto-deploys from its connected branch.

## 16. Conflicts for `/v2` and SSE

- **Mount point:** insert `/v2` between index.ts:82 and :84. Anything after line 104 never runs. `/v2` does not collide with any existing prefix (`/admin`, `/auth`, `/integrations`, `/content`, `/goals`, `/pipeline`, `/podcasts`, `/profile`, `/claude`, `/speech`, `/graph`, `/public`, `/dashboard`, `/health`).
- **Global middleware that hits `/v2`:** helmet (fine for SSE and JSON), `cors()` (`*`), `express.json({limit:'10mb'})` (fine; a v2 router can add a tighter `express.json` per route, but the global one parses first, so the 10 MB cap wins on size and a per-route cap must be stricter to matter), and the **global IP rate limiter**. Behind Render without trust proxy, that limiter is effectively shared. A v2 per-user limiter should key on `req.user.id` after auth, and the global one should either skip `/v2` streams or get `trust proxy`.
- **No compression:** SSE needs no `res.flush()`. Set `Content-Type: text/event-stream`, `Cache-Control: no-cache, no-transform`, `Connection: keep-alive`, `X-Accel-Buffering: no` (Render's proxy can buffer), call `res.flushHeaders()`, and heartbeat (`:\n\n`) well under 300 s (`server.timeout`). The `keepAliveTimeout` of 120 s applies between requests, not during a response.
- **Error handler:** the app-level handler writes JSON with `res.status(500)`. For a stream that has already started, catch inside the handler and emit `event: error`, then `res.end()`. Do not `next(err)`.
- **Client disconnects:** nothing existing listens for `req.on('close')`. Agent calls are not cancellable from outside (callAgent's AbortController is internal). A streaming proxy to the agent needs its own fetch with a signal tied to `req`/`res` close.
- **authMiddleware does one Supabase round trip per request.** That is fine for SSE (once per connection), but long-lived streams will not notice deletion or revocation mid-stream.
- **Response envelope convention:** every route returns `{ success: boolean, data?, error?, details?, pagination?, message? }`. Errors are often raw `err.message` in 500s.
- **Express 4.22:** async handler rejections are not caught automatically. Keep try/catch or add a wrapper.
- **Tests and harness:** importing `src/index.ts` binds a port and needs 8 env vars, and there is no supertest. A harness can be `createApp()` + `app.listen(0)` + global `fetch` (Node 20 has it). Supabase must be injected (today it is a module singleton `supabaseAdmin`, imported directly by auth middleware and routes), or tests must stub at the `fetch` level.
