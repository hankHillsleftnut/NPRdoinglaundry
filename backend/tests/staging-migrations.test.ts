import assert from 'node:assert/strict';
import { readdirSync } from 'node:fs';
import { join } from 'node:path';
import test from 'node:test';
import {
  BASE_FILE, LEDGER_TABLE, applyPlan, assertOnlyTestUsers, plan, recordedMigrations, type Executor,
} from '../scripts/staging/migrations.js';

const FILES = ['004_podcast_episodes_and_voice_persona.sql', '001_initial_schema.sql', '003_goals_observations_insights.sql',
  '002_seed_categories.sql', 'README.md'];

/**
 * A fake database that keeps the ledger and honours transactions: statements
 * between BEGIN and ROLLBACK are discarded, as Postgres discards them.
 */
function fakeDb(opts: { failOn?: string } = {}) {
  const ledger = new Map<string, string>();
  const ran: string[] = [];
  let pending: { ledger: [string, string][]; ran: string[] } | null = null;
  let ledgerExists = false;

  const db: Executor = {
    async query(sql, params = []) {
      const s = sql.trim();
      if (s === 'BEGIN') { pending = { ledger: [], ran: [] }; return { rows: [] }; }
      if (s === 'COMMIT') {
        for (const [f, how] of pending!.ledger) ledger.set(f, how);
        ran.push(...pending!.ran);
        pending = null;
        return { rows: [] };
      }
      if (s === 'ROLLBACK') { pending = null; return { rows: [] }; }
      if (s.includes('CREATE TABLE IF NOT EXISTS')) { ledgerExists = true; return { rows: [] }; }
      if (s.includes('to_regclass')) return { rows: [{ present: ledgerExists }] };
      if (s.startsWith(`SELECT file FROM ${LEDGER_TABLE}`)) return { rows: [...ledger.keys()].map((file) => ({ file })) };
      if (s.startsWith(`INSERT INTO ${LEDGER_TABLE}`)) {
        const how = s.includes("'baseline'") ? 'baseline' : 'applied';
        (pending?.ledger ?? []).push([String(params[0]), how]);
        return { rows: [] };
      }
      if (opts.failOn && s === `sql of ${opts.failOn}`) throw new Error('syntax error at or near "x"\nLINE 1: ...');
      pending?.ran.push(s);
      return { rows: [] };
    },
  };
  return { db, ledger, ran };
}

const readSql = (file: string) => `sql of ${file}`;

// 001 and 003 cannot be replayed (ivfflat on 3072 dimensions), so a fresh
// database gets the combined base and records 001-003 as contained in it.
test('a fresh database gets the combined base, then every numbered file after 003', () => {
  const p = plan(FILES, new Set());
  assert.equal(p.base, BASE_FILE);
  assert.deepEqual(p.toBaseline, ['001_initial_schema.sql', '002_seed_categories.sql', '003_goals_observations_insights.sql']);
  assert.deepEqual(p.toApply, ['004_podcast_episodes_and_voice_persona.sql']);
});

test('a second run applies nothing', async () => {
  const { db, ran } = fakeDb();
  await applyPlan(db, plan(FILES, await recordedMigrations(db, { create: true })), readSql);
  const again = plan(FILES, await recordedMigrations(db, { create: true }));
  assert.equal(again.base, null);
  assert.deepEqual(again.toApply, []);
  assert.deepEqual(again.toBaseline, []);
  assert.deepEqual(ran, [`sql of ${BASE_FILE}`, 'sql of 004_podcast_episodes_and_voice_persona.sql']);
});

test('a later numbered file is applied on its own, without the base', () => {
  const recorded = new Set([BASE_FILE, '001_initial_schema.sql', '002_seed_categories.sql',
    '003_goals_observations_insights.sql', '004_podcast_episodes_and_voice_persona.sql']);
  const p = plan([...FILES, '005_sessions.sql'], recorded);
  assert.equal(p.base, null);
  assert.deepEqual(p.toApply, ['005_sessions.sql']);
});

test('a failed migration is rolled back, recorded nowhere, and nothing after it runs', async () => {
  const { db, ledger, ran } = fakeDb({ failOn: '004_podcast_episodes_and_voice_persona.sql' });
  const result = await applyPlan(db, plan([...FILES, '005_sessions.sql'], new Set()), readSql);
  assert.deepEqual(result.failed, { file: '004_podcast_episodes_and_voice_persona.sql', error: 'syntax error at or near "x"' });
  assert.deepEqual(result.applied, [BASE_FILE]);
  assert.equal(ledger.has('004_podcast_episodes_and_voice_persona.sql'), false);
  assert.equal(ran.includes('sql of 005_sessions.sql'), false);
});

test('a failed base records none of the files it covers', async () => {
  const { db, ledger } = fakeDb({ failOn: BASE_FILE });
  const result = await applyPlan(db, plan(FILES, new Set()), readSql);
  assert.equal(result.failed?.file, BASE_FILE);
  assert.equal(ledger.size, 0);
});

test('a preview never creates the ledger', async () => {
  const { db } = fakeDb();
  assert.deepEqual([...(await recordedMigrations(db, { create: false }))], []);
  const created = await db.query(`SELECT to_regclass('public.${LEDGER_TABLE}') IS NOT NULL AS present`);
  assert.equal(created.rows[0]?.present, false);
});

// The plan must match the files actually in the repo, so a new migration shows up.
test('the repo migrations are planned in order', () => {
  const files = readdirSync(join(__dirname, '..', '..', 'supabase', 'migrations'));
  const p = plan(files, new Set());
  assert.deepEqual([...p.toBaseline, ...p.toApply], files.filter((f) => /^\d{3}_.*\.sql$/.test(f)).sort());
});

// Integrator review of #59: refuse any database holding a real person.
test('a database with a real user is refused; a fresh one or one with only test users is not', async () => {
  const db = (present: boolean, nonTest: number): Executor => ({
    async query(sql: string) {
      if (sql.includes('to_regclass')) return { rows: [{ present }] };
      return { rows: [{ n: nonTest }] };
    },
  });
  await assert.doesNotReject(assertOnlyTestUsers(db(false, 0)), 'fresh: no users table yet');
  await assert.doesNotReject(assertOnlyTestUsers(db(true, 0)), 'only dev-test-user accounts');
  await assert.rejects(assertOnlyTestUsers(db(true, 3)), /3 users who are not test accounts/);
});
