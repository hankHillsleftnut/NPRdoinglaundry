/**
 * BE0.4b over HTTP: the real app (harness), with sessions on a real Postgres
 * (PGlite, migration 005) so rotation, grace and revocation are the SQL's.
 */
import assert from 'node:assert/strict';
import test, { before } from 'node:test';
import { asServiceRole, freshDatabase, insertUser, type PGlite } from './support/database.js';
import { pgliteRpc } from './support/pglite-rpc.js';
import { startHarness, type Harness } from './support/harness.js';
import { startSession, supabaseSessionStore, type SessionStore } from '../src/sessions/store.js';

const SECRET = process.env.JWT_SECRET ?? '';
const DAY = 24 * 60 * 60 * 1000;
let db: PGlite;
let store: SessionStore;

before(async () => {
  db = await freshDatabase();
  const raw = supabaseSessionStore(pgliteRpc(db));
  store = Object.fromEntries(Object.entries(raw).map(([k, fn]) => [k, (...a: unknown[]) => asServiceRole(db, () => (fn as (...x: unknown[]) => Promise<unknown>)(...a))])) as unknown as SessionStore;
});

type Pair = { accessToken: string; refreshToken: string; accessTokenExpiresAt: string };

/** A harness and one signed-in person (a row in Postgres and in the harness's user table). */
async function signedIn(): Promise<{ h: Harness; userId: string; first: Pair }> {
  const h = await startHarness({ sessions: store });
  const userId = await insertUser(db);
  h.users.set(userId, { id: userId, appleUserId: `apple-${userId}`, tokenVersion: 0, firstName: 'Test' });
  const first = await startSession(store, { userId, tokenVersion: 0 }, SECRET, h.clock.now);
  return { h, userId, first };
}

const refresh = (h: Harness, refreshToken: unknown) => h.request('POST', '/v2/auth/refresh', { refreshToken });
const code = (body: unknown) => (body as { error?: { code?: string } }).error?.code;
const data = (body: unknown) => (body as { data: Pair & { user: unknown; access: unknown } }).data;

test('refresh rotates and the old token stops working', async () => {
  const { h, userId, first } = await signedIn();
  try {
    const res = await refresh(h, first.refreshToken);
    assert.equal(res.status, 200);
    const next = data(res.body);
    assert.notEqual(next.refreshToken, first.refreshToken);
    assert.deepEqual(next.user, { id: userId, firstName: 'Test', isNew: false });
    assert.deepEqual(next.access, { state: 'member' });
    const ping = await h.request('GET', '/v2/ping', undefined, { Authorization: `Bearer ${next.accessToken}` });
    assert.equal(ping.status, 200, 'the new access token works');

    h.clock.now += 31_000;
    const old = await refresh(h, first.refreshToken);
    assert.equal(old.status, 401);
    assert.equal(code(old.body), 'session_revoked');
  } finally {
    await h.close();
  }
});

test('a retry with the just-rotated token within 30 seconds gets the same successor', async () => {
  const { h, first } = await signedIn();
  try {
    const a = data((await refresh(h, first.refreshToken)).body);
    h.clock.now += 20_000;
    const b = data((await refresh(h, first.refreshToken)).body);
    assert.equal(b.refreshToken, a.refreshToken);
    assert.equal(b.accessToken, a.accessToken);
    assert.equal((await refresh(h, a.refreshToken)).status, 200, 'and the successor still works');
  } finally {
    await h.close();
  }
});

test('two refreshes at once for one family produce one successor', async () => {
  const { h, userId, first } = await signedIn();
  try {
    const [x, y] = await Promise.all([refresh(h, first.refreshToken), refresh(h, first.refreshToken)]);
    assert.deepEqual([x.status, y.status], [200, 200]);
    assert.equal(data(x.body).refreshToken, data(y.body).refreshToken);
    const { rows } = await db.query<{ n: number }>(`SELECT count(*)::int n FROM refresh_tokens WHERE user_id = $1`, [userId]);
    assert.equal(rows[0]!.n, 2);
  } finally {
    await h.close();
  }
});

test('reuse after the grace window revokes the whole family', async () => {
  const { h, first } = await signedIn();
  try {
    const second = data((await refresh(h, first.refreshToken)).body);
    h.clock.now += DAY;
    assert.equal(code((await refresh(h, first.refreshToken)).body), 'session_revoked');
    assert.equal(code((await refresh(h, second.refreshToken)).body), 'session_revoked', 'the thief and the owner are both out');
  } finally {
    await h.close();
  }
});

test('an unknown, empty or oversized refresh token is refused without a lookup error', async () => {
  const { h } = await signedIn();
  try {
    assert.equal(code((await refresh(h, 'not-a-real-token')).body), 'session_revoked');
    assert.equal(code((await refresh(h, '')).body), 'invalid_request');
    assert.equal(code((await refresh(h, 'x'.repeat(129))).body), 'invalid_request');
    assert.equal(code((await refresh(h, 42)).body), 'invalid_request');
    assert.equal(code((await h.request('POST', '/v2/auth/refresh', { refreshToken: 'a', userId: 'x' })).body), 'invalid_request');
  } finally {
    await h.close();
  }
});

test('refresh is limited per address', async () => {
  const { h } = await signedIn();
  try {
    for (let i = 0; i < 30; i++) await refresh(h, `unknown-${i}`);
    const res = await refresh(h, 'unknown-31');
    assert.equal(res.status, 429);
    assert.equal(code(res.body), 'rate_limited');
  } finally {
    await h.close();
  }
});

test('signout revokes this device only', async () => {
  const { h, userId, first } = await signedIn();
  try {
    const ipad = await startSession(store, { userId, tokenVersion: 0 }, SECRET, h.clock.now);
    const out = await h.request('POST', '/v2/auth/signout', { refreshToken: first.refreshToken }, { Authorization: `Bearer ${first.accessToken}` });
    assert.deepEqual(out.body, { success: true, data: { signedOut: true } });
    assert.equal(code((await refresh(h, first.refreshToken)).body), 'session_revoked');
    assert.equal((await refresh(h, ipad.refreshToken)).status, 200, 'the other device stays signed in');
    const again = await h.request('POST', '/v2/auth/signout', { refreshToken: first.refreshToken }, { Authorization: `Bearer ${first.accessToken}` });
    assert.equal(again.status, 200, 'signing out twice is still signed out');
  } finally {
    await h.close();
  }
});

test("signout can't end another person's session, and needs a signed-in user", async () => {
  const alice = await signedIn();
  try {
    const bobId = await insertUser(db);
    const bob = await startSession(store, { userId: bobId, tokenVersion: 0 }, SECRET, alice.h.clock.now);
    alice.h.users.set(bobId, { id: bobId, appleUserId: 'apple-bob', tokenVersion: 0 });
    const res = await alice.h.request('POST', '/v2/auth/signout', { refreshToken: bob.refreshToken }, { Authorization: `Bearer ${alice.first.accessToken}` });
    assert.equal(res.status, 404);
    assert.equal(code(res.body), 'not_found');
    assert.equal((await refresh(alice.h, bob.refreshToken)).status, 200, "Bob is still signed in");
    const anon = await alice.h.request('POST', '/v2/auth/signout', { refreshToken: alice.first.refreshToken });
    assert.equal(anon.status, 401);
  } finally {
    await alice.h.close();
  }
});

test('the session log carries no token', async () => {
  const { h, first } = await signedIn();
  try {
    const next = data((await refresh(h, first.refreshToken)).body);
    const all = h.logLines.join('\n');
    for (const secret of [first.refreshToken, next.refreshToken, next.accessToken]) assert.equal(all.includes(secret), false);
    const line = JSON.parse(h.logLines.find((l) => l.includes('auth.refresh'))!) as Record<string, unknown>;
    assert.deepEqual(Object.keys(line).sort(), ['door', 'ms', 'status', 'userId']);
    assert.equal(line.userId, null);
  } finally {
    await h.close();
  }
});

test('a database failure during refresh is internal, never a sign-out', async () => {
  const broken: SessionStore = { ...store, ownerOf: async () => { throw new Error('refresh_tokens lookup failed (08006)'); } };
  const h = await startHarness({ sessions: broken });
  try {
    const res = await refresh(h, 'some-token');
    assert.equal(res.status, 500);
    assert.equal(code(res.body), 'internal', 'not session_revoked: the app would sign the person out');
  } finally {
    await h.close();
  }
});
