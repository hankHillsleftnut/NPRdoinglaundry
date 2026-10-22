/**
 * The real Apple verifier (services/apple-auth.ts verifyAppleSignIn) against a
 * local key set: jose signs tokens the way Apple does, so every check runs
 * for real and no network is touched.
 */
import assert from 'node:assert/strict';
import test, { before } from 'node:test';
import type { JWTVerifyGetKey } from 'jose';
import { verifyAppleSignIn } from '../src/services/apple-auth.js';
import { isRejectedAppleToken } from '../src/services/apple-errors.js';
import { config } from '../src/utils/config.js';

type Jose = typeof import('jose');
type Key = Awaited<ReturnType<Jose['generateKeyPair']>>['privateKey'];
let jose: Jose;
let keys: JWTVerifyGetKey;
let privateKey: Key;
let otherKey: Key;
const KID = 'apple-test-key';
const NOW = Math.floor(Date.now() / 1000);

before(async () => {
  jose = await import('jose');
  const pair = await jose.generateKeyPair('RS256', { extractable: true });
  privateKey = pair.privateKey;
  otherKey = (await jose.generateKeyPair('RS256')).privateKey;
  const jwk = { ...(await jose.exportJWK(pair.publicKey)), kid: KID, alg: 'RS256' };
  keys = jose.createLocalJWKSet({ keys: [jwk] });
});

function token(over: { iss?: string; aud?: string; exp?: number; kid?: string; key?: Key; claims?: Record<string, unknown> } = {}) {
  return new jose.SignJWT({ nonce: 'abc123', email: 'sam@privaterelay.example', ...over.claims })
    .setProtectedHeader({ alg: 'RS256', kid: over.kid ?? KID })
    .setSubject('001234.apple-subject')
    .setIssuer(over.iss ?? 'https://appleid.apple.com')
    .setAudience(over.aud ?? config.apple.clientId)
    .setIssuedAt(NOW - 60)
    .setExpirationTime(over.exp ?? NOW + 600)
    .sign(over.key ?? privateKey);
}

async function rejected(identityToken: string): Promise<boolean> {
  try {
    await verifyAppleSignIn(identityToken, keys);
    return false;
  } catch (err) {
    return isRejectedAppleToken(err);
  }
}

test("a token signed with Apple's key, for this app, passes with its subject, email and nonce", async () => {
  assert.deepEqual(await verifyAppleSignIn(await token(), keys), {
    appleUserId: '001234.apple-subject', email: 'sam@privaterelay.example', nonce: 'abc123',
  });
});

test('a token for another app is invalid_credentials', async () => {
  assert.equal(await rejected(await token({ aud: 'com.someone.else' })), true);
});

test('a token from another issuer is invalid_credentials', async () => {
  assert.equal(await rejected(await token({ iss: 'https://evil.example' })), true);
});

test('an expired token is invalid_credentials', async () => {
  assert.equal(await rejected(await token({ exp: NOW - 120 })), true);
});

test('a token signed with a key Apple never published is invalid_credentials', async () => {
  assert.equal(await rejected(await token({ kid: 'unknown-kid' })), true, 'unknown kid');
  assert.equal(await rejected(await token({ key: otherKey })), true, 'right kid, wrong key');
});

test('HS256 and alg none tokens are invalid_credentials', async () => {
  const hs = await new jose.SignJWT({}).setProtectedHeader({ alg: 'HS256', kid: KID }).setSubject('x')
    .setIssuer('https://appleid.apple.com').setAudience(config.apple.clientId).setExpirationTime(NOW + 600)
    .sign(new TextEncoder().encode('a-shared-secret-anyone-could-guess'));
  assert.equal(await rejected(hs), true, 'HS256');
  const none = new jose.UnsecuredJWT({}).setSubject('x').setIssuer('https://appleid.apple.com')
    .setAudience(config.apple.clientId).setExpirationTime(NOW + 600).encode();
  assert.equal(await rejected(none), true, 'alg none');
  assert.equal(await rejected('not.a.jwt'), true, 'garbage');
});
