/**
 * BE0.4: the session SQL (migration 005) on a real Postgres (PGlite), as
 * service_role, through the same store the routes use.
 */
import assert from 'node:assert/strict';
import test, { before } from 'node:test';
import { asServiceRole, freshDatabase, insertUser, type PGlite } from './support/database.js';
import { pgliteRpc } from './support/pglite-rpc.js';
import { supabaseSessionStore, startSession, type SessionStore } from '../src/sessions/store.js';
import { check } from '../src/sessions/store.js';
import { hashRefreshToken, newRefreshToken, openGrace, REFRESH_GRACE_SECONDS, sealGrace, verifyAccessToken } from '../src/sessions/tokens.js';

const SECRET = 'test-only-not-a-key';
const T0 = Date.parse('2026-10-21T12:00:00.000Z');
const DAY = 24 * 60 * 60 * 1000;
const iso = (ms: number) => new Date(ms).toISOString();

let db: PGlite;
let store: SessionStore;
before(async () => {
  db = await freshDatabase();
  const raw = supabaseSessionStore(pgliteRpc(db));
  // Every call runs as the backend's own role.
  store = Object.fromEntries(Object.entries(raw).map(([k, fn]) => [k, (...a: unknown[]) => asServiceRole(db, () => (fn as (...x: unknown[]) => Promise<unknown>)(...a))])) as unknown as SessionStore;
});

/** Seeded randomness: each call gets the next distinct bytes, the same every run. */
let seed = 0;
const random = (n: number) => Buffer.alloc(n, ++seed % 256).fill(seed >> 8, 0, 1);

/** One refresh as the route will do it: a new refresh token, sealed for the grace window. */
async function rotate(oldPlain: string, nowMs: number) {
  const next = newRefreshToken(random);
  const result = await store.rotate({
    tokenHash: hashRefreshToken(oldPlain), newHash: next.hash, nowIso: iso(nowMs),
    refreshCiphertext: sealGrace(next.plain, SECRET, random),
  });
  return { result, next };
}

async function newSession(nowMs = T0) {
  const user = await insertUser(db);
  const s = await startSession(store, { userId: user, tokenVersion: 0 }, SECRET, nowMs, { random });
  return { user, ...s };
}

test('a new session stores only the hash, and its access token carries the user and version', async () => {
  const s = await newSession();
  const { rows } = await db.query<{ token_hash: string; n: number }>(`SELECT token_hash, (SELECT count(*)::int FROM refresh_tokens WHERE token_hash = $1) n FROM refresh_tokens WHERE user_id = $2`, [s.refreshToken, s.user]);
  assert.equal(rows.length, 1);
  assert.equal(rows[0]!.token_hash, hashRefreshToken(s.refreshToken));
  assert.equal(rows[0]!.n, 0, 'the plain token is never stored');
  assert.deepEqual(verifyAccessToken(s.accessToken, SECRET, T0), { userId: s.user, tokenVersion: 0 });
  assert.equal(await store.ownerOf(hashRefreshToken(s.refreshToken)), s.user);
});

test('refresh rotates and the old token stops working', async () => {
  const s = await newSession();
  const first = await rotate(s.refreshToken, T0 + 1000);
  assert.deepEqual(first.result, { outcome: 'rotated', userId: s.user });
  const again = await rotate(s.refreshToken, T0 + 1000 + (REFRESH_GRACE_SECONDS + 1) * 1000);
  assert.deepEqual(again.result, { outcome: 'revoked', reuse: true }, 'reuse is told apart, for the log');
  // ...and that reuse ended the whole family, successor included.
  assert.deepEqual((await rotate(first.next.plain, T0 + 2 * 60 * 1000)).result, { outcome: 'revoked' });
});

test('a retry with the just-rotated token within 30 seconds gets the same successor', async () => {
  const s = await newSession();
  const first = await rotate(s.refreshToken, T0 + 1000);
  const retry = await rotate(s.refreshToken, T0 + 1000 + 29 * 1000);
  assert.equal(retry.result.outcome, 'grace');
  if (retry.result.outcome !== 'grace') return;
  assert.equal(openGrace(retry.result.refreshCiphertext, SECRET), first.next.plain, 'the same successor refresh token');
  const { rows } = await db.query<{ cols: string[] }>(`SELECT array_agg(column_name::text) AS cols FROM information_schema.columns WHERE table_name = 'refresh_grace'`);
  assert.deepEqual(rows[0]!.cols.sort(), ['expires_at', 'refresh_ciphertext', 'token_hash'], 'no access token is ever stored');
  // The successor still works: the retry didn't burn the family.
  assert.equal((await rotate(first.next.plain, T0 + 60 * 1000)).result.outcome, 'rotated');
});

test('two refreshes at once for one family produce one successor', async () => {
  const s = await newSession();
  const [a, b] = await Promise.all([rotate(s.refreshToken, T0 + 1000), rotate(s.refreshToken, T0 + 1000)]);
  const outcomes = [a.result.outcome, b.result.outcome].sort();
  assert.deepEqual(outcomes, ['grace', 'rotated']);
  const { rows } = await db.query<{ n: number }>(`SELECT count(*)::int n FROM refresh_tokens WHERE user_id = $1`, [s.user]);
  assert.equal(rows[0]!.n, 2, 'the original and exactly one successor');
});

test('reuse after the grace window revokes the whole family', async () => {
  const s = await newSession();
  const first = await rotate(s.refreshToken, T0 + 1000);
  const second = await rotate(first.next.plain, T0 + DAY);
  assert.equal(second.result.outcome, 'rotated');
  // Someone replays the first token a day later.
  assert.deepEqual((await rotate(s.refreshToken, T0 + DAY + 1000)).result, { outcome: 'revoked', reuse: true });
  const { rows } = await db.query<{ live: number }>(`SELECT count(*) FILTER (WHERE revoked_at IS NULL)::int live FROM refresh_tokens WHERE user_id = $1`, [s.user]);
  assert.equal(rows[0]!.live, 0);
  assert.deepEqual((await rotate(second.next.plain, T0 + DAY + 2000)).result, { outcome: 'revoked' });
});

test('the absolute cap ends a session even when it is used daily', async () => {
  const s = await newSession();
  let plain = s.refreshToken;
  for (let d = 1; d < 180; d++) {
    const r = await rotate(plain, T0 + d * DAY);
    assert.equal(r.result.outcome, 'rotated', `day ${d}`);
    plain = r.next.plain;
  }
  assert.deepEqual((await rotate(plain, T0 + 180 * DAY + 1000)).result, { outcome: 'revoked' }, 'day 180: over');
});

test('an unused session ends after 60 days', async () => {
  const s = await newSession();
  assert.deepEqual((await rotate(s.refreshToken, T0 + 60 * DAY + 1000)).result, { outcome: 'revoked' });
});

test('an unknown token is revoked, not an error', async () => {
  assert.deepEqual((await rotate(newRefreshToken(random).plain, T0)).result, { outcome: 'revoked' });
  assert.equal(await store.ownerOf(hashRefreshToken('not-a-token')), null);
});

test('signout revokes this device only', async () => {
  const user = await insertUser(db);
  const phone = await startSession(store, { userId: user, tokenVersion: 0 }, SECRET, T0);
  const ipad = await startSession(store, { userId: user, tokenVersion: 0 }, SECRET, T0);
  assert.equal(await store.revoke(hashRefreshToken(phone.refreshToken), iso(T0 + 1000)), true);
  assert.equal((await rotate(phone.refreshToken, T0 + 2000)).result.outcome, 'revoked');
  assert.equal((await rotate(ipad.refreshToken, T0 + 2000)).result.outcome, 'rotated', 'the other device stays signed in');
  assert.equal(await store.revoke(hashRefreshToken(phone.refreshToken), iso(T0 + 3000)), false, 'signing out twice is harmless');
});

test("one user's sign-out never touches another user's session", async () => {
  const alice = await newSession(), bob = await newSession();
  await store.revoke(hashRefreshToken(alice.refreshToken), iso(T0 + 1000));
  assert.equal((await rotate(bob.refreshToken, T0 + 2000)).result.outcome, 'rotated');
});

test('a nonce can be used once while it lives', async () => {
  const nonce = hashRefreshToken('a-nonce');
  assert.equal(await store.useNonce(nonce, iso(T0)), true);
  assert.equal(await store.useNonce(nonce, iso(T0 + 1000)), false);
  assert.equal(await store.useNonce(hashRefreshToken('another-nonce'), iso(T0 + 1000)), true);
});

test('the session tables are closed to everyone but the service role', async () => {
  for (const role of ['anon', 'authenticated']) {
    await db.exec(`SET ROLE ${role}`);
    try {
      await assert.rejects(db.query('SELECT 1 FROM refresh_tokens LIMIT 1'), /permission denied/);
      await assert.rejects(db.query(`SELECT use_nonce('x', now())`), /permission denied/);
    } finally {
      await db.exec('RESET ROLE');
    }
  }
});

test('a database error surfaces as the function and code only, never the message', () => {
  assert.throws(
    () => check('rotate_refresh_token', { data: null, error: { code: '40001', message: 'could not serialize access; row (hash-0, ...)' } as { code: string } }),
    (e: unknown) => e instanceof Error && e.message === 'rotate_refresh_token failed (40001)',
  );
  assert.throws(() => check('use_nonce', { data: null, error: {} }), /use_nonce failed \(unknown\)/);
});
