/**
 * BE0.7: migration 028 on a database built from every migration (PGlite), and
 * the lock's concurrency on a real two-connection Postgres (embedded-postgres,
 * like sessions-lock.test.ts). Nothing leaves the machine; no real person.
 */
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { createServer } from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test, { after, before } from 'node:test';
import pg from 'pg';
import EmbeddedPostgres from 'embedded-postgres';
import { supabaseDeletionStore } from '../src/account/store.js';
import { asServiceRole, freshDatabase, insertUser, type PGlite } from './support/database.js';
import { pgliteRpc } from './support/pglite-rpc.js';

const T0 = '2026-10-23T12:00:00.000Z';
const T1 = '2026-10-23T12:10:00.000Z';
const LATER = '2026-10-23T13:00:00.000Z';

let db: PGlite;
before(async () => {
  db = await freshDatabase();
});

const store = () => supabaseDeletionStore(pgliteRpc(db));

async function userState(id: string) {
  const { rows } = await db.query<{ access: string; token_version: number; cipher: string | null }>(
    'SELECT access, token_version, apple_refresh_token_ciphertext AS cipher FROM users WHERE id = $1', [id]);
  return rows[0] ?? null;
}

async function withSession(id: string, hash: string) {
  await db.query('SELECT issue_session($1, $2, $3, $4, $5)', [id, hash, T0, null, 0]);
  await db.query('INSERT INTO refresh_grace (token_hash, refresh_ciphertext, expires_at) VALUES ($1, $2, $3)', [hash, 'sealed-grace', LATER]);
}

const openFamilies = async (id: string) =>
  (await db.query<{ n: number }>('SELECT count(*)::int n FROM refresh_tokens WHERE user_id = $1 AND revoked_at IS NULL', [id])).rows[0]!.n;
const graceRows = async (hash: string) =>
  (await db.query<{ n: number }>('SELECT count(*)::int n FROM refresh_grace WHERE token_hash = $1', [hash])).rows[0]!.n;
const deletionRows = async (userId: string) =>
  (await db.query<{ n: number }>('SELECT count(*)::int n FROM account_deletions WHERE user_id = $1', [userId])).rows[0]!.n;

test('the lock is one step: the row, access suspended, token_version bumped, every family ended', async () => {
  const alice = await insertUser(db);
  const bob = await insertUser(db);
  await withSession(alice, 'lock-a1');
  await withSession(alice, 'lock-a2');
  await withSession(bob, 'lock-b1');
  const bobBefore = await userState(bob);
  const s = store();

  const locked = await asServiceRole(db, () => s.lock(alice, T0, false, null));
  assert.equal(locked.outcome, 'locked');
  assert.ok(locked.outcome === 'locked' && locked.created);
  assert.deepEqual(await userState(alice), { access: 'suspended', token_version: 1, cipher: null });
  assert.equal(await openFamilies(alice), 0, 'every family of hers ended');
  assert.equal(await graceRows('lock-a1'), 0, 'and her grace rows gone');
  const { rows: [row] } = await db.query<{ state: string; apple: string | null }>('SELECT state, apple FROM account_deletions WHERE user_id = $1', [alice]);
  assert.deepEqual(row, { state: 'requested', apple: 'skipped' }, 'flag off: Apple is skipped');

  assert.deepEqual(await userState(bob), bobBefore, "Bob's account untouched");
  assert.equal(await openFamilies(bob), 1);
  assert.equal(await graceRows('lock-b1'), 1);
});

test('a second lock returns the same deletion and bumps nothing again', async () => {
  const alice = await insertUser(db);
  const s = store();
  const first = await s.lock(alice, T0, false, null);
  const second = await s.lock(alice, T1, false, null);
  assert.ok(first.outcome === 'locked' && second.outcome === 'locked');
  assert.equal(second.id, first.id);
  assert.equal(second.created, false);
  assert.equal((await userState(alice))!.token_version, 1, 'bumped once');
  assert.equal(await deletionRows(alice), 1);
  const prep = await s.prepare(alice);
  assert.ok(prep.outcome === 'ok' && prep.deletionId === first.id, 'prepare sees the open deletion');
});

test('Apple required with no token kept and none given: nothing changes at all', async () => {
  const alice = await insertUser(db);
  await withSession(alice, 'apple-none-1');
  const before = await userState(alice);
  const result = await store().lock(alice, T0, true, null);
  assert.deepEqual(result, { outcome: 'apple_confirmation_required' });
  assert.deepEqual(await userState(alice), before);
  assert.equal(await openFamilies(alice), 1);
  assert.equal(await deletionRows(alice), 0);
});

test('Apple required: a fresh sealed token is stored with the lock; a kept one is enough', async () => {
  const alice = await insertUser(db);
  const locked = await store().lock(alice, T0, true, 'v1:fresh-sealed');
  assert.equal(locked.outcome, 'locked');
  assert.equal((await userState(alice))!.cipher, 'v1:fresh-sealed');
  const { rows: [row] } = await db.query<{ apple: string | null }>('SELECT apple FROM account_deletions WHERE user_id = $1', [alice]);
  assert.equal(row!.apple, null, 'Apple still to do');

  const bob = await insertUser(db);
  await db.query(`UPDATE users SET apple_refresh_token_ciphertext = 'v1:kept' WHERE id = $1`, [bob]);
  const prep = await store().prepare(bob);
  assert.ok(prep.outcome === 'ok' && prep.hasAppleToken && prep.deletionId === null);
  assert.equal((await store().lock(bob, T0, true, null)).outcome, 'locked');
  assert.equal((await userState(bob))!.cipher, 'v1:kept', 'the kept token stays');
});

test('a waitlisted or paused person can be locked', async () => {
  for (const access of ['waitlisted', 'suspended']) {
    const id = await insertUser(db);
    await db.query('UPDATE users SET access = $2 WHERE id = $1', [id, access]);
    assert.equal((await store().lock(id, T0, false, null)).outcome, 'locked', access);
  }
});

test('one worker at a time: the lease, its expiry, and the sweeper skipping finished rows', async () => {
  const alice = await insertUser(db);
  const s = store();
  const locked = await s.lock(alice, T0, false, null);
  assert.ok(locked.outcome === 'locked');
  const first = await s.claim(locked.id, T0, 600);
  assert.ok(first);
  assert.equal(first.runs, 1);
  assert.equal(first.userId, alice);
  const midLease = '2026-10-23T12:05:00.000Z';
  assert.equal(await s.claim(locked.id, midLease, 600), null, 'held by the first worker');
  const due = await s.claimDue(midLease, 600, 50);
  assert.equal(due.some((r) => r.id === locked.id), false, 'the sweeper skips a held row');

  // The worker died: its lease runs out and the sweeper takes the row.
  const later = await s.claimDue(LATER, 600, 50);
  const taken = later.find((r) => r.id === locked.id);
  assert.ok(taken, 'picked up after the lease ran out');
  assert.equal(taken.runs, 2);

  await s.defer(locked.id, LATER);
  assert.equal(await s.claim(locked.id, T1, 600), null, 'a deferred row waits for its next run');
  assert.ok(await s.claim(locked.id, LATER, 600), 'then it can be claimed again');
});

test('the users row goes, everything of hers cascades, the log row outlives it, and Bob keeps his', async () => {
  const alice = await insertUser(db);
  const bob = await insertUser(db);
  for (const [id, hash] of [[alice, 'casc-a'], [bob, 'casc-b']] as const) {
    await withSession(id, hash);
    await db.query(`INSERT INTO invites (code_hash, kind, owner_user_id) VALUES ($1, 'member', $2)`, [`invite-${hash}`, id]);
  }
  await db.query(`UPDATE users SET apple_refresh_token_ciphertext = 'v1:alice-sealed' WHERE id = $1`, [alice]);
  const s = store();
  const locked = await s.lock(alice, T0, true, null);
  assert.ok(locked.outcome === 'locked');
  assert.equal(await s.appleToken(locked.id), 'v1:alice-sealed', 'readable while the deletion is open');

  assert.equal(await s.deleteUser(locked.id, T1), 'user_deleted');
  assert.equal(await userState(alice), null, 'her users row is gone');
  const left = async (id: string) => (await db.query<{ n: number }>(
    `SELECT ((SELECT count(*) FROM refresh_tokens WHERE user_id = $1) + (SELECT count(*) FROM invites WHERE owner_user_id = $1))::int n`, [id])).rows[0]!.n;
  assert.equal(await left(alice), 0, 'her sessions and invites cascaded');
  assert.equal(await left(bob), 2, "Bob's are all there");
  assert.ok(await userState(bob));
  assert.equal(await s.appleToken(locked.id), null, 'no token once the row is gone');

  const { rows: [row] } = await db.query<{ state: string; user_id: string }>('SELECT state, user_id FROM account_deletions WHERE id = $1', [locked.id]);
  assert.deepEqual(row, { state: 'user_deleted', user_id: alice }, 'the log row outlives the users row');
  assert.equal(await s.deleteUser(locked.id, T1), 'user_deleted', 'safe to repeat');
  await s.finish(locked.id, T1);
  assert.equal(await s.deleteUser(locked.id, T1), 'deleted');
  assert.equal(await s.claim(locked.id, LATER, 600), null, 'a finished deletion is never claimed');
  assert.equal(await s.deleteUser('9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c99', T1), 'not_found', 'no deletion row, no delete');
});

test('the log holds only ids, states, counts and result words', async () => {
  const { rows } = await db.query<{ column_name: string; data_type: string }>(
    `SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'account_deletions' ORDER BY ordinal_position`);
  assert.deepEqual(rows.map((r) => r.column_name), [
    'id', 'user_id', 'state', 'apple', 'sweep_before', 'sweep_after', 'diagnostics', 'grants_failed', 'objects_skipped',
    'diagnostics_removed', 'runs', 'claimed_until', 'next_run_at', 'created_at', 'user_deleted_at', 'finished_at',
  ]);
  const alice = await insertUser(db);
  const locked = await store().lock(alice, T0, true, 'v1:x');
  assert.ok(locked.outcome === 'locked');
  // A word outside the closed lists (say, a token by mistake) is refused by the table itself.
  await assert.rejects(store().note(locked.id, { apple: 'r.apple-refresh-placeholder' as never }), /note_account_deletion failed/);
  await store().note(locked.id, { apple: 'already_revoked', grantsFailed: 2 });
  const { rows: [row] } = await db.query<{ apple: string; grants_failed: number }>('SELECT apple, grants_failed FROM account_deletions WHERE id = $1', [locked.id]);
  assert.deepEqual(row, { apple: 'already_revoked', grants_failed: 2 });
});

test('no foreign key to users can block the row delete: every one is CASCADE or SET NULL', async () => {
  const { rows } = await db.query<{ tbl: string; rule: string }>(`
    SELECT c.conrelid::regclass::text AS tbl, c.confdeltype AS rule
      FROM pg_constraint c
     WHERE c.contype = 'f' AND c.confrelid = 'public.users'::regclass`);
  assert.ok(rows.length >= 10, `found ${rows.length} keys to users`);
  const blocking = rows.filter((r) => r.rule !== 'c' && r.rule !== 'n');
  assert.deepEqual(blocking, [], 'every key to users is ON DELETE CASCADE or SET NULL');
  assert.equal(rows.some((r) => r.tbl === 'account_deletions'), false, 'the log has no key to users');
});

test('the log and its functions are service_role only', async () => {
  for (const role of ['anon', 'authenticated']) {
    await db.exec(`SET ROLE ${role}`);
    try {
      await assert.rejects(db.query('SELECT count(*) FROM account_deletions'), /permission denied/, `${role} reads nothing`);
      await assert.rejects(db.query(`SELECT lock_account_for_deletion(gen_random_uuid(), now(), false, NULL)`), /permission denied/, `${role} locks nothing`);
      await assert.rejects(db.query(`SELECT delete_account_user(gen_random_uuid(), now())`), /permission denied/, `${role} deletes nothing`);
    } finally {
      await db.exec('RESET ROLE');
    }
  }
  const { rows } = await db.query<{ rls: boolean }>(`SELECT relrowsecurity AS rls FROM pg_class WHERE relname = 'account_deletions'`);
  assert.equal(rows[0]!.rls, true);
});

// ---------------------------------------------------------------------------
// Two requests at once, on a real server with two connections.

const PASSWORD = 'test-only-not-a-key';
let server: EmbeddedPostgres | undefined;
let dir: string | undefined;
let port = 0;
const client = () => new pg.Client({ host: '127.0.0.1', port, user: 'postgres', password: PASSWORD, database: 'deletions' });

async function freePort(): Promise<number> {
  return new Promise((resolve) => {
    const s = createServer();
    s.listen(0, '127.0.0.1', () => {
      const p = (s.address() as { port: number }).port;
      s.close(() => resolve(p));
    });
  });
}

after(async () => {
  await server?.stop();
  if (dir) rmSync(dir, { recursive: true, force: true });
});

test('two deletion requests at once: the second waits, then gets the same deletion', async () => {
  dir = mkdtempSync(join(tmpdir(), 'deletions-pg-'));
  port = await freePort();
  server = new EmbeddedPostgres({ databaseDir: dir, port, user: 'postgres', password: PASSWORD, persistent: false, onLog: () => undefined, onError: () => undefined });
  await server.initialise();
  await server.start();
  await server.createDatabase('deletions');
  const setup = client();
  await setup.connect();
  await setup.query(`
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    DO $$ BEGIN CREATE ROLE anon; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
    DO $$ BEGIN CREATE ROLE authenticated; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
    DO $$ BEGIN CREATE ROLE service_role; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
    CREATE TABLE users (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), apple_user_id TEXT UNIQUE NOT NULL);`);
  for (const f of ['005_sessions.sql', '007_invites.sql', '025_refresh_token_version.sql', '027_apple_tokens.sql', '028_deletions.sql']) {
    await setup.query(readFileSync(join(__dirname, '..', '..', 'supabase', 'migrations', f), 'utf8'));
  }
  const { rows: [user] } = await setup.query<{ id: string }>(`INSERT INTO users (apple_user_id) VALUES ('apple-concurrent') RETURNING id`);
  await setup.end();

  const a = client(), b = client();
  await a.connect();
  await b.connect();
  const lock = (c: pg.Client) => c.query<{ r: { outcome: string; id: string; created: boolean } }>(
    'SELECT lock_account_for_deletion($1, $2, false, NULL) AS r', [user!.id, T0]);
  try {
    await a.query('BEGIN');
    const first = (await lock(a)).rows[0]!.r;
    let bDone = false;
    const second = lock(b).then((r) => { bDone = true; return r; });
    await new Promise((r) => setTimeout(r, 300));
    assert.equal(bDone, false, 'B waits on the users row lock while A is open');
    await a.query('COMMIT');
    const other = (await second).rows[0]!.r;
    assert.equal(other.id, first.id, 'the same deletion');
    assert.equal(other.created, false);
    const { rows } = await a.query<{ n: number; v: number }>(
      `SELECT (SELECT count(*)::int FROM account_deletions WHERE user_id = $1) n, (SELECT token_version FROM users WHERE id = $1) v`, [user!.id]);
    assert.deepEqual(rows[0], { n: 1, v: 1 }, 'one row, one bump');
  } finally {
    await a.end();
    await b.end();
  }
});
