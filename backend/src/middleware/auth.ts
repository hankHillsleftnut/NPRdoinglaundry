import type { NextFunction, Request, RequestHandler, Response } from 'express';
import jwt from 'jsonwebtoken';
import { config } from '../utils/config.js';
import { supabaseAdmin, Tables } from '../utils/supabase.js';
import type { AuthUser, JWTPayload } from '../types/index.js';
import { getOrCreateUserWith, type UsersClient } from '../services/users.js';
import { DoorError, sendError } from '../doors/errors.js';
import { verifyAccessToken } from '../sessions/tokens.js';

// Extend Express Request type to include user
declare global {
  namespace Express {
    interface Request {
      user?: AuthUser;
    }
  }
}

/** Finds a signed-in user by id: null when there is no such user; throws when it can't tell. */
export type UserLookup = (userId: string) => Promise<AuthUser | null>;

/** Postgres: the column being read does not exist. */
const UNDEFINED_COLUMN = '42703';
let warnedNoTokenVersion = false;

/**
 * The real lookup: one round trip to the users table per authenticated request.
 *
 * Reads users.token_version (migration 005). If the server reaches production
 * before 005 does, the column is missing: the lookup falls back to the old
 * columns and logs once, so old sign-ins keep working. New access tokens are
 * then refused (no version to check them against), which is the safe side.
 */
/** The slice of supabase-js the lookup uses. */
export interface UserRowsClient {
  from(table: string): {
    select(columns: string): {
      eq(column: string, value: string): {
        maybeSingle(): PromiseLike<{ data: unknown; error: { code?: string } | null }>;
      };
    };
  };
}

export function userLookupWith(db: UserRowsClient): UserLookup {
  return async (userId) => {
    const read = (columns: string) => db.from(Tables.USERS).select(columns).eq('id', userId).maybeSingle();
    let { data, error } = await read('id, apple_user_id, email, token_version');
    if (error?.code === UNDEFINED_COLUMN) {
      if (!warnedNoTokenVersion) {
        warnedNoTokenVersion = true;
        console.warn('[auth] users.token_version is missing: migration 005 is not applied. Only old tokens can sign in.');
      }
      ({ data, error } = await read('id, apple_user_id, email'));
    }
    if (error) throw new Error(`user lookup failed (${error.code ?? 'unknown'})`);
    if (!data) return null;
    const row = data as unknown as { id: string; apple_user_id: string; email: string | null; token_version?: number };
    return {
      id: row.id,
      appleUserId: row.apple_user_id,
      email: row.email ?? undefined,
      ...(typeof row.token_version === 'number' ? { tokenVersion: row.token_version } : {}),
    };
  };
}

export const supabaseUserLookup: UserLookup = userLookupWith(supabaseAdmin as unknown as UserRowsClient);

type AuthFailure = 'missing' | 'invalid' | 'no_user' | 'error';

/** The old routes' bodies, unchanged, so the current app keeps reading them. */
const LEGACY_FAILURES: Record<AuthFailure, { status: number; error: string }> = {
  missing: { status: 401, error: 'Missing or invalid authorization header' },
  invalid: { status: 401, error: 'Invalid or expired token' },
  no_user: { status: 401, error: 'User not found' },
  error: { status: 500, error: 'Authentication error' },
};

/**
 * Authenticates from `Authorization: Bearer <jwt>` and sets `req.user` from the
 * token's user id, looked up with `users`.
 *
 * `envelope: true` (the `/v2` doors) answers failures in contract 00's
 * envelope (`unauthenticated` 401, `internal` 500); otherwise the old routes'
 * bodies, unchanged.
 *
 * A lookup that fails (the database is unreachable) is a 500, not a 401: a 401
 * signs the current app out, and an outage shouldn't sign everyone out.
 */
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function makeAuthMiddleware(users: UserLookup, opts: { envelope?: boolean; now?: () => number } = {}): RequestHandler {
  const fail = (res: Response, failure: AuthFailure) => {
    if (opts.envelope) {
      sendError(res, new DoorError(failure === 'error' ? 'internal' : 'unauthenticated'));
      return;
    }
    const { status, error } = LEGACY_FAILURES[failure];
    res.status(status).json({ success: false, error });
  };

  // Named, so the app's route list reads as it did before the factory existed.
  return async function authMiddleware(req: Request, res: Response, next: NextFunction): Promise<void> {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      fail(res, 'missing');
      return;
    }

    const token = authHeader.substring(7);
    const nowMs = opts.now ? opts.now() : Date.now();

    // The new 15-minute access token (BE0.4), or the old 30-day shape, which
    // old app versions keep using until X07 retires it.
    let userId: string;
    let requiredVersion: number | null = null;
    const access = verifyAccessToken(token, config.jwt.secret, nowMs);
    if (access) {
      userId = access.userId;
      requiredVersion = access.tokenVersion;
    } else {
      let payload: JWTPayload;
      try {
        payload = jwt.verify(token, config.jwt.secret, { clockTimestamp: Math.floor(nowMs / 1000) }) as JWTPayload;
      } catch {
        fail(res, 'invalid');
        return;
      }
      if (typeof payload?.userId !== 'string') {
        fail(res, 'invalid');
        return;
      }
      userId = payload.userId;
    }
    // A validly signed token whose user id isn't a UUID names no user.
    if (!UUID.test(userId)) {
      fail(res, 'invalid');
      return;
    }

    let user: AuthUser | null;
    try {
      user = await users(userId);
    } catch (error) {
      console.error('Auth middleware error:', error instanceof Error ? error.message : 'unknown');
      fail(res, 'error');
      return;
    }
    if (!user) {
      fail(res, 'no_user');
      return;
    }
    // A bumped token_version ends every access token issued before it.
    if (requiredVersion !== null && user.tokenVersion !== requiredVersion) {
      fail(res, 'invalid');
      return;
    }

    req.user = user;
    next();
  };
}

/** The old routes' middleware, built from the real lookup; existing imports keep working. */
export const authMiddleware = makeAuthMiddleware(supabaseUserLookup);

// Generate JWT for a user
export function generateToken(user: AuthUser): string {
  const payload: Omit<JWTPayload, 'iat' | 'exp'> = {
    userId: user.id,
    appleUserId: user.appleUserId,
  };

  return jwt.sign(payload, config.jwt.secret, {
    expiresIn: config.jwt.expiresIn,
  });
}

// Create or get user from Apple Sign In (race-safe; see services/users.ts)
export async function getOrCreateUser(
  appleUserId: string,
  email?: string
): Promise<AuthUser> {
  return getOrCreateUserWith(supabaseAdmin as unknown as UsersClient, Tables.USERS, appleUserId, email);
}
