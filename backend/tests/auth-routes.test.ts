import { test, type TestContext } from 'node:test';
import assert from 'node:assert/strict';
import type { Request, Response } from 'express';
import { SignJWT, generateKeyPair, exportJWK } from 'jose';

process.env.AGENT_SERVICE_URL ??= 'http://localhost';
process.env.ANTHROPIC_API_KEY ??= 'test';
process.env.INTERNAL_API_SECRET ??= 'test';
process.env.JWT_SECRET ??= 'test';
process.env.OPENAI_API_KEY ??= 'test';
process.env.SUPABASE_ANON_KEY ??= 'test';
process.env.SUPABASE_SERVICE_KEY ??= 'test';
process.env.SUPABASE_URL ??= 'http://localhost';
process.env.GOOGLE_OAUTH_CLIENT_ID ??= 'test-google-client';

const keyPair = generateKeyPair('RS256');

async function fixture(t: TestContext) {
  const { privateKey, publicKey } = await keyPair;
  const jwk = { ...(await exportJWK(publicKey)), kid: 'test-key', alg: 'RS256' };
  t.mock.method(globalThis, 'fetch', async (url: unknown) => {
    assert.match(String(url), /^https:\/\/(appleid\.apple\.com\/auth\/keys|www\.googleapis\.com\/oauth2\/v3\/certs)$/);
    return new Response(JSON.stringify({ keys: [jwk] }));
  });
  t.mock.method(console, 'error', () => {});
  const { authRouter } = await import('../src/routes/auth.js');
  const { config } = await import('../src/utils/config.js');
  const { supabaseAdmin, Tables } = await import('../src/utils/supabase.js');
  const sign = (google: boolean, audience?: string) => new SignJWT({ sub: 'private-subject', email: 'private@example.com' })
    .setProtectedHeader({ alg: 'RS256', kid: 'test-key' })
    .setIssuer(google ? 'https://accounts.google.com' : 'https://appleid.apple.com')
    .setAudience(audience ?? (google ? config.integrations.googleClientId : config.apple.clientId))
    .setIssuedAt().setExpirationTime('5m').sign(privateKey);

  // Exercise the handlers with an authenticated request where required.
  async function invoke(path: string, body: unknown) {
    const route = authRouter.stack.find((layer) => layer.route?.path === path)?.route;
    assert.ok(route);
    let status = 200;
    let response: Record<string, unknown> = {};
    const res = {
      status(value: number) { status = value; return this; },
      json(value: Record<string, unknown>) { response = value; return this; },
    };
    const handler = route.stack.at(-1)!.handle;
    await handler({ body, user: { id: 'u1' } } as Request, res as unknown as Response, () => {});
    return { status, body: response };
  }
  const bodyFor = (path: string, token: string) => path === '/google'
    ? { idToken: token }
    : { appleUserId: 'private-subject', identityToken: token };
  return { supabaseAdmin, Tables, sign, invoke, bodyFor };
}

for (const path of ['/signin', '/refresh', '/google']) {
  test(`${path} logs scalar jose diagnostics without the parsed identity payload`, async (t) => {
    const { sign, invoke, bodyFor } = await fixture(t);
    const logs: unknown[][] = [];
    t.mock.method(console, 'error', (...args: unknown[]) => { logs.push(args); });
    const token = await sign(path === '/google', 'wrong-app');
    const result = await invoke(path, bodyFor(path, token));
    assert.equal(result.status, 401);
    assert.equal(result.body.code, 'app_out_of_date');
    assert.equal(logs.length, 1);
    assert.match(String(logs[0]![0]), /app_out_of_date/);
    assert.deepEqual(logs[0]![1], {
      code: 'ERR_JWT_CLAIM_VALIDATION_FAILED', claim: 'aud', reason: 'check_failed',
    });
    assert.doesNotMatch(JSON.stringify(logs), /private-subject|private@example\.com|payload/);
  });

  test(`${path} returns server_error without a token when the epoch read fails`, async (t) => {
    const { supabaseAdmin, Tables, sign, invoke, bodyFor } = await fixture(t);
    t.mock.method(supabaseAdmin, 'from', (table: string) => {
      const query = {
        error: null,
        select() { return this; },
        update() { return this; },
        eq() { return this; },
        async maybeSingle() {
          return { data: table === Tables.AUTH_IDENTITIES
            ? { id: 'identity-1', user_id: 'u1', email: 'private@example.com' }
            : { id: 'u1', apple_user_id: 'private-subject', email: 'private@example.com', account_type: 'real' }, error: null };
        },
        async single() { return { data: null, error: { message: 'database unavailable' } }; },
      };
      return query;
    });
    const result = await invoke(path, bodyFor(path, await sign(path === '/google')));
    assert.equal(result.status, 500);
    assert.equal(result.body.code, 'server_error');
    assert.equal(result.body.success, false);
    assert.equal(result.body.data, undefined);
  });
}

test('Google account errors map only actual identity conflicts to account_in_use', async (t) => {
  const { supabaseAdmin, sign, invoke } = await fixture(t);
  const { IdentityLinkConflictError } = await import('../src/middleware/auth.js');
  const token = await sign(true);
  for (const error of [
    new TypeError('fetch failed'),
    new Error('subject column missing'),
    Object.assign(new Error('not an identity conflict'), { name: 'IdentityLinkConflictError' }),
    new IdentityLinkConflictError('google'),
  ]) {
    const from = t.mock.method(supabaseAdmin, 'from', () => { throw error; });
    const result = await invoke('/google', { idToken: token });
    assert.equal(result.status, error instanceof IdentityLinkConflictError ? 409 : 500);
    assert.equal(result.body.code, error instanceof IdentityLinkConflictError ? 'account_in_use' : 'server_error');
    from.mock.restore();
  }
});

test('deletion returns public fields and retains internal revocation details only in server logs', async (t) => {
  const { supabaseAdmin, invoke } = await fixture(t);
  t.mock.method(globalThis, 'fetch', async () => new Response(JSON.stringify({ error: 'internal-revocation-detail' }), { status: 500 }));
  t.mock.method(supabaseAdmin.storage, 'from', () => ({
    list: async () => ({ data: [{ name: 'episode.mp3' }], error: null }),
    remove: async () => ({ error: null }),
  }));
  const from = t.mock.method(supabaseAdmin, 'from', () => ({
    delete: () => ({ eq: async () => ({ error: null }) }),
  }));
  const logs: unknown[][] = [];
  t.mock.method(console, 'log', (...args: unknown[]) => { logs.push(args); });
  const result = await invoke('/account', {});
  assert.equal(result.status, 200);
  assert.deepEqual(result.body, {
    success: true,
    data: { deleted: true, googleRevoked: false, appleRevoked: 'not_requested', filesRemoved: 1,
      message: 'Your account and everything in it has been deleted.' },
  });
  assert.equal(from.mock.callCount(), 1);
  assert.match(JSON.stringify(logs), /internal-revocation-detail/);
  assert.doesNotMatch(JSON.stringify(result.body), /notes|internal-revocation-detail/);
});
