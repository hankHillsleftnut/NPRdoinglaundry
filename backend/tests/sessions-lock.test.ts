/**
 * BE0.4 review: the row lock in rotate_refresh_token, proven on a real Postgres
 * server with two connections. PGlite has one connection, so it can't show
 * that a second refresh waits for the first; a server can.
 *
 * The server is a throwaway Postgres 17 (embedded-postgres: the official
 * binaries from npm, run from a temp directory on a free local port, deleted
 * after). Only users and migration 005 are applied; nothing leaves the machine.
 */
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { createServer } from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test, { after, before } from 'node:test';
import pg from 'pg';
import EmbeddedPostgres from 'embedded-postgres';

const MIGRATION = join(__dirname, '..', '..', 'supabase', 'migrations', '005_sessions.sql');
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
  await setup.query(readFileSync(MIGRATION, 'utf8'));
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
