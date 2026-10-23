import { createCipheriv, createDecipheriv, createPrivateKey, randomBytes } from 'node:crypto';
import { decodeJwt, importPKCS8, SignJWT } from 'jose';

/**
 * Apple's tokens for Sign in with Apple (BE0.5, Apple TN3194, App Review 5.1.1(v)).
 *
 * At sign-in the app sends a one-time authorization code (it lives about five
 * minutes and works once). The sign-in door trades it here for Apple's refresh
 * token and keeps that sealed on the user, so account deletion (BE0.7) can
 * revoke it. Everything that talks to Apple is gated by APPLE_REVOKE_ENABLED:
 * with the flag off nothing here calls Apple.
 *
 * - clientSecret(): the ES256 JWT Apple wants as client_secret (iss Team ID,
 *   sub APPLE_CLIENT_ID, aud appleid.apple.com, kid APPLE_KEY_ID), valid 180
 *   days, cached and re-minted a day before it runs out.
 * - exchangeCode(): POST /auth/token, grant_type=authorization_code.
 * - revoke(): POST /auth/revoke with token_type_hint (used by BE0.7 and BE0.13).
 * - sealAppleToken()/openAppleToken(): AES-256-GCM under TOKEN_ENCRYPTION_KEY
 *   (32 bytes, base64), a fresh IV every time, `v1:<iv>:<tag>:<ciphertext>`.
 *
 * Never log or return a code, a token, a ciphertext or the client secret.
 * Errors thrown here carry Apple's HTTP status at most, never a body.
 * `fetch` and the clock are passed in so tests never reach Apple.
 */

export const APPLE_AUDIENCE = 'https://appleid.apple.com';
export const APPLE_TOKEN_URL = 'https://appleid.apple.com/auth/token';
export const APPLE_REVOKE_URL = 'https://appleid.apple.com/auth/revoke';
/** Apple allows at most six months; 180 days stays under it. */
export const CLIENT_SECRET_TTL_SECONDS = 180 * 24 * 60 * 60;
/** A cached client secret is replaced this long before it runs out. */
export const CLIENT_SECRET_RENEW_SECONDS = 24 * 60 * 60;
/** The code is exchanged inside the sign-in request, so Apple gets this long at most. */
export const APPLE_CALL_TIMEOUT_MS = 5_000;

/** config.apple: what this module reads. */
export interface AppleTokenSettings {
  clientId: string;
  teamId: string;
  keyId: string;
  /** The .p8 key's PEM; `\n` written as two characters (one-line env value) is accepted. */
  privateKey: string;
  revokeEnabled: boolean;
  /** TOKEN_ENCRYPTION_KEY: 32 bytes, base64. */
  tokenEncryptionKey: string | null;
}

/** The part of fetch this module uses. */
export type AppleFetch = (url: string, init: {
  method: 'POST';
  headers: Record<string, string>;
  body: string;
  signal?: AbortSignal;
}) => Promise<{ ok: boolean; status: number; json(): Promise<unknown> }>;

export type AppleTokenHint = 'refresh_token' | 'access_token';

export interface AppleTokenGrant {
  refreshToken: string | null;
  /** The `sub` of the id_token Apple returned with the grant, when it sent one. */
  appleUserId: string | null;
}

export interface AppleTokens {
  clientSecret(): Promise<string>;
  exchangeCode(code: string): Promise<AppleTokenGrant>;
  revoke(token: string, hint: AppleTokenHint): Promise<void>;
}

const pem = (key: string) => key.replace(/\\n/g, '\n');

/** TOKEN_ENCRYPTION_KEY as 32 bytes, or a thrown error that names the variable only. */
export function encryptionKeyOf(base64: string | null | undefined): Buffer {
  const bytes = Buffer.from(base64 ?? '', 'base64');
  if (bytes.length !== 32) throw new Error('TOKEN_ENCRYPTION_KEY must be 32 bytes, base64 (openssl rand -base64 32)');
  return bytes;
}

/** Seals a token for the database: AES-256-GCM, a fresh 12-byte IV each time. */
export function sealAppleToken(plain: string, sealingKey: Buffer, random: (n: number) => Buffer = randomBytes): string {
  const iv = random(12);
  const cipher = createCipheriv('aes-256-gcm', sealingKey, iv);
  const body = Buffer.concat([cipher.update(plain, 'utf8'), cipher.final()]);
  return ['v1', ...[iv, cipher.getAuthTag(), body].map((b) => b.toString('base64url'))].join(':');
}

/** Opens a sealed token; throws (without the value) on a wrong key, a tampered value or an unknown version. */
export function openAppleToken(sealed: string, sealingKey: Buffer): string {
  const [version, ...parts] = sealed.split(':');
  if (version !== 'v1' || parts.length !== 3) throw new Error('openAppleToken: not a v1 sealed token');
  const [iv, tag, body] = parts.map((p) => Buffer.from(p, 'base64url')) as [Buffer, Buffer, Buffer];
  // Pinned: GCM would otherwise accept a tag cut down to 4 bytes.
  if (iv.length !== 12 || tag.length !== 16) throw new Error('openAppleToken: not a v1 sealed token');
  const decipher = createDecipheriv('aes-256-gcm', sealingKey, iv, { authTagLength: 16 });
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(body!), decipher.final()]).toString('utf8');
}

/**
 * The start-up check: with APPLE_REVOKE_ENABLED on, every piece must be there
 * and readable, or the server refuses to start (like an unreadable version
 * floor). With the flag off nothing is required. Messages name variables only.
 */
export function checkAppleTokenSettings(settings: AppleTokenSettings): void {
  if (!settings.revokeEnabled) return;
  const missing = (['clientId', 'teamId', 'keyId', 'privateKey'] as const).filter((k) => !settings[k]);
  if (missing.length > 0) {
    const names: Record<(typeof missing)[number], string> = {
      clientId: 'APPLE_CLIENT_ID', teamId: 'APPLE_TEAM_ID', keyId: 'APPLE_KEY_ID', privateKey: 'APPLE_PRIVATE_KEY',
    };
    throw new Error(`APPLE_REVOKE_ENABLED is true but ${missing.map((k) => names[k]).join(', ')} is not set`);
  }
  encryptionKeyOf(settings.tokenEncryptionKey);
  let ok = false;
  try {
    const key = createPrivateKey(pem(settings.privateKey));
    ok = key.asymmetricKeyType === 'ec' && key.asymmetricKeyDetails?.namedCurve === 'prime256v1';
  } catch {
    ok = false;
  }
  if (!ok) throw new Error('APPLE_PRIVATE_KEY must be the Sign in with Apple .p8 key (EC P-256, PEM)');
}

function form(fields: Record<string, string>): string {
  return new URLSearchParams(fields).toString();
}

export function createAppleTokens(opts: {
  settings: AppleTokenSettings;
  fetch?: AppleFetch;
  /** Milliseconds since the epoch. */
  now?: () => number;
}): AppleTokens {
  const { settings } = opts;
  const doFetch: AppleFetch = opts.fetch ?? ((url, init) => fetch(url, init));
  const now = opts.now ?? Date.now;
  let cached: { jwt: string; exp: number } | null = null;

  async function clientSecret(): Promise<string> {
    const nowSec = Math.floor(now() / 1000);
    if (cached && nowSec < cached.exp - CLIENT_SECRET_RENEW_SECONDS) return cached.jwt;
    const signingKey = await importPKCS8(pem(settings.privateKey), 'ES256');
    const exp = nowSec + CLIENT_SECRET_TTL_SECONDS;
    const jwt = await new SignJWT({})
      .setProtectedHeader({ alg: 'ES256', kid: settings.keyId })
      .setIssuer(settings.teamId)
      .setSubject(settings.clientId)
      .setAudience(APPLE_AUDIENCE)
      .setIssuedAt(nowSec)
      .setExpirationTime(exp)
      .sign(signingKey);
    cached = { jwt, exp };
    return jwt;
  }

  async function post(url: string, fields: Record<string, string>, what: string) {
    // The gate: with the flag off nothing here reaches Apple.
    if (!settings.revokeEnabled) throw new Error(`apple ${what}: APPLE_REVOKE_ENABLED is off`);
    const secret = await clientSecret();
    const res = await doFetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: form({ client_id: settings.clientId, client_secret: secret, ...fields }),
      signal: AbortSignal.timeout(APPLE_CALL_TIMEOUT_MS),
    });
    // Status only: Apple's error body is never carried along.
    if (!res.ok) throw new Error(`apple ${what}: HTTP ${res.status}`);
    return res;
  }

  return {
    clientSecret,
    async exchangeCode(code) {
      const res = await post(APPLE_TOKEN_URL, { code, grant_type: 'authorization_code' }, 'token');
      const body = (await res.json().catch(() => null)) as { refresh_token?: unknown; id_token?: unknown } | null;
      let appleUserId: string | null = null;
      // Straight from Apple over TLS, so read without re-verifying; used only to match the signed-in subject.
      if (typeof body?.id_token === 'string') {
        try {
          const sub = decodeJwt(body.id_token).sub;
          appleUserId = typeof sub === 'string' ? sub : null;
        } catch {
          appleUserId = null;
        }
      }
      return { refreshToken: typeof body?.refresh_token === 'string' && body.refresh_token ? body.refresh_token : null, appleUserId };
    },
    async revoke(token, hint) {
      await post(APPLE_REVOKE_URL, { token, token_type_hint: hint }, 'revoke');
    },
  };
}

/** The subset of the Supabase client the keeper writes through. */
export interface AppleTokenDb {
  from(table: string): {
    update(values: Record<string, unknown>): {
      eq(column: string, value: unknown): {
        select(columns: string): { maybeSingle(): PromiseLike<{ data: unknown; error: unknown }> };
      };
    };
  };
}

/**
 * Exchanges a sign-in's authorization code and keeps the sealed refresh token
 * on the user. Resolves true when stored, false otherwise (Apple refused or was
 * down, no refresh token, a grant not for this Apple subject, the write failed);
 * never throws and never fails a sign-in.
 */
export type KeepAppleToken = (userId: string, appleUserId: string, authorizationCode: string) => Promise<boolean>;

/**
 * The sign-in door's keeper, or undefined when APPLE_REVOKE_ENABLED is off (the
 * door then never calls Apple). Throws on a bad configuration with the flag on:
 * the server must not start that way.
 */
export function createAppleTokenKeeper(opts: {
  settings: AppleTokenSettings;
  db: AppleTokenDb;
  fetch?: AppleFetch;
  now?: () => number;
}): KeepAppleToken | undefined {
  checkAppleTokenSettings(opts.settings);
  if (!opts.settings.revokeEnabled) return undefined;
  const sealingKey = encryptionKeyOf(opts.settings.tokenEncryptionKey);
  const apple = createAppleTokens(opts);
  const now = opts.now ?? Date.now;
  return async (userId, appleUserId, authorizationCode) => {
    try {
      const grant = await apple.exchangeCode(authorizationCode);
      if (!grant.refreshToken) return false;
      // A code for another Apple account (or a grant that doesn't say whose it is) is never kept on this one.
      if (grant.appleUserId !== appleUserId) return false;
      const { data, error } = await opts.db.from('users').update({
        apple_refresh_token_ciphertext: sealAppleToken(grant.refreshToken, sealingKey),
        apple_refresh_token_at: new Date(now()).toISOString(),
      }).eq('id', userId).select('id').maybeSingle();
      return !error && data !== null;
    } catch {
      return false;
    }
  };
}
