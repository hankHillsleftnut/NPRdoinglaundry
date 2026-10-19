/**
 * Sign in with Google, and connecting Google in the same step.
 *
 * The app signs in with Google and sends two things: an ID token (who they are)
 * and, when the person granted data access in that same consent, a one-time
 * server auth code. The ID token is verified here against Google's keys; the
 * code is exchanged for the tokens that let the agent read their Calendar, Docs,
 * Gmail and YouTube -- exactly as the separate "Connect Google" flow does.
 */

import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey } from 'jose';
import { config } from '../utils/config.js';

const googleKeys = createRemoteJWKSet(new URL('https://www.googleapis.com/oauth2/v3/certs'));

export interface VerifiedGoogleIdentity {
  subject: string;
  email?: string;
  emailVerified: boolean;
}

/** The client IDs a Google ID token may be issued to: the iOS app, and the backend's web client. */
export function googleAudiences(): string[] {
  return [config.integrations.googleIosClientId, config.integrations.googleClientId].filter(Boolean);
}

export async function verifyGoogleIdToken(
  idToken: string,
  options: { keys?: JWTVerifyGetKey; audiences?: string[] } = {},
): Promise<VerifiedGoogleIdentity> {
  const audiences = options.audiences ?? googleAudiences();
  if (audiences.length === 0) throw new Error('Google sign-in is not configured (no client ID)');
  const { payload } = await jwtVerify(idToken, options.keys ?? googleKeys, {
    issuer: ['https://accounts.google.com', 'accounts.google.com'],
    audience: audiences,
  });
  if (!payload.sub) throw new Error('Google identity token does not contain a subject');
  return {
    subject: payload.sub,
    ...(typeof payload.email === 'string' ? { email: payload.email } : {}),
    emailVerified: payload.email_verified === true,
  };
}

/**
 * Exchange the app's one-time server auth code for Google tokens. iOS server
 * auth codes are redeemed with the web client and an empty redirect URI.
 */
export async function exchangeGoogleServerAuthCode(
  code: string,
  fetchImpl: typeof fetch = fetch,
): Promise<Record<string, unknown>> {
  const body = new URLSearchParams({
    code,
    client_id: config.integrations.googleClientId,
    client_secret: config.integrations.googleClientSecret,
    redirect_uri: '',
    grant_type: 'authorization_code',
  });
  const res = await fetchImpl('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });
  const tokens = (await res.json()) as Record<string, unknown>;
  if (!res.ok) throw new Error(`Google code exchange failed (${res.status})`);
  return tokens;
}
