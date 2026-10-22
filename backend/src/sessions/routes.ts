import { Router, type Request, type RequestHandler, type Response } from 'express';
import { z } from 'zod';
import type { UserLookup } from '../middleware/auth.js';
import { DoorError, sendError, type DoorErrorCode } from '../doors/errors.js';
import type { Limiter } from '../doors/limits.js';
import type { DoorLogLine } from '../utils/log.js';
import type { AppleSignIn } from '../services/apple-auth.js';
import { isRejectedAppleToken } from '../services/apple-errors.js';
import { startSession, type SessionStore } from './store.js';
import { hashNonce, hashRefreshToken, issueAccessToken, newRefreshToken, openGrace, sealGrace } from './tokens.js';

/**
 * `POST /v2/auth/apple` and `POST /v2/auth/refresh` (public) and
 * `POST /v2/auth/signout` (signed in), contract 00 §3 (BE0.4b, BE0.4c).
 *
 * Refresh trades a refresh token for a new pair and retires the old one. A
 * retry of the same token within 30 seconds gets the same pair (a dropped
 * response must not sign the person out); reuse after that ends the device's
 * whole session (someone else has a copy). Anything that isn't a live session
 * is `session_revoked`, and the app signs out.
 *
 * Neither the refresh token nor its hash is ever logged.
 */
export interface SessionRouteDeps {
  store: SessionStore;
  users: UserLookup;
  limiter: Limiter;
  now: () => number;
  secret: string;
  log: { door(line: DoorLogLine): void };
  /** The signed-in check for signout (the /v2 envelope middleware). */
  auth: RequestHandler;
  /** Our own bugs (an unexpected throw) go here, never to the client. */
  reportBug: (err: unknown, door: string) => void;
  /** Verifies an Apple identity token (services/apple-auth.ts). */
  verifyApple: (identityToken: string) => Promise<AppleSignIn>;
  /** Finds or creates the account for an Apple subject. */
  accounts: { findOrCreateApple(appleUserId: string, profile: { email?: string; firstName?: string }): Promise<{ userId: string; isNew: boolean }> };
}

const AppleBody = z.object({
  identityToken: z.string().min(1).max(8192),
  // Kept for Apple token revocation (BE0.5); required now so the app always sends it.
  authorizationCode: z.string().min(1).max(1024),
  rawNonce: z.string().min(16).max(128),
  fullName: z.object({
    givenName: z.string().max(100).nullable().optional(),
    familyName: z.string().max(100).nullable().optional(),
  }).strict().nullable().optional(),
  email: z.string().email().max(320).nullable().optional(),
}).strict();

/** 32 random bytes, base64url: 43 characters. Anything far longer isn't one of ours. */
const RefreshBody = z.object({ refreshToken: z.string().min(1).max(128) }).strict();

export function createSessionRouter(deps: SessionRouteDeps): Router {
  const router = Router();

  const respond = (name: string, userId: string | null, started: number) => ({
    ok(res: Response, data: unknown) {
      res.status(200).json({ success: true, data });
      deps.log.door({ door: name, userId, status: 200, ms: deps.now() - started });
    },
    fail(res: Response, err: unknown) {
      if (!(err instanceof DoorError)) {
        try {
          deps.reportBug(err, name);
        } catch {
          // Nowhere left to report to; the client still gets its envelope.
        }
      }
      const sent = sendError(res, err);
      deps.log.door({ door: name, userId, status: sent.status, code: sent.code as DoorErrorCode, ms: deps.now() - started });
    },
  });

  /**
   * POST /v2/auth/apple (public): sign in with Apple. The token is verified
   * (Apple's keys, issuer, audience, RS256), its nonce must be the hash of
   * the raw nonce the app sent and is accepted once, and the account is the
   * Apple subject's (created on first sign-in with the name Apple sends once).
   */
  router.post('/apple', (req: Request, res: Response) => {
    const started = deps.now();
    let userId: string | null = null;
    const out = () => respond('auth.apple', userId, started);
    void (async () => {
      const taken = deps.limiter.take(`ip:${req.ip ?? 'unknown'}`, 'write', started);
      if (!taken.ok) throw new DoorError('rate_limited', { retryAfterSeconds: taken.retryAfterSeconds });
      const parsed = AppleBody.safeParse(req.body ?? {});
      if (!parsed.success) throw new DoorError('invalid_request');
      const body = parsed.data;

      let verified: AppleSignIn;
      try {
        verified = await deps.verifyApple(body.identityToken);
      } catch (err) {
        if (isRejectedAppleToken(err)) throw new DoorError('invalid_credentials');
        throw err;
      }
      // The nonce binds this token to this sign-in attempt, once (replay protection).
      if (!verified.nonce || verified.nonce !== hashNonce(body.rawNonce)) throw new DoorError('invalid_credentials');
      if (!(await deps.store.useNonce(verified.nonce, new Date(started).toISOString()))) throw new DoorError('invalid_credentials');

      // Apple's own email claim wins over the one the app passes along.
      const email = verified.email ?? body.email ?? undefined;
      const firstName = body.fullName?.givenName ?? undefined;
      const account = await deps.accounts.findOrCreateApple(verified.appleUserId, {
        ...(email ? { email } : {}),
        ...(firstName ? { firstName } : {}),
      });
      userId = account.userId;
      const user = await deps.users(account.userId);
      if (!user || user.tokenVersion === undefined) throw new Error('auth.apple: the account has no token version (is migration 005 applied?)');

      const session = await startSession(deps.store, { userId: user.id, tokenVersion: user.tokenVersion }, deps.secret, started);
      out().ok(res, {
        ...session,
        user: { id: user.id, firstName: user.firstName ?? null, isNew: account.isNew },
        // Access states arrive with invites (BE0.12); until then everyone signed in is a member.
        access: { state: 'member' },
      });
    })().catch((err: unknown) => out().fail(res, err));
  });

  router.post('/refresh', (req: Request, res: Response) => {
    const started = deps.now();
    const out = respond('auth.refresh', null, started);
    void (async () => {
      // Public: limited per address (behind Render's one trusted proxy).
      const taken = deps.limiter.take(`ip:${req.ip ?? 'unknown'}`, 'write', started);
      if (!taken.ok) throw new DoorError('rate_limited', { retryAfterSeconds: taken.retryAfterSeconds });

      const parsed = RefreshBody.safeParse(req.body ?? {});
      if (!parsed.success) throw new DoorError('invalid_request');
      const tokenHash = hashRefreshToken(parsed.data.refreshToken);

      const ownerId = await deps.store.ownerOf(tokenHash);
      if (!ownerId) throw new DoorError('session_revoked');
      const user = await deps.users(ownerId);
      if (!user || user.tokenVersion === undefined) throw new DoorError('session_revoked');

      const next = newRefreshToken();
      const access = issueAccessToken({ userId: user.id, tokenVersion: user.tokenVersion }, deps.secret, started);
      const result = await deps.store.rotate({
        tokenHash, newHash: next.hash, nowIso: new Date(started).toISOString(),
        accessToken: access.token, accessExpiresAt: access.expiresAt, refreshCiphertext: sealGrace(next.plain, deps.secret),
      });
      if (result.outcome === 'revoked') throw new DoorError('session_revoked');

      const pair = result.outcome === 'rotated'
        ? { accessToken: access.token, refreshToken: next.plain, accessTokenExpiresAt: access.expiresAt }
        : { accessToken: result.accessToken, refreshToken: openGrace(result.refreshCiphertext, deps.secret), accessTokenExpiresAt: result.accessExpiresAt };
      out.ok(res, {
        ...pair,
        user: { id: user.id, firstName: user.firstName ?? null, isNew: false },
        // Access states arrive with invites (BE0.12); until then everyone signed in is a member.
        access: { state: 'member' },
      });
    })().catch((err: unknown) => out.fail(res, err));
  });

  router.post('/signout', deps.auth, (req: Request, res: Response) => {
    const started = deps.now();
    const userId = req.user?.id ?? null;
    const out = respond('auth.signout', userId, started);
    void (async () => {
      if (!userId) throw new DoorError('unauthenticated');
      const taken = deps.limiter.take(userId, 'write', started);
      if (!taken.ok) throw new DoorError('rate_limited', { retryAfterSeconds: taken.retryAfterSeconds });
      const parsed = RefreshBody.safeParse(req.body ?? {});
      if (!parsed.success) throw new DoorError('invalid_request');
      const tokenHash = hashRefreshToken(parsed.data.refreshToken);
      // Only your own device: another person's session is not found, never ended.
      const ownerId = await deps.store.ownerOf(tokenHash);
      if (ownerId !== null && ownerId !== userId) throw new DoorError('not_found');
      if (ownerId) await deps.store.revoke(tokenHash, new Date(started).toISOString());
      // Signing out a session that's already gone is still "signed out".
      out.ok(res, { signedOut: true });
    })().catch((err: unknown) => out.fail(res, err));
  });

  return router;
}
