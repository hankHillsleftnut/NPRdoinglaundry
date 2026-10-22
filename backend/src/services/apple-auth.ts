import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey } from 'jose';
import { config } from '../utils/config.js';

const appleKeys = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));

export async function verifyAppleIdentityToken(identityToken: string): Promise<{
  appleUserId: string;
  email?: string;
}> {
  const { payload } = await jwtVerify(identityToken, appleKeys, {
    issuer: 'https://appleid.apple.com',
    audience: config.apple.clientId,
  });
  if (!payload.sub) throw new Error('Apple identity token does not contain a subject');
  return {
    appleUserId: payload.sub,
    ...(typeof payload.email === 'string' ? { email: payload.email } : {}),
  };
}

export interface AppleSignIn {
  appleUserId: string;
  email?: string;
  /** The token's nonce claim: SHA-256 hex of the raw nonce the app generated. */
  nonce?: string;
}

/**
 * Verifies an identity token for the new sign-in (BE0.4c): Apple's keys,
 * issuer, audience = APPLE_CLIENT_ID, RS256 only. Throws jose's errors, which
 * services/apple-errors.ts sorts into "bad token" (401) and "couldn't check" (500).
 * `keys` is Apple's published key set; tests pass a local one.
 */
export async function verifyAppleSignIn(identityToken: string, keys: JWTVerifyGetKey = appleKeys): Promise<AppleSignIn> {
  const { payload } = await jwtVerify(identityToken, keys, {
    issuer: 'https://appleid.apple.com',
    audience: config.apple.clientId,
    algorithms: ['RS256'],
  });
  if (!payload.sub) throw new Error('Apple identity token does not contain a subject');
  return {
    appleUserId: payload.sub,
    ...(typeof payload.email === 'string' ? { email: payload.email } : {}),
    ...(typeof payload.nonce === 'string' ? { nonce: payload.nonce } : {}),
  };
}
