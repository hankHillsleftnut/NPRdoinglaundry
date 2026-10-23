/**
 * BE0.5: Apple's tokens (services/apple-tokens.ts). A fake Apple (an injected
 * fetch) and a throwaway P-256 key made here, so nothing reaches Apple and no
 * real key is involved.
 */
import assert from 'node:assert/strict';
import test from 'node:test';
import { generateKeyPairSync, randomBytes } from 'node:crypto';
import { decodeProtectedHeader, jwtVerify } from 'jose';
import {
  APPLE_REVOKE_URL, APPLE_TOKEN_URL, CLIENT_SECRET_TTL_SECONDS, checkAppleTokenSettings, createAppleTokenKeeper, createAppleTokens,
  encryptionKeyOf, openAppleToken, sealAppleToken, type AppleFetch, type AppleTokenDb, type AppleTokenSettings,
} from '../src/services/apple-tokens.js';

const pair = generateKeyPairSync('ec', { namedCurve: 'P-256' });
const throwawayPem = pair.privateKey.export({ type: 'pkcs8', format: 'pem' }).toString();
const sealing = randomBytes(32);

const settings = (over: Partial<AppleTokenSettings> = {}): AppleTokenSettings => ({
  clientId: 'com.example.test-app',
  teamId: 'TEAMTEST01',
  keyId: 'KIDTEST001',
  privateKey: throwawayPem,
  revokeEnabled: true,
  tokenEncryptionKey: sealing.toString('base64'),
  ...over,
});

const NOW = 1_800_000_000_000;

/** An id_token as Apple's token endpoint returns one; only its payload is read. */
const idTokenFor = (sub: string) =>
  [{ alg: 'none' }, { iss: 'https://appleid.apple.com', sub }].map((p) => Buffer.from(JSON.stringify(p)).toString('base64url')).join('.') + '.sig';

type Call = { url: string; fields: Record<string, string> };
function fakeApple(reply: (url: string) => { status: number; body?: unknown } | Error = () => ({ status: 200, body: {} })) {
  const calls: Call[] = [];
  const fetch: AppleFetch = async (url, init) => {
    calls.push({ url, fields: Object.fromEntries(new URLSearchParams(init.body)) });
    const r = reply(url);
    if (r instanceof Error) throw r;
    return { ok: r.status >= 200 && r.status < 300, status: r.status, json: async () => r.body };
  };
  return { fetch, calls };
}

test('the client secret is a valid ES256 JWT with the right claims', async () => {
  const apple = createAppleTokens({ settings: settings(), now: () => NOW });
  const secret = await apple.clientSecret();
  const header = decodeProtectedHeader(secret);
  assert.deepEqual(header, { alg: 'ES256', kid: 'KIDTEST001' });
  const { payload } = await jwtVerify(secret, pair.publicKey, {
    algorithms: ['ES256'], issuer: 'TEAMTEST01', subject: 'com.example.test-app', audience: 'https://appleid.apple.com', currentDate: new Date(NOW),
  });
  assert.equal(payload.iat, NOW / 1000);
  assert.equal(payload.exp! - payload.iat!, CLIENT_SECRET_TTL_SECONDS);
  assert.ok(CLIENT_SECRET_TTL_SECONDS <= 180 * 24 * 3600, 'within six months');
});

test('the client secret is cached and re-minted a day before it runs out', async () => {
  const clock = { now: NOW };
  const apple = createAppleTokens({ settings: settings(), now: () => clock.now });
  const first = await apple.clientSecret();
  clock.now += 10 * 24 * 3600 * 1000;
  assert.equal(await apple.clientSecret(), first, 'still cached after ten days');
  clock.now = NOW + (CLIENT_SECRET_TTL_SECONDS - 24 * 3600) * 1000;
  const second = await apple.clientSecret();
  assert.notEqual(second, first, 're-minted inside the last day');
});

test('a one-line env value with \\n escapes is read as the PEM', async () => {
  const apple = createAppleTokens({ settings: settings({ privateKey: throwawayPem.replace(/\n/g, '\\n') }), now: () => NOW });
  await jwtVerify(await apple.clientSecret(), pair.publicKey, { currentDate: new Date(NOW) });
});

test('tokens are encrypted at rest and decrypt to the same value; two seals differ', () => {
  const plain = 'r.apple-refresh-placeholder';
  const a = sealAppleToken(plain, sealing);
  const b = sealAppleToken(plain, sealing);
  assert.match(a, /^v1:[A-Za-z0-9_-]+:[A-Za-z0-9_-]+:[A-Za-z0-9_-]+$/);
  assert.notEqual(a, b, 'a fresh IV each time');
  assert.equal(a.includes(plain), false);
  assert.equal(openAppleToken(a, sealing), plain);
  assert.equal(openAppleToken(b, sealing), plain);
  assert.throws(() => openAppleToken(a, randomBytes(32)), 'another key cannot open it');
  const [v, iv, tag, body] = a.split(':');
  const flipped = Buffer.from(body!, 'base64url');
  flipped[0] = flipped[0]! ^ 1;
  assert.throws(() => openAppleToken([v, iv, tag, flipped.toString('base64url')].join(':'), sealing), 'a tampered value is refused');
  assert.throws(() => openAppleToken(a.replace(/^v1/, 'v2'), sealing), 'an unknown version is refused');
});

test('the encryption setting must be 32 bytes of base64', () => {
  assert.equal(encryptionKeyOf(sealing.toString('base64')).length, 32);
  for (const bad of [null, '', randomBytes(16).toString('base64'), 'not base64 at all']) assert.throws(() => encryptionKeyOf(bad), /TOKEN_ENCRYPTION_KEY/);
});

test('the code exchange posts grant_type=authorization_code with the client secret', async () => {
  const apple = fakeApple(() => ({ status: 200, body: { refresh_token: 'r.placeholder', access_token: 'a.placeholder', id_token: idTokenFor('sub-1') } }));
  const tokens = createAppleTokens({ settings: settings(), fetch: apple.fetch, now: () => NOW });
  const grant = await tokens.exchangeCode('code-placeholder');
  assert.deepEqual(grant, { refreshToken: 'r.placeholder', appleUserId: 'sub-1' });
  assert.equal(apple.calls.length, 1);
  assert.equal(apple.calls[0]!.url, APPLE_TOKEN_URL);
  const { client_secret: secret, ...rest } = apple.calls[0]!.fields;
  assert.deepEqual(rest, { client_id: 'com.example.test-app', code: 'code-placeholder', grant_type: 'authorization_code' });
  assert.equal(secret, await tokens.clientSecret());
});

test('a refused exchange throws with the status only, never the body', async () => {
  const apple = fakeApple(() => ({ status: 400, body: { error: 'invalid_grant', echo: 'code-placeholder' } }));
  const tokens = createAppleTokens({ settings: settings(), fetch: apple.fetch, now: () => NOW });
  await assert.rejects(tokens.exchangeCode('code-placeholder'), (err: Error) => {
    assert.equal(err.message, 'apple token: HTTP 400');
    return true;
  });
});

test('revoke posts token_type_hint=refresh_token', async () => {
  const apple = fakeApple();
  const tokens = createAppleTokens({ settings: settings(), fetch: apple.fetch, now: () => NOW });
  await tokens.revoke('r.placeholder', 'refresh_token');
  await tokens.revoke('a.placeholder', 'access_token');
  assert.deepEqual(apple.calls.map((c) => c.url), [APPLE_REVOKE_URL, APPLE_REVOKE_URL]);
  const { client_secret: secret, ...rest } = apple.calls[0]!.fields;
  assert.ok(secret);
  assert.deepEqual(rest, { client_id: 'com.example.test-app', token: 'r.placeholder', token_type_hint: 'refresh_token' });
  assert.equal(apple.calls[1]!.fields.token_type_hint, 'access_token');
  await assert.rejects(createAppleTokens({ settings: settings(), fetch: fakeApple(() => ({ status: 503 })).fetch, now: () => NOW }).revoke('r', 'refresh_token'), /HTTP 503/);
});

test('with the flag off nothing calls Apple', async () => {
  const apple = fakeApple();
  const off = settings({ revokeEnabled: false });
  const tokens = createAppleTokens({ settings: off, fetch: apple.fetch, now: () => NOW });
  await assert.rejects(tokens.exchangeCode('code'), /APPLE_REVOKE_ENABLED is off/);
  await assert.rejects(tokens.revoke('r', 'refresh_token'), /APPLE_REVOKE_ENABLED is off/);
  const db: AppleTokenDb = { from: () => { throw new Error('no write expected'); } };
  assert.equal(createAppleTokenKeeper({ settings: off, db, fetch: apple.fetch }), undefined, 'no keeper, so the sign-in door skips Apple');
  // Off needs nothing configured at all.
  assert.equal(createAppleTokenKeeper({ settings: settings({ revokeEnabled: false, privateKey: '', keyId: '', teamId: '', tokenEncryptionKey: null }), db }), undefined);
  assert.equal(apple.calls.length, 0);
});

test('with the flag on, a missing or unreadable key refuses to start', () => {
  checkAppleTokenSettings(settings());
  checkAppleTokenSettings(settings({ revokeEnabled: false, privateKey: '', tokenEncryptionKey: null }));
  assert.throws(() => checkAppleTokenSettings(settings({ privateKey: '' })), /APPLE_PRIVATE_KEY is not set/);
  assert.throws(() => checkAppleTokenSettings(settings({ teamId: '', keyId: '' })), /APPLE_TEAM_ID, APPLE_KEY_ID is not set/);
  assert.throws(() => checkAppleTokenSettings(settings({ tokenEncryptionKey: null })), /TOKEN_ENCRYPTION_KEY/);
  assert.throws(() => checkAppleTokenSettings(settings({ privateKey: 'not a pem' })), /APPLE_PRIVATE_KEY must be/);
  const rsa = generateKeyPairSync('rsa', { modulusLength: 2048 }).privateKey.export({ type: 'pkcs8', format: 'pem' }).toString();
  assert.throws(() => checkAppleTokenSettings(settings({ privateKey: rsa })), /EC P-256/);
  const db: AppleTokenDb = { from: () => { throw new Error('unused'); } };
  assert.throws(() => createAppleTokenKeeper({ settings: settings({ tokenEncryptionKey: null }), db }), /TOKEN_ENCRYPTION_KEY/);
});

/** A users table of one column pair, through the same builder calls supabase-js takes. */
function memoryUsers(ids: string[]) {
  const rows = new Map(ids.map((id) => [id, {} as Record<string, unknown>]));
  const db: AppleTokenDb = {
    from: (table) => ({
      update: (values) => ({
        eq: (column, value) => ({
          select: () => ({
            maybeSingle: async () => {
              assert.equal(table, 'users');
              assert.equal(column, 'id');
              const row = rows.get(value as string);
              if (!row) return { data: null, error: null };
              Object.assign(row, values);
              return { data: { id: value }, error: null };
            },
          }),
        }),
      }),
    }),
  };
  return { db, rows };
}

test('the keeper stores only a grant for the signed-in Apple subject', async () => {
  const { db, rows } = memoryUsers(['u1']);
  const replies: Record<string, unknown> = { right: { refresh_token: 'r.right', id_token: idTokenFor('sub-1') } };
  const apple = fakeApple(() => ({ status: 200, body: replies.next }));
  const keep = createAppleTokenKeeper({ settings: settings(), db, fetch: apple.fetch, now: () => NOW })!;

  replies.next = { refresh_token: 'r.other', id_token: idTokenFor('sub-someone-else') };
  assert.equal(await keep('u1', 'sub-1', 'c1'), false, 'a code for another Apple account');
  replies.next = { refresh_token: 'r.no-id' };
  assert.equal(await keep('u1', 'sub-1', 'c2'), false, 'a grant that does not say whose it is');
  replies.next = { access_token: 'a.only', id_token: idTokenFor('sub-1') };
  assert.equal(await keep('u1', 'sub-1', 'c3'), false, 'no refresh token');
  assert.deepEqual(rows.get('u1'), {}, 'nothing stored so far');

  replies.next = replies.right;
  assert.equal(await keep('u1', 'sub-1', 'c4'), true);
  const row = rows.get('u1')!;
  assert.equal(openAppleToken(row.apple_refresh_token_ciphertext as string, sealing), 'r.right');
  assert.equal(row.apple_refresh_token_at, new Date(NOW).toISOString());
  assert.equal(await keep('u-missing', 'sub-1', 'c5'), false, 'no such user row');
});

test('the keeper never throws: Apple down or refusing is just false', async () => {
  const { db } = memoryUsers(['u1']);
  for (const reply of [() => new Error('fetch failed'), () => ({ status: 400 }), () => ({ status: 200, body: 'not json' })]) {
    const keep = createAppleTokenKeeper({ settings: settings(), db, fetch: fakeApple(reply).fetch, now: () => NOW })!;
    assert.equal(await keep('u1', 'sub-1', 'c'), false);
  }
});
