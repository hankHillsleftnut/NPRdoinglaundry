/**
 * Builds the backend's half of the staging database.
 *
 * The numbered migrations 001-003 cannot be replayed on a fresh database:
 * 001 and 003 declare ivfflat indexes on 3072-dimension columns, which pgvector
 * refuses (its limit is 2,000), and no numbered file before 004 creates
 * podcast_episodes. `supabase/combined_migration.sql` is the corrected one-shot
 * version and matches what production holds; the agent repo vendors it as its
 * test base schema for the same reason. So a fresh staging database gets the
 * combined file once, 001-003 are recorded as already present, and every later
 * numbered file is applied in order.
 *
 * The ledger is the agent's `schema_migrations` table, with the same definition,
 * so both repos record into one place and whichever runs first creates it.
 * Backend files (0xx) and agent files (1xx) never share a name.
 *
 * Pure planning plus a runner over a minimal executor, so it is tested without
 * a network. scripts/staging-migrate.ts connects it to the staging database.
 */

export const LEDGER_TABLE = 'schema_migrations';
export const BASE_FILE = 'combined_migration.sql';
/** The numbered files the base already contains. */
export const BASE_COVERS_THROUGH = '003_goals_observations_insights.sql';

export const LEDGER_SQL = `
  CREATE TABLE IF NOT EXISTS ${LEDGER_TABLE} (
    file        TEXT PRIMARY KEY,
    applied_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    how         TEXT NOT NULL CHECK (how IN ('applied', 'baseline'))
  );
  REVOKE ALL ON ${LEDGER_TABLE} FROM PUBLIC;
`;

/**
 * Staging only: the bucket episode audio is written to. No migration creates it
 * (backend-reference §9); it is private here, as BEA.7 makes it in production.
 */
export const STAGING_BUCKETS_SQL = `
  INSERT INTO storage.buckets (id, name, public)
  VALUES ('podcast-audio', 'podcast-audio', FALSE)
  ON CONFLICT (id) DO UPDATE SET public = FALSE;
`;

export interface Executor {
  query(sql: string, params?: unknown[]): Promise<{ rows: Record<string, unknown>[] }>;
}

/** Only accounts the dev route makes start with this; a real Apple subject never does. */
export const TEST_SUBJECT_PREFIX = 'dev-test-user:';

/**
 * Refuses a database that holds a real person. A fresh staging database has no
 * users table; a used one has only dev-test-user accounts. Production has real
 * users, so this stops a run there even if every env check was fooled.
 */
export async function assertOnlyTestUsers(db: Executor): Promise<void> {
  const { rows: exists } = await db.query(`SELECT to_regclass('public.users') IS NOT NULL AS present`);
  if (!exists[0]?.present) return;
  const { rows } = await db.query(
    `SELECT count(*)::int AS n FROM users WHERE apple_user_id IS NULL OR apple_user_id NOT LIKE $1`,
    [`${TEST_SUBJECT_PREFIX}%`],
  );
  const n = Number(rows[0]?.n ?? 0);
  if (n > 0) throw new Error(`Refusing to run: this database has ${n} users who are not test accounts, so it is not staging.`);
}

export interface Plan {
  alreadyRecorded: string[];
  /** Applied first, only on a database that has never had it. */
  base: string | null;
  /** Recorded as present without running, because the base contains them. */
  toBaseline: string[];
  toApply: string[];
}

/** Backend migration files in apply order: three digits, underscore, .sql. */
export function numberedFiles(files: string[]): string[] {
  return files.filter((f) => /^\d{3}_.*\.sql$/.test(f)).sort();
}

export function plan(files: string[], recorded: Set<string>): Plan {
  const numbered = numberedFiles(files);
  const needsBase = !recorded.has(BASE_FILE);
  const out: Plan = { alreadyRecorded: [], base: needsBase ? BASE_FILE : null, toBaseline: [], toApply: [] };
  for (const f of numbered) {
    if (recorded.has(f)) out.alreadyRecorded.push(f);
    else if (needsBase && f <= BASE_COVERS_THROUGH) out.toBaseline.push(f);
    else out.toApply.push(f);
  }
  return out;
}

export async function recordedMigrations(db: Executor, opts: { create: boolean }): Promise<Set<string>> {
  if (opts.create) {
    await db.query(LEDGER_SQL);
  } else {
    const { rows } = await db.query(`SELECT to_regclass('public.${LEDGER_TABLE}') IS NOT NULL AS present`);
    if (!rows[0]?.present) return new Set();
  }
  const { rows } = await db.query(`SELECT file FROM ${LEDGER_TABLE}`);
  return new Set(rows.map((r) => String(r.file)));
}

export interface ApplyResult {
  applied: string[];
  baselined: string[];
  failed?: { file: string; error: string };
}

async function applyOne(db: Executor, file: string, sql: string, extra: string[] = []): Promise<void> {
  await db.query('BEGIN');
  try {
    await db.query(sql);
    await db.query(`INSERT INTO ${LEDGER_TABLE} (file, how) VALUES ($1, 'applied')`, [file]);
    for (const covered of extra) {
      await db.query(`INSERT INTO ${LEDGER_TABLE} (file, how) VALUES ($1, 'baseline') ON CONFLICT (file) DO NOTHING`, [covered]);
    }
    await db.query('COMMIT');
  } catch (err) {
    await db.query('ROLLBACK').catch(() => undefined);
    throw err;
  }
}

/**
 * Carries out a plan. The base and the files it covers are recorded in the same
 * transaction, so a failed base leaves nothing recorded. Stops at the first
 * failure: later migrations may depend on it.
 */
export async function applyPlan(db: Executor, p: Plan, readSql: (file: string) => string): Promise<ApplyResult> {
  const result: ApplyResult = { applied: [], baselined: [] };
  const steps: { file: string; extra: string[] }[] = [
    ...(p.base ? [{ file: p.base, extra: p.toBaseline }] : []),
    ...p.toApply.map((file) => ({ file, extra: [] })),
  ];
  for (const step of steps) {
    try {
      await applyOne(db, step.file, readSql(step.file), step.extra);
      result.applied.push(step.file);
      result.baselined.push(...step.extra);
    } catch (err) {
      result.failed = { file: step.file, error: (err as Error).message.split('\n')[0] ?? 'unknown error' };
      break;
    }
  }
  return result;
}
