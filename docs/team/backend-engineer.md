# Backend engineer · plan

You open the doors between the iOS app and Retrospect's brain, and you build the few server pieces that don't exist yet. You own two codebases: `backend/` in NPRdoinglaundry, and the whole of Retrospect-agent. Read [README.md](./README.md), [context.md](./context.md), [byte-card.md](./byte-card.md) and [testing.md](./testing.md) before your first byte; this file assumes all four.

**Where the detail lives.** This file is the map: mission, rules, the decomposition tree and the queue. Every byte is a card, and the card is your whole brief:

| File | What's in it | Detail |
|---|---|---|
| [backend/phase-0.md](./backend/phase-0.md) | foundations: staging, hygiene, the door kit, the harness, sessions, Apple, invites, deletion, limits, version floor, cost; **the migration number table and house style** | full cards |
| [backend/phase-a.md](./backend/phase-a.md) | agent hardening (BEA.1–8) | full cards |
| [backend/phase-1-journal.md](./backend/phase-1-journal.md) | the journal slice (BE1.1–BE1.7) | full cards |
| [backend/later-phases.md](./backend/later-phases.md) | first run, podcasts, goals, you, settings, retiring the old | outline cards, filled in before each phase |
| [reference/backend-reference.md](./reference/backend-reference.md), [reference/agent-api-reference.md](./reference/agent-api-reference.md) | field-level truth for both repos, read from the code on 21 Oct | reference |
| [contracts/](./contracts/) | 00 platform, 01 first run (draft), 02 journal | law |

## 1. Your mission in one paragraph

The agent already does most of what the designs show: briefs, guesses, search, facts with evidence, corrections, onboarding, podcasts. The app can't reach most of it, because the backend forwards only ingest, podcasts and integrations. Your job is to make every capability the app needs reachable through a **door**: one authenticated `/v2` route per capability, built from one shared kit, that takes the user from the token (never from the client), checks the user owns what they ask for, applies per-user limits, forwards to the agent, maps the answer to the agreed contract, and logs it without content. Where the agent has the engine but no route, you add a small agent route first. Where the agent has a bug a door would carry to the app, you fix it first (phase A). Where nothing exists (sessions, invites, deletion, brief audio, the podcast job, push, entitlement, export), you build it. One small PR at a time, each complete.

## 2. What you own, and what you never touch

| You own | You never touch |
|---|---|
| `backend/**` in NPRdoinglaundry | `Retrospect/**` (the app): the plumbing and UI engineers |
| `supabase/migrations/**` in NPRdoinglaundry (backend tables, `005_…` onward) | `design-system/**`, `docs/design/**`, Paper |
| All of Retrospect-agent (routes, engines, its `supabase/migrations/1xx_…`, `152` onward) | `docs/team/**` except your report on the board (the integrator edits these) |
| Backend and agent tests, fixtures validation on the backend side | `.github/workflows/**` (ask the integrator) |
| | Any contract (propose changes; the integrator decides) |

If a byte seems to need a file outside your column, stop and ask the integrator. Don't work around it.

## 3. Ground truth, condensed (the references have every line number)

**Backend:** TypeScript strict, `module: NodeNext` without `"type": "module"`, so it compiles to **CommonJS** and relative imports need `.js` suffixes. Express 4.22, zod 3.25, `node:test` via tsx. Auth is a 30-day HS256 JWT checked against the `users` row on every request; `/auth/refresh` re-verifies an Apple token (no refresh tokens, no revocation). `callAgent` buffers responses, 450 s default timeout, retries only 429 (ingest isn't idempotent). Limits are a global IP limiter (broken behind Render's proxy: no `trust proxy`) and an in-memory per-user guard for `/claude/generate`. `config` throws on import without env vars; `index.ts` listens on import (no app factory). Some 500s leak `err.message`. Admin has a hard-coded default secret and accepts it in the query string. `content-insert.ts` ignores `Idempotency-Key` for singleton types. Migrations `001`–`004`; most tables come from the agent's migrations. No staging service exists on Render yet.

**Agent:** CommonJS, Express 4, node-cron (UTC, flagged), PGlite tests (run as **superuser**, which hides permission bugs). Every route sits behind a shared secret and **trusts whatever `userId` it's sent**: that's why doors exist. Engines with no route: brief history, pending guesses, entry lineage, portrait, understanding, people, goal evidence, podcast status. Nothing exists for streaming, a podcast job, full deletion, export, brief audio, chapters, Notion. **The daily brief cron is off in production** (`ENABLE_DAILY_BRIEF` unset; founder decision D10). Known bugs, fixed in phase A: corrections can't write under the service role (BEA.1), four unscoped or unchecked queries (BEA.2), preferences PUT wipes fields (BEA.3), most model calls aren't counted against the $15 daily cap (BEA.4), onboarding advance can run twice at once (BEA.5), bad JSON is a 500 (BEA.6), episode audio is a public permanent URL with the user id in it (BEA.7), a quiet week is a 500 (BEA.8). Storage buckets don't cascade on user delete; every FK to `users` does.

## 4. The door: one shape, built once, used about 40 times

Built in BE0.1 (`src/doors/`), tested in BE0.2. A door is:

1. **Mounted under `/v2/…`**, so old routes can be retired cleanly (X07).
2. **Authenticated**; the user is `req.user.id`. A `userId` from the client is ignored or rejected.
3. **Gated**: `invite_required` (403) while `waitlisted`, `suspended` (403); one check in the kit, skipped only for auth, meta, access, waitlist and redeem (BE0.12).
4. **Ownership-checked** when it names a thing by id: 404 `not_found`, never 403, so ids can't be probed.
5. **Validated** with zod against the contract (strict: unknown fields rejected).
6. **Limited** per user per bucket: `read` 120/min, `write` 30/min, `expensive` 10/min and 60/hour, plus the daily spend cap on expensive doors. Reads are never refused for spend (founder rule).
7. **Forwarded** with an explicit timeout and retry (`read`: once on 5xx/timeout; `none` for writes without an idempotency key).
8. **Mapped** to the contract's camelCase shape; agent internals (trace ids, cost lines, raw rows, embeddings, agent error messages) never leak.
9. **Logged** as one JSON line: door, userId, status, ms, agentMs, costUsd. The log type has no field that can carry content.
10. **Tested** with the nine-test door suite: unauthenticated 401 · waitlisted 403 · another user's id 404 · bad body 400 with a code · over limit 429 · agent 5xx 502 · agent timeout 504 · agent 404 → 404 · happy path matches the contract fixture exactly.

Envelope: `{ success: true, data }` or `{ success: false, error: { code, message, retryAfterSeconds? } }`, codes from contract 00 §2.

## 5. How you work: big picture down to one PR, dripped in (README §3, §4)

**Decompose before you build.** Every piece of server work hangs off the tree in §6: product → flow → capability → door or agent route → engine change → one PR. A card names its place in the tree. If a byte doesn't fit in the tree, it isn't a byte yet: ask the integrator.

**Drip, never batch.** One byte per branch, one PR per byte, small enough to review in one sitting (size S or M; an L is split along the lines its card gives). PRs land continuously, each one complete: nothing is compromised to go faster.

| Never compromised | What it means for every backend PR |
|---|---|
| Tests | the byte's named tests exist and pass; a bug fix shows the failing run on main and the passing run |
| Code quality | reads like the surrounding code; no dead code, no `any`, no `select('*')`, no copy-paste between doors (the kit exists) |
| Behaviour | the contract field for field; every error code the contract lists for that door is reachable and tested |
| Completion | the acceptance list is all yes; nothing "for later" hidden inside a merged PR (later work is a new card) |
| Edge cases | concurrency (two calls at once), retries, idempotency, empty states, time zones, another user's ids, oversized input |
| Safety | no secrets, no content in logs, no `err.message` in responses, migrations as files only |

**Mechanics:**
- **Two worktrees**, one per repo, each off that repo's fresh `origin/main`. Before every commit: `git remote get-url origin` and `git branch --show-current`. Never commit in `RETROSPECT_BACKUP_2026-05-28`. Never a bare `git stash`.
- **Branches:** `be/<id>-<slug>` (NPRdoinglaundry), `agent/<id>-<slug>` (Retrospect-agent). Never stack on an open PR; if you need unmerged work, wait.
- **Across repos:** two PRs, agent first, then backend.
- **Before you push:** backend `npm ci && npm run build && npm run typecheck && npm test`; agent `npm run security:check && npm run typecheck && npm test && npm run build` with the CI placeholder env vars. Read every result; never push red "to see".
- **Migrations:** numbers are pre-assigned (phase-0.md table); a migration is a file, tested on PGlite or the local schema check, and listed in the PR as **not applied**. Applying to staging is yours (BE0.S); applying to production is the founder's, through the integrator.
- **No deploys.** Merging deploys nothing. Never trigger a Render deploy.
- **Secrets:** never print, log or commit one; env var names only. Gitleaks runs on every PR.
- **Personal content:** debug with counts and types; never print entry text, answers, mail or calendar contents, even from staging test users.
- **Cost:** no paid model in tests. Real-model checks only on local staging with the seeded test users, logged as test spend.
- **Disk:** `df -h /` once per session; stop under 5 GB. You never run Xcode or simulators.
- **Review:** CodeRabbit, your own reviewer pass over the diff (removed behaviour, callers, names, duplication), CI green, then the integrator. Report after each PR in README §8's format.

## 6. The decomposition tree

```
Retrospect (the server side of the app)
├── platform ─────────────────────────────────────────── contract 00
│   ├── environments ............ local staging                         BE0.S
│   ├── runtime ................. proxy, timeouts, Node, idempotency      BE0.0, BE0.3
│   ├── doors ................... kit, envelope, log · harness · limits   BE0.1, BE0.2, BE0.9
│   ├── sessions ................ Apple sign-in v2, refresh, sign-out     BE0.4
│   │                             Apple token + revoke · notifications     BE0.5, BE0.13
│   │                             Google sign-in                           BE2.4
│   ├── access .................. waitlist, approval links, 3 invites     BE0.12
│   ├── version floor ........... /v2/meta, 426                            BE0.10
│   ├── account ................. delete account · delete data           BE0.6, BE0.7, BE0.8
│   └── cost .................... ledger + cap · per-user per-week        BEA.4, BE0.11
├── brain hardening (agent) ──────────────────────────── phase A
│   corrections write BEA.1 · user scoping BEA.2 · preferences merge BEA.3 · one first pass BEA.5
│   bad JSON BEA.6 · private audio BEA.7 · quiet weeks BEA.8
├── journal ──────────────────────────────────────────── contract 02
│   ├── sending ................. POST /v2/entries, GET /v2/entries/today BE1.1
│   ├── today's brief ........... latest, history, switch · audio          BE1.3, BE1.3b
│   ├── guesses ................. list, answer, why                        BE1.4
│   ├── entries ................. list + search, one · edit, delete       BE1.5, BE1.5b
│   ├── what retro took ......... lineage forward                          BE1.6
│   ├── "not right" ............. corrections, confirm                     BE1.7
│   └── (v2, deferred) .......... conversation, streaming                  BE1.0, BE1.1-v2, BE1.2a/b
├── first run ────────────────────────────────────────── contract 01 (draft)
│   ├── questions ............... answers, goals, onboarding doors         BE2.1, BE2.2
│   ├── connect ................. knows-you · Notion                       BE2.3, BE2.9
│   ├── getting ready ........... podcast job · episode doors              BE2.5a, BE2.5b
│   ├── push .................... devices · sender                         BE2.6, BE2.7
│   └── paywall ................. RevenueCat entitlement mirror            BE2.8
├── podcasts ─────────────────────────────────────────── contract 03
│   chapters + real duration BE3.0 · why this is here BE3.1 · feedback BE3.2 · weekly push BE3.3
├── goals ────────────────────────────────────────────── contract 04
│   goal doors BE4.1 · said vs did BE4.2 · check-in push BE4.3
├── you ──────────────────────────────────────────────── contract 05
│   people BE5.1 · portrait BE5.2 · what I know + answer verdicts BE5.3 · search BE5.4
├── settings and account ─────────────────────────────── contract 06
│   settings + voice BE6.1 · brief time per user BE6.2 · export BE6.3 · subscription BE6.4
└── retire the old ───────────────────────────────────── after the version floor
    old routes X07 · legacy brain tables X08
```

## 7. The queue

Take bytes in this order unless the integrator re-orders the board. At most two of your PRs in review at once. "Blocked" names what must be merged (or decided) first.

| # | Byte | Repo | Size | Blocked by | Card |
|---|---|---|---|---|---|
| 1 | BE0.0 runtime hygiene | backend | M | — | [phase-0](./backend/phase-0.md) |
| 2 | BEA.6 bad JSON is a 400 | agent | S | — | [phase-a](./backend/phase-a.md) |
| 3 | BE0.1 door kit | backend | L | BE0.0 | phase-0 |
| 4 | BEA.2 user scoping | agent | M | — | phase-a |
| 5 | BE0.2 app factory + harness | backend | M | BE0.1 | phase-0 |
| 6 | BEA.1 corrections write | agent | M | — | phase-a |
| 7 | BE0.S local staging | both | M | founder: staging Supabase project | phase-0 |
| 8 | BE0.3 error leaks, speech limits | backend | S | BE0.1 | phase-0 |
| 9 | BEA.4 spend ledger + cap | agent | M | — | phase-a |
| 10 | BE0.4 sessions | backend | L | BE0.2 | phase-0 |
| 11 | BE0.12 invites | backend | L | BE0.4 | phase-0 |
| 12 | BE0.10 version floor | backend | S | BE0.1 | phase-0 |
| 13 | BE1.1 sending into your bank | backend | M | BE0.12, contract 02 | [phase-1](./backend/phase-1-journal.md) |
| 14 | BE1.5 entry history | backend | M | BE1.1 | phase-1 |
| 15 | BEA.7 private audio | agent | M | — | phase-a |
| 16 | BE1.6 what retro took | agent + backend | M | BE1.5, BEA.2 | phase-1 |
| 17 | BE1.7 "not right" | backend | M | BE1.6, BEA.1 | phase-1 |
| 18 | BE1.5b edit / delete an entry | agent + backend | L | BE1.5, BEA.1 | phase-1 |
| 19 | BE1.3 briefs | agent + backend | M | BE0.2 | phase-1 |
| 20 | BE1.3b brief audio | agent + backend | L | BE1.3, BEA.7, BEA.4 | phase-1 |
| 21 | BE1.4 guesses | agent + backend | M | BE0.2 | phase-1 |
| 22 | BEA.3 preferences merge | agent | S | — | phase-a |
| 23 | BEA.5 one first pass | agent | S | — | phase-a |
| 24 | BEA.8 quiet weeks | agent | S | — | phase-a |
| 25 | BE0.6 delete everything (agent) | agent | M | — | phase-0 |
| 26 | BE0.5 Apple token + revoke | backend | M | BE0.4, founder: Sign in with Apple key | phase-0 |
| 27 | BE0.7 account deletion door | backend | M | BE0.6, BE0.5 | phase-0 |
| 28 | BE0.13 Apple notifications | backend | S | BE0.5, BE0.7 | phase-0 |
| 29 | BE0.8 delete my data | agent + backend | M | BE0.7 | phase-0 |
| 30 | BE0.9 shared limiter store | backend | S | BE0.1; before the first ship gate | phase-0 |
| 31 | BE0.11 cost per user | agent + backend | M | BEA.4 | phase-0 |
| 32+ | Phase 2 (BE2.1–BE2.9), then 3–7 | — | — | contract 01 merged; cards filled in | [later-phases](./backend/later-phases.md) |

Why this order: hygiene, the kit and the harness come before any door; the agent fixes that a journal door would carry (scoping, corrections, spend) run alongside them; sessions and invites come before the journal because every `/v2` door is gated; the journal slice is the first full flow (README §6); deletion lands before any external tester (App Review requires it), and the shared limiter before the first ship gate.

**Deferred to v2, written down so nothing is lost** (founder, 21 Oct: the journal isn't a chat yet; Retro's acknowledgement is canned on the phone; a real conversation "probably requires rethinking"):
- *BE1.0 · conversation fixes:* correction candidate ids in replies, `used` in today, the local day, real ids for `said_today`.
- *BE1.1-v2 · conversation door* over agent `POST /conversation`, with idempotency.
- *BE1.2a/b · streaming replies:* an agent SSE variant, then a streaming door; one JSON object per `data:` line, heartbeats every 15 s, no compression on the route, tested through Render's proxy on staging, not only locally.

## 8. Definition of done for every byte

1. The card's acceptance list is all yes, and nothing outside the card changed.
2. Every new door passes the nine-test door suite; every new agent route has a two-user PGlite test proving isolation; a fix shows its test failing on main.
3. The contract's fixtures for that door validate against the door's zod output schema.
4. CI is green on every repo the byte touched, and you read each job.
5. No secrets, no content in logs, no agent message in responses, no `select('*')`.
6. Migrations are files only, tested, numbered from the table, listed as not applied.
7. The PR body: what and why in the user's terms, the card and contract section, the tests, proof, what's not done, what the founder must decide.
8. CodeRabbit is done, your reviewer pass is done and its findings fixed, then the integrator reviews.

## 9. Things that will bite you

- **CommonJS vs ESM:** backend relative imports need `.js`; `jose` is ESM-only and needs Node ≥ 22.12 (BE0.0). Don't copy import styles between repos.
- **`config` throws on import** and imports are hoisted: tests set env through `tsx --import tests/support/env.ts`.
- **The agent trusts `userId`.** A door that forwards a client-supplied id leaks across users. The 404 test exists for this; never skip it.
- **PGlite runs as superuser.** Permission bugs only show under `SET ROLE service_role` (BEA.1). Any test of a write the service role performs runs under that role.
- **Migration 121 forbids direct writes** to `question_answers`: everything goes through `SECURITY DEFINER` functions. Never "fix" a permission error with a GRANT.
- **Ingest isn't idempotent.** Never add a retry to a write without an idempotency key.
- **One Render instance.** In-memory limits and caches reset on deploy (BE0.9 before the first ship gate).
- **Two brief shapes in one column.** v2 brief items are bookkeeping ("pattern", "answer"); never show them (BE1.3).
- **Storage doesn't cascade.** Deleting a user leaves files in four buckets unless you remove them, paging past `list()`'s 1,000 cap (BE0.6).
- **`select('*')` on episodes or raw content ships embeddings** (3,072 floats per row).
- **Time zones:** "today" is the user's local day from `users.time_zone` (sent as `X-Time-Zone`), never UTC; `brief_date` is still UTC until BE6.2.
- **The brief cron is off in production.** Don't "fix" it; it's founder decision D10.
- **Voice is ~60% of per-user cost.** Never synthesise on a dry run or for staging test users unless the test asks; report measured cost per brief and per episode.
