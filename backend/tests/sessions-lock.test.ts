/**
 * BE0.4 review: the row lock in rotate_refresh_token, and BE0.12's guard in
 * redeem_invite, proven on a real Postgres server with two connections. PGlite has one connection, so it can't show
 * that a second refresh waits for the first; a server can.
 *
 * The server is a throwaway Postgres 17 (embedded-postgres: the official
 * binaries from npm, run from a temp directory on a free local port, deleted
 * after). Only users and migrations 005 and 007 are applied; nothing leaves the machine.
 */
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { createServer } from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test, { after, before } from 'node:test';
import pg from 'pg';
import EmbeddedPostgres from 'embedded-postgres';

const MIGRATIONS = ['005_sessions.sql', '007_invites.sql'].map((f) => join(__dirname, '..', '..', 'supabase', 'migrations', f));
const PASSWORD = 'test-only-not-a-key';

let server: EmbeddedPostgres;
let dir: string;
let port: number;

async function freePort(): Promise<number> {
  return new Promise((resolve) => {
    const s = createServer();
    s.listen(0, '127.0.0.1', () => {
      const p = (s.address() as { port: number }).port;
      s.close(() => resolve(p));
    });
  });
}

const client = () => new pg.Client({ host: '127.0.0.1', port, user: 'postgres', password: PASSWORD, database: 'sessions' });

before(async () => {
  dir = mkdtempSync(join(tmpdir(), 'sessions-pg-'));
  port = await freePort();
  server = new EmbeddedPostgres({ databaseDir: dir, port, user: 'postgres', password: PASSWORD, persistent: false, onLog: () => undefined, onError: () => undefined });
  await server.initialise();
  await server.start();
  await server.createDatabase('sessions');
  const setup = client();
  await setup.connect();
  await setup.query(`
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    DO $$ BEGIN CREATE ROLE anon; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
    DO $$ BEGIN CREATE ROLE authenticated; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
    DO $$ BEGIN CREATE ROLE service_role; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
    CREATE TABLE users (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), apple_user_id TEXT UNIQUE NOT NULL);`);
  for (const file of MIGRATIONS) await setup.query(readFileSync(file, 'utf8'));
  await setup.end();
});

after(async () => {
  await server?.stop();
  if (dir) rmSync(dir, { recursive: true, force: true });
});

const T0 = '2026-10-21T12:00:00.000Z';

test('a second refresh of the same token waits for the first, then gets its successor', async () => {
  const setup = client();
  await setup.connect();
  const { rows: [user] } = await setup.query<{ id: string }>(`INSERT INTO users (apple_user_id) VALUES ('apple-lock') RETURNING id`);
  await setup.query(`SELECT issue_session($1, 'hash-0', $2)`, [user!.id, T0]);
  await setup.end();

  const a = client(), b = client();
  await a.connect();
  await b.connect();
  try {
    // A refreshes inside an open transaction: it holds the row lock.
    await a.query('BEGIN');
    const first = await a.query<{ r: { outcome: string } }>(`SELECT rotate_refresh_token('hash-0', 'hash-a', $1, 'sealed-a') AS r`, [T0]);
    assert.equal(first.rows[0]!.r.outcome, 'rotated');

    // B refreshes the same token meanwhile.
    let bDone = false;
    const second = b.query<{ r: { outcome: string; refresh_ciphertext?: string } }>(
      `SELECT rotate_refresh_token('hash-0', 'hash-b', $1, 'sealed-b') AS r`, [T0]).then((r) => { bDone = true; return r; });
    await new Promise((r) => setTimeout(r, 300));
    assert.equal(bDone, false, 'B is blocked on the row lock while A is open');

    await a.query('COMMIT');
    const outcome = (await second).rows[0]!.r;
    assert.equal(outcome.outcome, 'grace', 'B sees A rotated it, and gets A\'s successor');
    assert.equal(outcome.refresh_ciphertext, 'sealed-a');

    const { rows } = await a.query<{ n: number }>(`SELECT count(*)::int n FROM refresh_tokens WHERE user_id = $1`, [user!.id]);
    assert.equal(rows[0]!.n, 2, 'one successor, not two');
  } finally {
    await a.end();
    await b.end();
  }
});

test('two people redeeming one code at once: the second waits, then finds it used', async () => {
  const setup = client();
  await setup.connect();
  const ids: string[] = [];
  for (const name of ['apple-redeem-a', 'apple-redeem-b']) {
    const { rows: [u] } = await setup.query<{ id: string }>(`INSERT INTO users (apple_user_id) VALUES ($1) RETURNING id`, [name]);
    ids.push(u!.id);
  }
  await setup.query(`INSERT INTO invites (code_hash, kind) VALUES ('code-hash-1', 'founder')`);
  await setup.end();

  const a = client(), b = client();
  await a.connect();
  await b.connect();
  const redeem = (c: pg.Client, user: string, n: string) => c.query<{ r: { outcome: string } }>(
    `SELECT redeem_invite($1, 'code-hash-1', $2, ARRAY['new-${n}-1', 'new-${n}-2', 'new-${n}-3'], ARRAY['s1', 's2', 's3']) AS r`, [user, T0]);
  try {
    await a.query('BEGIN');
    assert.equal((await redeem(a, ids[0]!, 'a')).rows[0]!.r.outcome, 'redeemed');
    let bDone = false;
    const second = redeem(b, ids[1]!, 'b').then((r) => { bDone = true; return r; });
    await new Promise((r) => setTimeout(r, 300));
    assert.equal(bDone, false, "B waits on A's claim of the invite");
    await a.query('COMMIT');
    assert.equal((await second).rows[0]!.r.outcome, 'used');

    const { rows } = await a.query<{ used_by: string; b_access: string; b_invites: number }>(`
      SELECT (SELECT used_by_user_id::text FROM invites WHERE code_hash = 'code-hash-1') used_by,
             (SELECT access FROM users WHERE id = $1) b_access,
             (SELECT count(*)::int FROM invites WHERE owner_user_id = $1) b_invites`, [ids[1]]);
    assert.deepEqual(rows[0], { used_by: ids[0], b_access: 'waitlisted', b_invites: 0 }, 'A has it; B got nothing');
  } finally {
    await a.end();
    await b.end();
  }
});
