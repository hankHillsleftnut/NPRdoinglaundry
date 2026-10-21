import assert from 'node:assert/strict';
import test from 'node:test';
import { isRejectedAppleToken } from '../src/services/apple-errors.js';

type SigningKey = Awaited<ReturnType<typeof import('jose')['generateKeyPair']>>['privateKey'];

/** Real errors from jose's own verifier, not hand-made lookalikes. */
async function verifyError(build: (jose: typeof import('jose'), key: SigningKey) => Promise<string>, verifyWith?: 'other-key'): Promise<unknown> {
  const jose = await import('jose');
  const { privateKey, publicKey } = await jose.generateKeyPair('RS256');
  const other = await jose.generateKeyPair('RS256');
  const token = await build(jose, privateKey);
  try {
    await jose.jwtVerify(token, verifyWith ? other.publicKey : publicKey, { issuer: 'https://appleid.apple.com', audience: 'app' });
  } catch (err) {
    return err;
  }
  throw new Error('expected verification to fail');
}

const sign = (claims: { exp?: number; aud?: string }) =>
  async (jose: typeof import('jose'), key: SigningKey) =>
    new jose.SignJWT({}).setProtectedHeader({ alg: 'RS256' }).setIssuer('https://appleid.apple.com')
      .setAudience(claims.aud ?? 'app').setSubject('s').setIssuedAt(1_000)
      .setExpirationTime(claims.exp ?? Math.floor(Date.now() / 1000) + 600).sign(key);

// BE0.0 (backend-reference §0 finding 6): a bad Apple token came back as a 500.
test('an expired Apple identity token is a rejected token (401), not a 500', async () => {
  assert.equal(isRejectedAppleToken(await verifyError(sign({ exp: 2_000 }))), true);
});

test('a token signed by another key, for another app, or not a token at all is rejected', async () => {
  assert.equal(isRejectedAppleToken(await verifyError(sign({}), 'other-key')), true, 'bad signature');
  assert.equal(isRejectedAppleToken(await verifyError(sign({ aud: 'someone-else' }))), true, 'wrong audience');
  assert.equal(isRejectedAppleToken(await verifyError(async () => 'not-a-jwt')), true, 'malformed');
});

test('failing to reach Apple or anything else is not blamed on the token', () => {
  assert.equal(isRejectedAppleToken(Object.assign(new Error('timeout'), { code: 'ERR_JWKS_TIMEOUT' })), false);
  assert.equal(isRejectedAppleToken(new Error('fetch failed')), false);
  assert.equal(isRejectedAppleToken(null), false);
  assert.equal(isRejectedAppleToken(undefined), false);
});
