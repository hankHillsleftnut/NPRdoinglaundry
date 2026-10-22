# Local staging

The backend and the brain running on this Mac against a second, free Supabase project (`retrospect-staging`), so anything can be tried against real services without touching a real person's data (founder, 21 Oct, D2). Moving to Render staging later is configuration only (the last section).

| Service | Repo | Port | Health |
|---|---|---|---|
| backend | NPRdoinglaundry `backend/` | 3000 | `GET /health` |
| agent (the brain) | Retrospect-agent | 3001 | `GET /health/ready` |

## The rules

- **Staging only, checked three ways.** Each staging script reads `.env.staging` itself, with its values winning over anything exported in the shell (so an exported production `DATABASE_URL` can never be used); refuses unless that file says `RETROSPECT_ENV=staging`; and refuses any database that holds a user who isn't a `dev-test-user:` test account. The services do the same: both `dev:staging` scripts set `DOTENV_CONFIG_PATH=.env.staging DOTENV_CONFIG_OVERRIDE=true` and preload `dotenv/config`, so the staging file wins over the shell before any module (Sentry included) reads the environment. The seed makes its accounts with its own staging client, never through whatever backend is listening locally.
- **No secret leaves the env files.** Values live only in the two untracked `.env.staging` files. Never paste them into a PR, a report, a log or a chat; check them by name or by a successful connection.
- **No model spend by default.** The model keys are placeholders, so model calls fail and nothing is spent. Real keys go in only when a test needs a real model, and that spend is logged as test spend in `cost-per-user.md`. From BEA.4 the agent also stops all model calls once staging has spent `STAGING_DAILY_CAP_USD` (default $5) in 24 hours.
- **Invented content only.** The seeded accounts hold made-up words. Never copy a real person's entries into staging.

## One-time setup

1. **Env files.** In each repo, copy `.env.staging.example` to `.env.staging` and fill in the blanks:
   - the staging project's `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`, `SUPABASE_ANON_KEY` and `DATABASE_URL` (Supabase dashboard → Project Settings), the same in both files;
   - `JWT_SECRET`, `ADMIN_SECRET` and `INTERNAL_API_SECRET` from `openssl rand -hex 32`; `INTERNAL_API_SECRET` must be **the same value in both files**;
   - in both files: `DATABASE_CA_CERT`, the path to Supabase's CA certificate (dashboard → Database settings → SSL configuration → download certificate). Supabase signs database certificates with its own root, so `staging:migrate` and `db:migrate:staging` verify the connection against this file and refuse to run without it.
   `DOTENV_CONFIG_PATH=.env.staging` (already in the examples) makes each service read only its staging file, over the shell, so a missing value is never filled in from the `.env` beside it.
2. **Install:** `npm ci` in `backend/` and in the agent repo.
3. **Database, backend first, then the agent:**
   ```sh
   cd backend && npm run staging:migrate -- --apply          # base schema, 004, the private podcast-audio bucket
   cd <agent repo> && npm run db:migrate:staging -- --apply  # agent migrations 100 onward
   ```
   Both record what they applied in the database's `schema_migrations` table, so re-running applies only what's new. Without `--apply` they show the plan and change nothing. When a byte adds a migration (`005_sessions.sql`, `152_…`), the same commands apply it to staging; production is never touched by these commands.

   Why the backend starts from `supabase/combined_migration.sql` and not `001`: the numbered `001`–`003` can't be replayed on a fresh database (two ivfflat indexes on 3,072-dimension columns, which pgvector refuses, and no `podcast_episodes` until `004`). The combined file is the corrected version and matches production; the agent repo uses it as its test base schema for the same reason. `001`–`003` are recorded as contained in it.

## Every day

```sh
cd backend
npm run staging:up            # checks both env files, starts the agent and the backend, waits for health
npm run staging:seed          # creates the three test accounts (safe to re-run; needs no backend running)
npm run staging:up -- stop    # stops both
```

`staging:up` looks for the agent repo at `../../retrospect-agent` from `backend/`; set `AGENT_DIR` to point elsewhere. Logs go to `backend/logs/staging/` (gitignored). To run one service by hand: `npm run dev:staging` in either repo.

## The test accounts (T08)

| Account | Holds |
|---|---|
| `fresh` | nothing: a brand new account |
| `day-one` | the onboarding answers only (one `onboarding_profile` entry) |
| `month` | 30 days of typed and voice entries, a brief for the day you seed (quoting two of them; re-seeding on a later day adds that day's), two offered guesses, one episode (no real audio; a placeholder path in its metadata) |

A token for any of them, for a test build or `curl`:

```sh
curl -s -X POST localhost:3000/auth/dev/test-user -H 'content-type: application/json' -d '{"key":"month"}'
```

Without a body the same route makes a new throwaway account. The route exists only when `NODE_ENV` isn't `production`, and only reaches `dev-test-user:` accounts, never a real one.

Seeded rows are marked: `metadata.test_account = true` on entries and episodes, `model_version = 'staging-seed'` on briefs and guesses (those tables have no metadata column). Entries are stored as already processed, so nothing picks them up and spends on them; running a real ingest over them is a deliberate, paid step.

**Reset** (remove the three accounts and everything they hold, then seed them fresh; their ids change):

```sh
npm run staging:seed -- --reset
```

To start the whole database over, delete and recreate the staging project in Supabase, then repeat the one-time setup.

## Moving to Render staging later (about an hour, no code changes)

1. In Render, create the services from `backend/render.staging.yaml` and the agent's `render.staging.yaml` (both already exist; about $14 a month for two Starter services).
2. Set every variable from the two `.env.staging.example` files in the Render dashboard, with `AGENT_SERVICE_URL` pointing at the agent's private address. Keep `RETROSPECT_ENV=staging`; the blueprints set `NODE_ENV=production`, which turns the dev route off there, so seeding on Render staging needs another way to sign in as a test account (decide then).
3. Run `staging:migrate` and `db:migrate:staging` from this Mac as above; the database is the same staging project.
4. Point a test build at the Render staging URL.
