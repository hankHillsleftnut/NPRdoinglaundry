/**
 * BE0.4c over HTTP: POST /v2/auth/apple on the real app, with a fake Apple
 * verifier (no network) and sessions on a real Postgres (PGlite, migration 005).
 */
import assert from 'node:assert/strict';
import test, { before } from 'node:test';
import { asServiceRole, freshDatabase, insertUser, type PGlite } from './support/database.js';
import { pgliteRpc } from './support/pglite-rpc.js';
import { AuthResponse } from '../src/sessions/routes.js';
import { startHarness, type Harness } from './support/harness.js';
import { supabaseSessionStore, type SessionStore } from '../src/sessions/store.js';
import { hashNonce } from '../src/sessions/tokens.js';
import type { AppleSignIn } from '../src/services/apple-auth.js';
import { generateKeyPairSync, randomBytes } from 'node:crypto';
import { pgliteQuery } from './support/pglite-query.js';
import {
  APPLE_TOKEN_URL, createAppleTokenKeeper, openAppleToken, type AppleFetch, type AppleTokenDb, type KeepAppleToken,
} from '../src/services/apple-tokens.js';

let db: PGlite;
let store: SessionStore;
before(async () => {
  db = await freshDatabase();
  const raw = supabaseSessionStore(pgliteRpc(db));
  store = Object.fromEntries(Object.entries(raw).map(([k, fn]) => [k, (...a: unknown[]) => asServiceRole(db, () => (fn as (...x: unknown[]) => Promise<unknown>)(...a))])) as unknown as SessionStore;
});

/** Apple, faked: a token is `token:<sub>:<nonce claim>`; special tokens fail the way jose does. */
const fakeApple = async (token: string): Promise<AppleSignIn> => {
  if (token === 'expired') throw Object.assign(new Error('"exp" claim timestamp check failed'), { code: 'ERR_JWT_EXPIRED' });
  if (token === 'apple-down') throw new Error('fetch failed');
  const [, sub, nonce] = token.split(':');
  return { appleUserId: sub!, ...(nonce ? { nonce } : {}), email: `${sub}@privaterelay.example` };
};

let nonceSeq = 0;
const rawNonce = () => `raw-nonce-${String(++nonceSeq).padStart(8, '0')}`;
const tokenFor = (sub: string, raw: string) => `token:${sub}:${hashNonce(raw)}`;

async function harness(extra: { keepAppleToken?: KeepAppleToken } = {}): Promise<{ h: Harness; profiles: Map<string, { email?: string; firstName?: string }> }> {
  const bySub = new Map<string, string>();
  const profiles = new Map<string, { email?: string; firstName?: string }>();
  // The account store adds each new person to the harness's user table, so it needs the harness.
  const ref: { h?: Harness } = {};
  const h = await startHarness({
    sessions: store,
    verifyApple: fakeApple,
    accounts: {
      async findOrCreateApple(sub, profile) {
        const existing = bySub.get(sub);
        if (existing) return { userId: existing, isNew: false };
        const id = await insertUser(db, sub);
        bySub.set(sub, id);
        profiles.set(id, profile);
        ref.h!.users.set(id, { id, appleUserId: sub, tokenVersion: 0, ...(profile.firstName ? { firstName: profile.firstName } : {}) });
        return { userId: id, isNew: true };
      },
    },
    ...extra,
  });
  ref.h = h;
  return { h, profiles };
}

const signIn = (h: Harness, body: Record<string, unknown>) => h.request('POST', '/v2/auth/apple', body);
const code = (body: unknown) => (body as { error?: { code?: string } }).error?.code;
type SignedIn = { accessToken: string; refreshToken: string; accessTokenExpiresAt: string; user: { id: string; firstName: string | null; isNew: boolean }; access: { state: string } };
const data = (body: unknown) => (body as { data: SignedIn }).data;

test('a first sign-in creates the account with the name Apple sends once, and the session works', async () => {
  const { h, profiles } = await harness();
  try {
    const raw = rawNonce();
    const res = await signIn(h, { identityToken: tokenFor('sub-new', raw), authorizationCode: 'code', rawNonce: raw, fullName: { givenName: 'Sam', familyName: null } });
    assert.equal(res.status, 200);
    const d = data(res.body);
    assert.deepEqual(d.user, { id: d.user.id, firstName: 'Sam', isNew: true });
    assert.deepEqual(d.access, { state: 'member' });
    assert.equal(AuthResponse.safeParse(d).success, true, 'the answer matches the contract');
    assert.equal(new Date(d.accessTokenExpiresAt).getTime(), h.clock.now + 15 * 60 * 1000);
    assert.deepEqual(profiles.get(d.user.id), { email: 'sub-new@privaterelay.example', firstName: 'Sam' });
    assert.equal((await h.request('GET', '/v2/ping', undefined, { Authorization: `Bearer ${d.accessToken}` })).status, 200);
    assert.equal((await h.request('POST', '/v2/auth/refresh', { refreshToken: d.refreshToken })).status, 200);
  } finally {
    await h.close();
  }
});

test('signing in again finds the same account and never renames it', async () => {
  const { h } = await harness();
  try {
    const r1 = rawNonce(), r2 = rawNonce();
    const first = data((await signIn(h, { identityToken: tokenFor('sub-again', r1), authorizationCode: 'c', rawNonce: r1, fullName: { givenName: 'Sam' } })).body);
    const second = data((await signIn(h, { identityToken: tokenFor('sub-again', r2), authorizationCode: 'c', rawNonce: r2, fullName: { givenName: 'Someone Else' } })).body);
    assert.equal(second.user.id, first.user.id);
    assert.equal(second.user.isNew, false);
    assert.equal(second.user.firstName, 'Sam');
    assert.notEqual(second.refreshToken, first.refreshToken, 'a new device session each time');
  } finally {
    await h.close();
  }
});

test('two people get two accounts', async () => {
  const { h } = await harness();
  try {
    const ra = rawNonce(), rb = rawNonce();
    const a = data((await signIn(h, { identityToken: tokenFor('sub-a', ra), authorizationCode: 'c', rawNonce: ra })).body);
    const b = data((await signIn(h, { identityToken: tokenFor('sub-b', rb), authorizationCode: 'c', rawNonce: rb })).body);
    assert.notEqual(a.user.id, b.user.id);
  } finally {
    await h.close();
  }
});

test('a token without the right nonce is refused', async () => {
  const { h } = await harness();
  try {
    const raw = rawNonce();
    const wrong = await signIn(h, { identityToken: tokenFor('sub-n', raw), authorizationCode: 'c', rawNonce: rawNonce() });
    assert.equal(wrong.status, 401);
    assert.equal(code(wrong.body), 'invalid_credentials');
    const none = await signIn(h, { identityToken: 'token:sub-n', authorizationCode: 'c', rawNonce: raw });
    assert.equal(code(none.body), 'invalid_credentials');
  } finally {
    await h.close();
  }
});

test('a nonce can be used once', async () => {
  const { h } = await harness();
  try {
    const raw = rawNonce();
    const body = { identityToken: tokenFor('sub-replay', raw), authorizationCode: 'c', rawNonce: raw };
    assert.equal((await signIn(h, body)).status, 200);
    const replay = await signIn(h, body);
    assert.equal(replay.status, 401);
    assert.equal(code(replay.body), 'invalid_credentials');
  } finally {
    await h.close();
  }
});

test('a bad Apple token is invalid_credentials; failing to reach Apple is internal', async () => {
  const { h } = await harness();
  try {
    const raw = rawNonce();
    const expired = await signIn(h, { identityToken: 'expired', authorizationCode: 'c', rawNonce: raw });
    assert.equal(expired.status, 401);
    assert.equal(code(expired.body), 'invalid_credentials');
    const down = await signIn(h, { identityToken: 'apple-down', authorizationCode: 'c', rawNonce: raw });
    assert.equal(down.status, 500);
    assert.equal(code(down.body), 'internal');
  } finally {
    await h.close();
  }
});

test('a malformed sign-in is invalid_request', async () => {
  const { h } = await harness();
  try {
    const raw = rawNonce();
    const good = { identityToken: tokenFor('sub-bad', raw), authorizationCode: 'c', rawNonce: raw };
    for (const bad of [
      { ...good, authorizationCode: undefined },
      { ...good, rawNonce: 'short' },
      { ...good, userId: 'someone-else' },
      { ...good, identityToken: 'x'.repeat(8193) },
    ]) {
      const res = await signIn(h, JSON.parse(JSON.stringify(bad)) as Record<string, unknown>);
      assert.equal(res.status, 400, JSON.stringify(Object.keys(bad)));
      assert.equal(code(res.body), 'invalid_request');
    }
  } finally {
    await h.close();
  }
});

test('an odd optional name or email never blocks a sign-in', async () => {
  const { h, profiles } = await harness();
  try {
    for (const [i, extra] of [
      { email: 'not-an-email' },
      { fullName: { givenName: 'Sam', middleName: 'J', nickname: 'S' } },
      { fullName: { givenName: 'x'.repeat(101) } },
      { fullName: 'Sam' },
    ].entries()) {
      const raw = rawNonce();
      const res = await signIn(h, { identityToken: tokenFor(`sub-odd-${i}`, raw), authorizationCode: 'c', rawNonce: raw, ...extra });
      assert.equal(res.status, 200, JSON.stringify(extra));
    }
    const names = [...profiles.values()].map((p) => p.firstName);
    assert.deepEqual(names, [undefined, 'Sam', undefined, undefined], 'unknown name parts dropped; a name that does not fit is no name');
  } finally {
    await h.close();
  }
});

test("only Apple's verified email is stored, never the copy the app sends", async () => {
  const { h, profiles } = await harness();
  try {
    const raw = rawNonce();
    const res = await signIn(h, { identityToken: tokenFor('sub-mail', raw), authorizationCode: 'c', rawNonce: raw, email: 'someone.else@example.com' });
    const { user } = (res.body as { data: { user: { id: string } } }).data;
    assert.equal(profiles.get(user.id)?.email, 'sub-mail@privaterelay.example');
  } finally {
    await h.close();
  }
});

test('sign-in is limited per address', async () => {
  const { h } = await harness();
  try {
    for (let i = 0; i < 30; i++) await signIn(h, {});
    const res = await signIn(h, {});
    assert.equal(res.status, 429);
    assert.equal(code(res.body), 'rate_limited');
  } finally {
    await h.close();
  }
});

test('the sign-in log carries no token, nonce or email', async () => {
  const { h } = await harness();
  try {
    const raw = rawNonce();
    const d = data((await signIn(h, { identityToken: tokenFor('sub-log', raw), authorizationCode: 'c', rawNonce: raw })).body);
    const all = h.logLines.join('\n');
    for (const secret of [raw, hashNonce(raw), d.accessToken, d.refreshToken, 'privaterelay', 'sub-log']) assert.equal(all.includes(secret), false, secret);
    const line = JSON.parse(h.logLines.find((l) => l.includes('auth.apple'))!) as Record<string, unknown>;
    assert.equal(line.userId, d.user.id);
  } finally {
    await h.close();
  }
});

// ---- BE0.5: Apple's refresh token is kept at sign-in (flag on), behind a fake Apple.

const sealing = randomBytes(32);
const appleSettings = {
  clientId: 'com.example.test-app', teamId: 'TEAMTEST01', keyId: 'KIDTEST001',
  privateKey: generateKeyPairSync('ec', { namedCurve: 'P-256' }).privateKey.export({ type: 'pkcs8', format: 'pem' }).toString(),
  revokeEnabled: true, tokenEncryptionKey: sealing.toString('base64'),
};
const idTokenFor = (sub: string) =>
  [{ alg: 'none' }, { sub }].map((p) => Buffer.from(JSON.stringify(p)).toString('base64url')).join('.') + '.sig';

/** The users table on PGlite (migration 027's columns), written as service_role like production. */
const usersAsService = (): AppleTokenDb => {
  const q = pgliteQuery(db);
  return {
    from: (table) => ({
      update: (values) => ({
        eq: (column, value) => ({
          select: (cols) => ({ maybeSingle: () => asServiceRole(db, async () => q.from(table).update(values).eq(column, value).select(cols).maybeSingle()) }),
        }),
      }),
    }),
  };
};

/** Apple's token endpoint, faked: `reply` decides per call; every call is recorded. */
function fakeAppleTokens(reply: (fields: Record<string, string>) => { status: number; body?: unknown } | Error) {
  const calls: Record<string, string>[] = [];
  const fetch: AppleFetch = async (url, init) => {
    assert.equal(url, APPLE_TOKEN_URL);
    const fields = Object.fromEntries(new URLSearchParams(init.body));
    calls.push(fields);
    const r = reply(fields);
    if (r instanceof Error) throw r;
    return { ok: r.status >= 200 && r.status < 300, status: r.status, json: async () => r.body };
  };
  return { fetch, calls };
}

async function storedFor(userId: string): Promise<{ ciphertext: string | null; at: string | null }> {
  const { rows } = await db.query<{ c: string | null; at: Date | null }>(
    'SELECT apple_refresh_token_ciphertext AS c, apple_refresh_token_at AS at FROM users WHERE id = $1', [userId]);
  return { ciphertext: rows[0]!.c, at: rows[0]!.at ? rows[0]!.at.toISOString() : null };
}

const lineFor = (h: Harness) => JSON.parse(h.logLines.filter((l) => l.includes('auth.apple')).at(-1)!) as Record<string, unknown>;

test('with the flag on, sign-in exchanges the code and keeps the refresh token sealed on the user', async () => {
  const apple = fakeAppleTokens((f) => ({ status: 200, body: { refresh_token: `r.for-${f.code}`, access_token: 'a.x', id_token: idTokenFor('sub-keep') } }));
  const { h } = await harness({ keepAppleToken: createAppleTokenKeeper({ settings: appleSettings, db: usersAsService(), fetch: apple.fetch, now: () => h.clock.now })! });
  try {
    const raw = rawNonce();
    const res = await signIn(h, { identityToken: tokenFor('sub-keep', raw), authorizationCode: 'code-keep-1', rawNonce: raw });
    assert.equal(res.status, 200);
    assert.equal(apple.calls.length, 1);
    assert.equal(apple.calls[0]!.code, 'code-keep-1');
    assert.equal(apple.calls[0]!.grant_type, 'authorization_code');
    const stored = await storedFor(data(res.body).user.id);
    assert.ok(stored.ciphertext?.startsWith('v1:'));
    assert.equal(stored.ciphertext!.includes('r.for-code-keep-1'), false, 'never stored in the clear');
    assert.equal(openAppleToken(stored.ciphertext!, sealing), 'r.for-code-keep-1');
    assert.equal(stored.at, new Date(h.clock.now).toISOString());
    assert.equal(lineFor(h).failures, undefined, 'no failure counted');
  } finally {
    await h.close();
  }
});

test("a failed code exchange doesn't fail sign-in", async () => {
  const outcomes = [new Error('fetch failed'), { status: 400, body: { error: 'invalid_grant' } }, { status: 500 }, { status: 200, body: { access_token: 'a.only' } }];
  let i = 0;
  const apple = fakeAppleTokens(() => outcomes[i++]!);
  const { h } = await harness({ keepAppleToken: createAppleTokenKeeper({ settings: appleSettings, db: usersAsService(), fetch: apple.fetch, now: () => h.clock.now })! });
  try {
    for (let n = 0; n < outcomes.length; n++) {
      const raw = rawNonce();
      const res = await signIn(h, { identityToken: tokenFor(`sub-fail-${n}`, raw), authorizationCode: `code-fail-${n}`, rawNonce: raw });
      assert.equal(res.status, 200, `outcome ${n}`);
      assert.equal(AuthResponse.safeParse(data(res.body)).success, true);
      assert.equal((await storedFor(data(res.body).user.id)).ciphertext, null, 'nothing stored');
      assert.equal(lineFor(h).failures, 1, 'counted, nothing more');
    }
    // Even a keeper that throws (a bug) never reaches the person.
    const { h: h2 } = await harness({ keepAppleToken: () => { throw new Error('boom'); } });
    try {
      const raw = rawNonce();
      const res = await signIn(h2, { identityToken: tokenFor('sub-fail-throw', raw), authorizationCode: 'c', rawNonce: raw });
      assert.equal(res.status, 200);
      assert.equal(lineFor(h2).failures, 1);
    } finally {
      await h2.close();
    }
  } finally {
    await h.close();
  }
});

test('with the flag off nothing calls Apple at sign-in', async () => {
  // The default app (APPLE_REVOKE_ENABLED unset in tests): no keeper is built.
  const realFetch = globalThis.fetch;
  const urls: string[] = [];
  globalThis.fetch = ((input: Parameters<typeof fetch>[0], init?: Parameters<typeof fetch>[1]) => {
    urls.push(typeof input === 'string' ? input : input instanceof URL ? input.href : input.url);
    return realFetch(input, init);
  }) as typeof fetch;
  const { h } = await harness();
  try {
    const raw = rawNonce();
    const res = await signIn(h, { identityToken: tokenFor('sub-off', raw), authorizationCode: 'code-off', rawNonce: raw });
    assert.equal(res.status, 200);
    assert.equal(urls.some((u) => u.includes('appleid.apple.com')), false);
    assert.equal((await storedFor(data(res.body).user.id)).ciphertext, null);
    assert.equal(lineFor(h).failures, undefined);
  } finally {
    globalThis.fetch = realFetch;
    await h.close();
  }
});

test('no log line carries the code or a token', async () => {
  const printed: string[] = [];
  const saved = { log: console.log, error: console.error, warn: console.warn, info: console.info };
  for (const k of ['log', 'error', 'warn', 'info'] as const) console[k] = (...a: unknown[]) => { printed.push(a.map(String).join(' ')); };
  const apple = fakeAppleTokens(() => ({ status: 200, body: { refresh_token: 'r.secret-refresh-value', access_token: 'a.secret-access-value', id_token: idTokenFor('sub-quiet') } }));
  const refusing = fakeAppleTokens(() => ({ status: 400, body: { error: 'invalid_grant', echo: 'code-secret-2' } }));
  const { h } = await harness({ keepAppleToken: createAppleTokenKeeper({ settings: appleSettings, db: usersAsService(), fetch: apple.fetch, now: () => h.clock.now })! });
  const { h: h2 } = await harness({ keepAppleToken: createAppleTokenKeeper({ settings: appleSettings, db: usersAsService(), fetch: refusing.fetch, now: () => h2.clock.now })! });
  try {
    const r1 = rawNonce(), r2 = rawNonce();
    const ok = await signIn(h, { identityToken: tokenFor('sub-quiet', r1), authorizationCode: 'code-secret-1', rawNonce: r1 });
    const failed = await signIn(h2, { identityToken: tokenFor('sub-quiet-2', r2), authorizationCode: 'code-secret-2', rawNonce: r2 });
    assert.equal(ok.status, 200);
    assert.equal(failed.status, 200);
    const stored = (await storedFor(data(ok.body).user.id)).ciphertext!;
    const clientSecret = apple.calls[0]!.client_secret!;
    const everything = [...h.logLines, ...h2.logLines, ...printed, JSON.stringify(ok.body), JSON.stringify(failed.body)].join('\n');
    for (const secret of ['code-secret-1', 'code-secret-2', 'secret-refresh-value', 'secret-access-value', stored, clientSecret]) {
      assert.equal(everything.includes(secret), false, 'a code, token, ciphertext or client secret leaked');
    }
  } finally {
    Object.assign(console, saved);
    await h.close();
    await h2.close();
  }
});
