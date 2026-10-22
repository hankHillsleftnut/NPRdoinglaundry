import { createCipheriv, createDecipheriv, createHash, hkdfSync, randomBytes } from 'node:crypto';
import jwt from 'jsonwebtoken';

/**
 * The new app's session tokens (contract 00 §3, BE0.4).
 *
 * - Access token: a 15-minute HS256 JWT, `{ sub, ver, typ: 'access' }`, issuer
 *   `retrospect-api`, audience `retrospect-app`. `ver` is the user's
 *   token_version, so bumping it ends every access token at once.
 * - Refresh token: 32 random bytes, base64url, opaque. Only its SHA-256 is
 *   stored; the plain token exists on the phone and, for 30 seconds after a
 *   rotation, encrypted in refresh_grace (sealGrace).
 *
 * Pure: the clock and the randomness are passed in. Never log a token or a hash.
 */
export const ACCESS_TOKEN_TTL_SECONDS = 15 * 60;
export const ACCESS_ISSUER = 'retrospect-api';
export const ACCESS_AUDIENCE = 'retrospect-app';
export const REFRESH_GRACE_SECONDS = 30;

export interface AccessClaims {
  userId: string;
  tokenVersion: number;
}

export function issueAccessToken(claims: AccessClaims, secret: string, nowMs: number): { token: string; expiresAt: string } {
  const iat = Math.floor(nowMs / 1000);
  const token = jwt.sign({ sub: claims.userId, ver: claims.tokenVersion, typ: 'access', iat }, secret, {
    algorithm: 'HS256',
    expiresIn: ACCESS_TOKEN_TTL_SECONDS,
    issuer: ACCESS_ISSUER,
    audience: ACCESS_AUDIENCE,
  });
  return { token, expiresAt: new Date((iat + ACCESS_TOKEN_TTL_SECONDS) * 1000).toISOString() };
}

/** The claims of a valid access token, or null for anything else (expired, forged, the old shape). */
export function verifyAccessToken(token: string, secret: string, nowMs: number): AccessClaims | null {
  try {
    const payload = jwt.verify(token, secret, {
      algorithms: ['HS256'],
      issuer: ACCESS_ISSUER,
      audience: ACCESS_AUDIENCE,
      clockTimestamp: Math.floor(nowMs / 1000),
    }) as { sub?: unknown; ver?: unknown; typ?: unknown };
    if (payload.typ !== 'access' || typeof payload.sub !== 'string' || typeof payload.ver !== 'number') return null;
    return { userId: payload.sub, tokenVersion: payload.ver };
  } catch {
    return null;
  }
}

export function hashRefreshToken(plain: string): string {
  return createHash('sha256').update(plain, 'utf8').digest('hex');
}

export function newRefreshToken(random: (n: number) => Buffer = randomBytes): { plain: string; hash: string } {
  const plain = random(32).toString('base64url');
  return { plain, hash: hashRefreshToken(plain) };
}

/** A sign-in nonce as the app hashes it into the identity token: SHA-256 hex of the raw nonce. */
export function hashNonce(rawNonce: string): string {
  return createHash('sha256').update(rawNonce, 'utf8').digest('hex');
}

function graceKey(secret: string): Buffer {
  return Buffer.from(hkdfSync('sha256', secret, 'retrospect-refresh-grace', 'aes-256-gcm', 32));
}

/** Encrypts a successor refresh token for its 30 seconds in refresh_grace (AES-256-GCM). */
export function sealGrace(plain: string, secret: string, random: (n: number) => Buffer = randomBytes): string {
  const iv = random(12);
  const cipher = createCipheriv('aes-256-gcm', graceKey(secret), iv);
  const body = Buffer.concat([cipher.update(plain, 'utf8'), cipher.final()]);
  return [iv, cipher.getAuthTag(), body].map((b) => b.toString('base64url')).join('.');
}

export function openGrace(sealed: string, secret: string): string {
  const [iv, tag, body] = sealed.split('.').map((p) => Buffer.from(p, 'base64url'));
  if (!iv || !tag || !body) throw new Error('openGrace: malformed');
  const decipher = createDecipheriv('aes-256-gcm', graceKey(secret), iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(body), decipher.final()]).toString('utf8');
}
