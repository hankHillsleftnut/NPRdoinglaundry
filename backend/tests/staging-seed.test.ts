import assert from 'node:assert/strict';
import test from 'node:test';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { assertStaging, loadStagingEnv, NotStagingError, postgresTls } from '../scripts/staging/guard.js';
import {
  ACCOUNTS, MONTH_DAYS, NotStagingDatabaseError, SEED_MODEL_VERSION, seedAll, type AccountKey, type Row, type SeedPorts, type SeedTable,
} from '../scripts/staging/seed.js';

const NOW = new Date('2026-10-21T12:00:00.000Z');

/**
 * An in-memory stand-in for the dev route and the database. The dev route
 * finds an account by its key the way getOrCreateUser finds it by Apple
 * subject; deleting an account cascades to its rows, as every FK to users does.
 */
function fakePorts() {
  const faults: { failInsertInto?: SeedTable; realUsers?: number } = {};
  const users = new Map<AccountKey, string>();
  const rows: Record<SeedTable, (Row & { id: string })[]> = {
    raw_content: [], daily_briefs: [], hypotheses: [], podcast_episodes: [],
  };
  let next = 1;
  const isSeeded = (table: SeedTable, r: Row) =>
    table === 'raw_content' || table === 'podcast_episodes'
      ? (r.metadata as { test_account?: boolean } | undefined)?.test_account === true
      : r.model_version === SEED_MODEL_VERSION;

  const ports: SeedPorts = {
    async ensureAccount(key) {
      if (!users.has(key)) users.set(key, `user-${next++}`);
      return users.get(key)!;
    },
    async seededIds(table, userId) {
      return rows[table].filter((r) => r.user_id === userId && isSeeded(table, r)).map((r) => r.id);
    },
    async insert(table, batch) {
      if (faults.failInsertInto === table) throw new Error(`inserting into ${table} failed`);
      const stored = batch.map((r) => ({ ...r, id: `${table}-${next++}` }));
      rows[table].push(...stored);
      return stored.map((r) => r.id);
    },
    async hasBriefOn(userId, briefDate) {
      return rows.daily_briefs.some((r) => r.user_id === userId && r.brief_date === briefDate);
    },
    async nonTestUserCount() {
      return faults.realUsers ?? 0;
    },
    async deleteAccount(userId) {
      for (const [key, id] of users) if (id === userId) users.delete(key);
      for (const table of Object.keys(rows) as SeedTable[]) rows[table] = rows[table].filter((r) => r.user_id !== userId);
    },
  };
  return { ports, users, rows, faults };
}

// BE0.S: the seed must be safe to run again, or staging fills with duplicates.
test('the seed script is idempotent: running it twice leaves three test users', async () => {
  const { ports, users, rows } = fakePorts();
  await seedAll(ports, NOW, { reset: false });
  const second = await seedAll(ports, NOW, { reset: false });

  assert.equal(users.size, 3);
  assert.deepEqual([...users.keys()], [...ACCOUNTS]);
  assert.equal(rows.raw_content.length, MONTH_DAYS + 1, 'thirty entries for month, one onboarding row for day-one');
  assert.equal(rows.daily_briefs.length, 1);
  assert.equal(rows.hypotheses.length, 2);
  assert.equal(rows.podcast_episodes.length, 1);
  assert.ok(second.every((r) => Object.keys(r.inserted).length === 0), 'the second run inserts nothing');
});

test('each account holds what its name says, and nothing of another account', async () => {
  const { ports, users, rows } = fakePorts();
  await seedAll(ports, NOW, { reset: false });
  const owned = (key: AccountKey) => {
    const id = users.get(key);
    return Object.fromEntries((Object.keys(rows) as SeedTable[]).map((t) => [t, rows[t].filter((r) => r.user_id === id).length]));
  };
  assert.deepEqual(owned('fresh'), { raw_content: 0, daily_briefs: 0, hypotheses: 0, podcast_episodes: 0 });
  assert.deepEqual(owned('day-one'), { raw_content: 1, daily_briefs: 0, hypotheses: 0, podcast_episodes: 0 });
  assert.deepEqual(owned('month'), { raw_content: MONTH_DAYS, daily_briefs: 1, hypotheses: 2, podcast_episodes: 1 });
  assert.equal(rows.raw_content.find((r) => r.user_id === users.get('day-one'))?.content_type, 'onboarding_profile');
});

test('every seeded row is marked as test data', async () => {
  const { ports, rows } = fakePorts();
  await seedAll(ports, NOW, { reset: false });
  for (const r of [...rows.raw_content, ...rows.podcast_episodes]) {
    assert.equal((r.metadata as { test_account?: boolean }).test_account, true);
  }
  for (const r of [...rows.daily_briefs, ...rows.hypotheses]) assert.equal(r.model_version, SEED_MODEL_VERSION);
});

test('the month account alternates typed and voice entries, one a day, oldest first', async () => {
  const { ports, rows } = fakePorts();
  await seedAll(ports, NOW, { reset: false });
  const types = rows.raw_content.filter((r) => r.content_type !== 'onboarding_profile').map((r) => r.content_type);
  assert.equal(types.filter((t) => t === 'journal_entry').length, MONTH_DAYS / 2);
  assert.equal(types.filter((t) => t === 'voice_journal').length, MONTH_DAYS / 2);
  const dates = rows.raw_content.filter((r) => r.content_type !== 'onboarding_profile').map((r) => String(r.content_date));
  assert.deepEqual([...dates].sort(), dates);
  assert.ok(dates.every((d) => d < NOW.toISOString()), 'no entry is dated in the future');
});

// A brief quote must be found in its source (agent vetBrief), or the brief is
// not a valid example of what the agent writes.
test('the seeded brief quotes entries that exist, word for word', async () => {
  const { ports, rows } = fakePorts();
  await seedAll(ports, NOW, { reset: false });
  const brief = rows.daily_briefs[0]!;
  assert.equal(brief.brief_date, '2026-10-21');
  const items = brief.items as { quote: string; sourceRef: { raw_content_id: string } }[];
  assert.equal(items.length, 2);
  for (const item of items) {
    const source = rows.raw_content.find((r) => r.id === item.sourceRef.raw_content_id);
    assert.ok(source, 'the item points at a seeded entry');
    assert.ok(String(source.content).includes(item.quote), 'the quote is in that entry');
  }
});

test('reset removes the accounts and seeds them fresh, still three', async () => {
  const { ports, users, rows } = fakePorts();
  await seedAll(ports, NOW, { reset: false });
  const before = users.get('month');
  await seedAll(ports, NOW, { reset: true });
  assert.equal(users.size, 3);
  assert.notEqual(users.get('month'), before, 'the month account is a new one');
  assert.equal(rows.raw_content.length, MONTH_DAYS + 1);
  assert.equal(rows.daily_briefs.length, 1);
});

test('a failed insert stops the seed, and a re-run finishes it without duplicating what landed', async () => {
  const { ports, rows, faults } = fakePorts();
  faults.failInsertInto = 'hypotheses';
  await assert.rejects(seedAll(ports, NOW, { reset: false }), /hypotheses/);
  assert.equal(rows.raw_content.length, MONTH_DAYS + 1);
  assert.equal(rows.hypotheses.length, 0);

  delete faults.failInsertInto;
  await seedAll(ports, NOW, { reset: false });
  assert.equal(rows.raw_content.length, MONTH_DAYS + 1, 'entries are not inserted twice');
  assert.equal(rows.daily_briefs.length, 1);
  assert.equal(rows.hypotheses.length, 2);
  assert.equal(rows.podcast_episodes.length, 1);
});

// Staging scripts write to a database; only an env file that says staging may run them.
test('staging scripts refuse to run outside staging', () => {
  assert.throws(() => assertStaging({}), NotStagingError);
  assert.throws(() => assertStaging({ RETROSPECT_ENV: 'production' }), NotStagingError);
  assert.doesNotThrow(() => assertStaging({ RETROSPECT_ENV: 'staging' }));
});

// Integrator review of #59: the last line of defence is the database itself.
test('a database with any real user is refused before anything is written', async () => {
  const { ports, users, rows, faults } = fakePorts();
  faults.realUsers = 1;
  await assert.rejects(seedAll(ports, NOW, { reset: true }), NotStagingDatabaseError);
  assert.equal(users.size, 0, 'no account was made or removed');
  assert.equal(rows.raw_content.length, 0);
});

test('today\'s brief is keyed on the date: a later day gets its own, the same day never clashes', async () => {
  const { ports, rows, users } = fakePorts();
  await seedAll(ports, NOW, { reset: false });
  await seedAll(ports, new Date('2026-10-22T09:00:00.000Z'), { reset: false });
  assert.deepEqual(rows.daily_briefs.map((b) => b.brief_date), ['2026-10-21', '2026-10-22']);

  // A brief the agent wrote for today (not seeded) is left alone, not duplicated.
  rows.daily_briefs.push({ id: 'agent-brief', user_id: users.get('month'), brief_date: '2026-10-23', model_version: 'claude' });
  await seedAll(ports, new Date('2026-10-23T09:00:00.000Z'), { reset: false });
  assert.equal(rows.daily_briefs.filter((b) => b.brief_date === '2026-10-23').length, 1);
});

// Integrator review of #59: node --env-file never overrides the shell, so an
// exported production DATABASE_URL would have won.
test('the staging env file wins over values already in the shell', () => {
  const dir = mkdtempSync(join(tmpdir(), 'staging-env-'));
  const file = join(dir, '.env.staging');
  writeFileSync(file, 'RETROSPECT_ENV=staging\nDATABASE_URL=postgres://staging.invalid/db\n');
  const env: NodeJS.ProcessEnv = { RETROSPECT_ENV: 'production', DATABASE_URL: 'postgres://production.invalid/db' };
  loadStagingEnv(file, env);
  assert.equal(env.DATABASE_URL, 'postgres://staging.invalid/db');
  assert.equal(env.RETROSPECT_ENV, 'staging');
  assert.throws(() => loadStagingEnv(join(dir, 'missing'), {}), /could not read missing/);
});

test('the Postgres connection is verified against the CA certificate, never unverified', () => {
  assert.throws(() => postgresTls({}), /DATABASE_CA_CERT is not set/);
  assert.deepEqual(postgresTls({ DATABASE_CA_CERT: '/ca.crt' }, (p) => `cert at ${p}`), { ca: 'cert at /ca.crt', rejectUnauthorized: true });
});
