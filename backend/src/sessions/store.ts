import { issueAccessToken, newRefreshToken, type AccessClaims } from './tokens.js';

/**
 * The database side of sessions (migration 005). Each method is one SQL
 * function, so one transaction; the store is an interface so routes are
 * tested over HTTP with an in-memory one and the SQL is tested on PGlite.
 */
export type RotateResult =
  | { outcome: 'rotated'; userId: string }
  | { outcome: 'grace'; userId: string; accessToken: string; accessExpiresAt: string; refreshCiphertext: string }
  | { outcome: 'revoked' };

export interface SessionStore {
  /** Starts a new family for one device with this token hash. */
  issue(userId: string, tokenHash: string, nowIso: string, device?: string): Promise<void>;
  /** Who a refresh token belongs to (any state), or null when it isn't one. */
  ownerOf(tokenHash: string): Promise<string | null>;
  rotate(input: {
    tokenHash: string; newHash: string; nowIso: string;
    accessToken: string; accessExpiresAt: string; refreshCiphertext: string;
  }): Promise<RotateResult>;
  /** Ends the presented token's family (this device). */
  revoke(tokenHash: string, nowIso: string): Promise<boolean>;
  /** True the first time a nonce is seen while it lives; false after. */
  useNonce(nonceHash: string, nowIso: string): Promise<boolean>;
}

/** What `rpc` returns in supabase-js: enough of it for the store. */
export interface RpcClient {
  rpc(fn: string, args: Record<string, unknown>): PromiseLike<{ data: unknown; error: { code?: string } | null }>;
  from(table: string): {
    select(columns: string): {
      eq(column: string, value: string): {
        maybeSingle(): PromiseLike<{ data: { user_id: string } | null; error: { code?: string } | null }>;
      };
    };
  };
}

function check<T>(fn: string, r: { data: unknown; error: { code?: string } | null }): T {
  // The code only: a database message can carry row values.
  if (r.error) throw new Error(`${fn} failed (${r.error.code ?? 'unknown'})`);
  return r.data as T;
}

export function supabaseSessionStore(db: RpcClient): SessionStore {
  return {
    async issue(userId, tokenHash, nowIso, device) {
      check('issue_session', await db.rpc('issue_session', { p_user: userId, p_token_hash: tokenHash, p_now: nowIso, p_device: device ?? null }));
    },
    async ownerOf(tokenHash) {
      const r = await db.from('refresh_tokens').select('user_id').eq('token_hash', tokenHash).maybeSingle();
      return check<{ user_id: string } | null>('refresh_tokens lookup', r)?.user_id ?? null;
    },
    async rotate(input) {
      const raw = check<Record<string, unknown>>('rotate_refresh_token', await db.rpc('rotate_refresh_token', {
        p_token_hash: input.tokenHash, p_new_hash: input.newHash, p_now: input.nowIso,
        p_access_token: input.accessToken, p_access_expires_at: input.accessExpiresAt, p_refresh_ciphertext: input.refreshCiphertext,
      }));
      if (raw.outcome === 'rotated') return { outcome: 'rotated', userId: String(raw.user_id) };
      if (raw.outcome === 'grace') {
        return {
          outcome: 'grace', userId: String(raw.user_id), accessToken: String(raw.access_token),
          accessExpiresAt: new Date(String(raw.access_expires_at)).toISOString(), refreshCiphertext: String(raw.refresh_ciphertext),
        };
      }
      return { outcome: 'revoked' };
    },
    async revoke(tokenHash, nowIso) {
      return check<boolean>('revoke_session', await db.rpc('revoke_session', { p_token_hash: tokenHash, p_now: nowIso })) === true;
    },
    async useNonce(nonceHash, nowIso) {
      return check<boolean>('use_nonce', await db.rpc('use_nonce', { p_nonce_hash: nonceHash, p_now: nowIso })) === true;
    },
  };
}

export interface IssuedSession {
  accessToken: string;
  refreshToken: string;
  accessTokenExpiresAt: string;
}

/** A new session for one device: a fresh family and an access token. */
export async function startSession(
  store: SessionStore, claims: AccessClaims, secret: string, nowMs: number, opts: { device?: string; random?: (n: number) => Buffer } = {},
): Promise<IssuedSession> {
  const refresh = newRefreshToken(opts.random);
  await store.issue(claims.userId, refresh.hash, new Date(nowMs).toISOString(), opts.device);
  const access = issueAccessToken(claims, secret, nowMs);
  return { accessToken: access.token, refreshToken: refresh.plain, accessTokenExpiresAt: access.expiresAt };
}
