import { test } from 'node:test';
import assert from 'node:assert/strict';
import { SignJWT, generateKeyPair, exportJWK, createLocalJWKSet } from 'jose';

process.env.AGENT_SERVICE_URL ??= 'http://localhost';
process.env.ANTHROPIC_API_KEY ??= 'test';
process.env.INTERNAL_API_SECRET ??= 'test';
process.env.JWT_SECRET ??= 'test';
process.env.OPENAI_API_KEY ??= 'test';
process.env.SUPABASE_ANON_KEY ??= 'test';
process.env.SUPABASE_SERVICE_KEY ??= 'test';
process.env.SUPABASE_URL ??= 'http://localhost';
process.env.GOOGLE_OAUTH_CLIENT_ID ??= 'web-client';
process.env.GOOGLE_OAUTH_CLIENT_SECRET ??= 'web-secret';

/** Sign in with Google: tokens are checked against Google's keys (stood in for here by local ones). */

async function setup() {
  const { publicKey, privateKey } = await generateKeyPair('RS256');
  const jwk = { ...(await exportJWK(publicKey)), kid: 'k1', alg: 'RS256' };
  const keys = createLocalJWKSet({ keys: [jwk] });
  const sign = (claims: Record<string, unknown>, opts: { iss?: string; aud?: string } = {}) =>
    new SignJWT(claims).setProtectedHeader({ alg: 'RS256', kid: 'k1' })
      .setIssuer(opts.iss ?? 'https://accounts.google.com').setAudience(opts.aud ?? 'ios-client')
      .setIssuedAt().setExpirationTime('5m').sign(privateKey);
  return { keys, sign };
}

test('a genuine Google token gives the person, their email, and whether Google verified it', async () => {
  const { verifyGoogleIdToken } = await import('../src/services/google-auth.js');
  const { keys, sign } = await setup();
  const token = await sign({ sub: 'g-123', email: 'a@example.com', email_verified: true });
  const id = await verifyGoogleIdToken(token, { keys, audiences: ['ios-client'] });
  assert.deepEqual(id, { subject: 'g-123', email: 'a@example.com', emailVerified: true });
});

test('a token issued to a different app is refused, and reads as "app out of date"', async () => {
  const { verifyGoogleIdToken } = await import('../src/services/google-auth.js');
  const { classifyTokenError } = await import('../src/services/auth-errors.js');
  const { keys, sign } = await setup();
  const token = await sign({ sub: 'g-1' }, { aud: 'someone-elses-app' });
  await assert.rejects(verifyGoogleIdToken(token, { keys, audiences: ['ios-client'] }), (err) => {
    assert.equal(classifyTokenError(err, 'Google').code, 'app_out_of_date');
    return true;
  });
});

test('a token not from Google is refused', async () => {
  const { verifyGoogleIdToken } = await import('../src/services/google-auth.js');
  const { keys, sign } = await setup();
  const token = await sign({ sub: 'g-1' }, { iss: 'https://evil.example' });
  await assert.rejects(verifyGoogleIdToken(token, { keys, audiences: ['ios-client'] }));
});

test('with no client ID configured, Google sign-in refuses rather than accepting anything', async () => {
  const { verifyGoogleIdToken } = await import('../src/services/google-auth.js');
  const { keys, sign } = await setup();
  await assert.rejects(verifyGoogleIdToken(await sign({ sub: 'x' }), { keys, audiences: [] }), /not configured/);
});

test('the one-time code is redeemed with the web client and an empty redirect, as iOS requires', async () => {
  const { exchangeGoogleServerAuthCode } = await import('../src/services/google-auth.js');
  let sent: URLSearchParams | null = null;
  const fakeFetch = (async (_url: string, init: { body: URLSearchParams }) => {
    sent = init.body;
    return new Response(JSON.stringify({ access_token: 'a', refresh_token: 'r', expires_in: 3600 }), { status: 200 });
  }) as unknown as typeof fetch;
  const tokens = await exchangeGoogleServerAuthCode('one-time', fakeFetch);
  assert.equal(tokens.refresh_token, 'r');
  assert.equal(sent!.get('client_id'), 'web-client');
  assert.equal(sent!.get('redirect_uri'), '');
  assert.equal(sent!.get('grant_type'), 'authorization_code');
});

test('a refused code exchange is an error, so sign-in can carry on without connecting', async () => {
  const { exchangeGoogleServerAuthCode } = await import('../src/services/google-auth.js');
  const fakeFetch = (async () => new Response('{"error":"invalid_grant"}', { status: 400 })) as unknown as typeof fetch;
  await assert.rejects(exchangeGoogleServerAuthCode('used-twice', fakeFetch), /code exchange failed \(400\)/);
});
