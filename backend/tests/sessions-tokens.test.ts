import assert from 'node:assert/strict';
import test from 'node:test';
import jwt from 'jsonwebtoken';
import {
  ACCESS_TOKEN_TTL_SECONDS, hashNonce, hashRefreshToken, issueAccessToken, newRefreshToken, openGrace, sealGrace, verifyAccessToken,
} from '../src/sessions/tokens.js';

const SECRET = 'test-only-not-a-key';
const T0 = Date.parse('2026-10-21T12:00:00.000Z');
const USER = '11111111-1111-4111-8111-111111111111';

test('an access token lasts 15 minutes and says who and which version', () => {
  const { token, expiresAt } = issueAccessToken({ userId: USER, tokenVersion: 3 }, SECRET, T0);
  assert.equal(expiresAt, new Date(T0 + ACCESS_TOKEN_TTL_SECONDS * 1000).toISOString());
  assert.deepEqual(verifyAccessToken(token, SECRET, T0 + 14 * 60 * 1000), { userId: USER, tokenVersion: 3 });
  assert.equal(verifyAccessToken(token, SECRET, T0 + 15 * 60 * 1000 + 1000), null, 'expired');
});

test('forged, foreign or old-shape tokens are not access tokens', () => {
  const iat = Math.floor(T0 / 1000);
  const sign = (payload: object, opts: jwt.SignOptions, secret = SECRET) => jwt.sign({ iat, ...payload }, secret, { expiresIn: 900, ...opts });
  const base = { sub: USER, ver: 0, typ: 'access' };
  const good = { issuer: 'retrospect-api', audience: 'retrospect-app' };
  assert.equal(verifyAccessToken(sign(base, good, 'another-secret'), SECRET, T0), null, 'wrong secret');
  assert.equal(verifyAccessToken(sign(base, { ...good, audience: 'someone-else' }), SECRET, T0), null, 'wrong audience');
  assert.equal(verifyAccessToken(sign(base, { ...good, issuer: 'someone-else' }), SECRET, T0), null, 'wrong issuer');
  assert.equal(verifyAccessToken(sign({ ...base, typ: 'refresh' }, good), SECRET, T0), null, 'not an access token');
  assert.equal(verifyAccessToken(sign({ userId: USER, appleUserId: 'a' }, {}), SECRET, T0), null, 'the old 30-day shape');
  assert.equal(verifyAccessToken(sign(base, { ...good, algorithm: 'HS512' }), SECRET, T0), null, 'another algorithm');
  const unsigned = `${Buffer.from('{"alg":"none","typ":"JWT"}').toString('base64url')}.${Buffer.from(JSON.stringify({ ...base, iss: 'retrospect-api', aud: 'retrospect-app', iat, exp: iat + 900 })).toString('base64url')}.`;
  assert.equal(verifyAccessToken(unsigned, SECRET, T0), null, 'alg none');
});

test('a refresh token is 32 random bytes, stored only as its hash', () => {
  const t = newRefreshToken((n) => Buffer.alloc(n, 7));
  assert.equal(Buffer.from(t.plain, 'base64url').length, 32);
  assert.equal(t.hash, hashRefreshToken(t.plain));
  assert.match(t.hash, /^[0-9a-f]{64}$/);
  assert.notEqual(newRefreshToken().plain, newRefreshToken().plain);
});

test('the grace copy of a refresh token is encrypted and tamper-evident', () => {
  const sealed = sealGrace('the-successor', SECRET);
  assert.equal(sealed.includes('the-successor'), false);
  assert.equal(openGrace(sealed, SECRET), 'the-successor');
  assert.throws(() => openGrace(sealed, 'another-secret'));
  const [iv, tag, body] = sealed.split('.');
  const flipped = Buffer.from(body!, 'base64url');
  flipped[0] = flipped[0]! ^ 1;
  assert.throws(() => openGrace([iv, tag, flipped.toString('base64url')].join('.'), SECRET));
});

test('a nonce is hashed the way Apple expects: SHA-256 hex of the raw nonce', () => {
  assert.equal(hashNonce('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
});
