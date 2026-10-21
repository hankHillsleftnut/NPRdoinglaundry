import assert from 'node:assert/strict';
import test from 'node:test';
import { isRejectedAppleToken } from '../src/services/apple-errors.js';

type Jose = typeof import('jose');
type SigningKey = Awaited<ReturnType<Jose['generateKeyPair']>>['privateKey'];

/** A fixed clock: issued at NOW - 1 min, valid for 10 min, verified at NOW. */
const NOW = new Date('2026-10-21T12:00:00.000Z');
const NOW_S = Math.floor(NOW.getTime() / 1000);

/**
 * Real errors from jose's own verifier, not hand-made lookalikes, verified
 * against a key set the way apple-auth.ts verifies against Apple's.
 */
async function verifyError(build: (jose: Jose, key: SigningKey) => Promise<string>, opts: { otherKey?: boolean } = {}): Promise<unknown> {
  const jose = await import('jose');
  const signer = await jose.generateKeyPair('RS256');
  const verifier = opts.otherKey ? await jose.generateKeyPair('RS256') : signer;
  const jwk = { ...(await jose.exportJWK(verifier.publicKey)), alg: 'RS256', kid: 'apple' };
  const keys = jose.createLocalJWKSet({ keys: [jwk] });
  const token = await build(jose, signer.privateKey);
  try {
    await jose.jwtVerify(token, keys, { issuer: 'https://appleid.apple.com', audience: 'app', currentDate: NOW });
  } catch (err) {
    return err;
  }
  throw new Error('expected verification to fail');
}

const sign = (claims: { exp?: number; aud?: string }) =>
  async (jose: Jose, key: SigningKey) =>
    new jose.SignJWT({}).setProtectedHeader({ alg: 'RS256', kid: 'apple' }).setIssuer('https://appleid.apple.com')
      .setAudience(claims.aud ?? 'app').setSubject('s').setIssuedAt(NOW_S - 60)
      .setExpirationTime(claims.exp ?? NOW_S + 600).sign(key);

// BE0.0 (backend-reference §0 finding 6): a bad Apple token came back as a 500.
test('an expired Apple identity token is a rejected token (401), not a 500', async () => {
  assert.equal(isRejectedAppleToken(await verifyError(sign({ exp: NOW_S - 1 }))), true);
});

test('a token signed by another key, for another app, or not a token at all is rejected', async () => {
  assert.equal(isRejectedAppleToken(await verifyError(sign({}), { otherKey: true })), true, 'bad signature');
  assert.equal(isRejectedAppleToken(await verifyError(sign({ aud: 'someone-else' }))), true, 'wrong audience');
  assert.equal(isRejectedAppleToken(await verifyError(async () => 'not-a-jwt')), true, 'malformed');
});

// Integrator review of #61: alg "none" and HS256 were 500s.
test('a token with an algorithm Apple never uses (none, HS256) is rejected', async () => {
  const none = await verifyError(async (jose) => new jose.UnsecuredJWT({}).setIssuer('https://appleid.apple.com').setAudience('app').encode());
  const hs256 = await verifyError(async (jose) =>
    new jose.SignJWT({}).setProtectedHeader({ alg: 'HS256' }).sign(new TextEncoder().encode('x'.repeat(32))));
  assert.equal(isRejectedAppleToken(none), true, 'alg none');
  assert.equal(isRejectedAppleToken(hs256), true, 'HS256');
});

test('failing to reach Apple or anything else is not blamed on the token', () => {
  assert.equal(isRejectedAppleToken(Object.assign(new Error('timeout'), { code: 'ERR_JWKS_TIMEOUT' })), false);
  assert.equal(isRejectedAppleToken(new Error('fetch failed')), false);
  assert.equal(isRejectedAppleToken(null), false);
  assert.equal(isRejectedAppleToken(undefined), false);
});
