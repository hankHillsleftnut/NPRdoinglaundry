/**
 * Delete my account — everything, and the sign-in links to it.
 *
 * Apple requires an app that creates accounts to let people delete them from
 * inside the app, and to revoke their Sign in with Apple link when they do.
 * Order matters:
 *   1. Revoke what can only be revoked while we still hold it: Google's access
 *      (through the agent, which holds the encrypted tokens) and Apple's link.
 *      These are best effort -- a failure is reported, never a reason to keep
 *      someone's data they asked us to delete.
 *   2. Remove stored files (episode audio), which the database cannot cascade.
 *   3. Delete the account row last. Every table that belongs to a person
 *      references users(id) ON DELETE CASCADE, so this removes all of it.
 */

import { SignJWT, importPKCS8 } from 'jose';
import { config } from '../utils/config.js';

export interface DeletionDeps {
  revokeGoogle: (userId: string) => Promise<boolean>;
  revokeApple: (authorizationCode: string) => Promise<boolean>;
  removeStoredFiles: (userId: string) => Promise<number>;
  deleteUserRow: (userId: string) => Promise<void>;
}

export interface DeletionResult {
  deleted: true;
  googleRevoked: boolean;
  appleRevoked: boolean | 'not_requested';
  filesRemoved: number;
  notes: string[];
}

export async function deleteAccount(
  userId: string,
  options: { appleAuthorizationCode?: string },
  deps: DeletionDeps,
): Promise<DeletionResult> {
  const notes: string[] = [];

  let googleRevoked = false;
  try {
    googleRevoked = await deps.revokeGoogle(userId);
  } catch (err) {
    notes.push(`Google access not revoked: ${(err as Error).message}`);
  }

  let appleRevoked: boolean | 'not_requested' = 'not_requested';
  if (options.appleAuthorizationCode) {
    try {
      appleRevoked = await deps.revokeApple(options.appleAuthorizationCode);
    } catch (err) {
      appleRevoked = false;
      notes.push(`Apple link not revoked: ${(err as Error).message}`);
    }
  }

  let filesRemoved = 0;
  try {
    filesRemoved = await deps.removeStoredFiles(userId);
  } catch (err) {
    notes.push(`Stored files not removed: ${(err as Error).message}`);
  }

  // Last, and not optional: if this fails, the whole request fails.
  await deps.deleteUserRow(userId);

  return { deleted: true, googleRevoked, appleRevoked, filesRemoved, notes };
}

/**
 * Apple's client secret: a short-lived ES256 JWT signed with the app's Sign in
 * with Apple key (APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY).
 */
export async function appleClientSecret(now = new Date()): Promise<string> {
  const { teamId, keyId, privateKey, clientId } = config.apple;
  if (!teamId || !keyId || !privateKey) throw new Error('Sign in with Apple key is not configured');
  const key = await importPKCS8(privateKey.replace(/\\n/g, '\n'), 'ES256');
  const iat = Math.floor(now.getTime() / 1000);
  return new SignJWT({})
    .setProtectedHeader({ alg: 'ES256', kid: keyId })
    .setIssuer(teamId)
    .setSubject(clientId)
    .setAudience('https://appleid.apple.com')
    .setIssuedAt(iat)
    .setExpirationTime(iat + 300)
    .sign(key);
}

/**
 * Revoke the person's Sign in with Apple link. The app passes a fresh
 * authorization code (from asking them to confirm with Apple); it is exchanged
 * for a refresh token, which is then revoked.
 */
export async function revokeAppleAuthorization(code: string, fetchImpl: typeof fetch = fetch): Promise<boolean> {
  const clientSecret = await appleClientSecret();
  const form = (fields: Record<string, string>) =>
    ({ method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams(fields) });
  const tokenRes = await fetchImpl('https://appleid.apple.com/auth/token', form({
    client_id: config.apple.clientId, client_secret: clientSecret, code, grant_type: 'authorization_code',
  }));
  const tokens = (await tokenRes.json()) as { refresh_token?: string; access_token?: string };
  if (!tokenRes.ok) throw new Error(`Apple code exchange failed (${tokenRes.status})`);
  const token = tokens.refresh_token ?? tokens.access_token;
  if (!token) throw new Error('Apple returned no token to revoke');
  const revokeRes = await fetchImpl('https://appleid.apple.com/auth/revoke', form({
    client_id: config.apple.clientId, client_secret: clientSecret, token,
    token_type_hint: tokens.refresh_token ? 'refresh_token' : 'access_token',
  }));
  if (!revokeRes.ok) throw new Error(`Apple revoke failed (${revokeRes.status})`);
  return true;
}
