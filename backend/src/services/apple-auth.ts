import { createRemoteJWKSet, jwtVerify } from 'jose';
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
