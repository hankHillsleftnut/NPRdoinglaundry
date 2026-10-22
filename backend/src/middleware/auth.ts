import type { NextFunction, Request, RequestHandler, Response } from 'express';
import jwt from 'jsonwebtoken';
import { config } from '../utils/config.js';
import { supabaseAdmin, Tables } from '../utils/supabase.js';
import type { AuthUser, JWTPayload } from '../types/index.js';
import { getOrCreateUserWith, type UsersClient } from '../services/users.js';
import { DoorError, sendError } from '../doors/errors.js';

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

/** The real lookup: one round trip to the users table per authenticated request. */
export const supabaseUserLookup: UserLookup = async (userId) => {
  const { data, error } = await supabaseAdmin
    .from(Tables.USERS)
    .select('id, apple_user_id, email')
    .eq('id', userId)
    .maybeSingle();
  if (error) throw new Error(`user lookup failed (${error.code ?? 'unknown'})`);
  if (!data) return null;
  return { id: data.id, appleUserId: data.apple_user_id, email: data.email ?? undefined };
};

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
export function makeAuthMiddleware(users: UserLookup, opts: { envelope?: boolean } = {}): RequestHandler {
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

    let payload: JWTPayload;
    try {
      payload = jwt.verify(authHeader.substring(7), config.jwt.secret) as JWTPayload;
    } catch {
      fail(res, 'invalid');
      return;
    }
    if (typeof payload?.userId !== 'string' || payload.userId === '') {
      fail(res, 'invalid');
      return;
    }

    let user: AuthUser | null;
    try {
      user = await users(payload.userId);
    } catch (error) {
      console.error('Auth middleware error:', error instanceof Error ? error.message : 'unknown');
      fail(res, 'error');
      return;
    }
    if (!user) {
      fail(res, 'no_user');
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
