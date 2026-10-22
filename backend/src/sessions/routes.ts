import { Router, type Request, type RequestHandler, type Response } from 'express';
import { z } from 'zod';
import type { UserLookup } from '../middleware/auth.js';
import { DoorError, sendError, type DoorErrorCode } from '../doors/errors.js';
import type { Limiter } from '../doors/limits.js';
import type { DoorLogLine } from '../utils/log.js';
import type { SessionStore } from './store.js';
import { hashRefreshToken, issueAccessToken, newRefreshToken, openGrace, sealGrace } from './tokens.js';

/**
 * `POST /v2/auth/refresh` (public) and `POST /v2/auth/signout` (signed in),
 * contract 00 §3 (BE0.4b).
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
}

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
      const result = await deps.store.rotate({
        tokenHash, newHash: next.hash, nowIso: new Date(started).toISOString(), refreshCiphertext: sealGrace(next.plain, deps.secret),
      });
      if (result.outcome === 'revoked') throw new DoorError('session_revoked');

      // A retry inside the grace window gets the same successor refresh token;
      // either way the access token is freshly issued (none is ever stored).
      const refreshToken = result.outcome === 'rotated' ? next.plain : openGrace(result.refreshCiphertext, deps.secret);
      const access = issueAccessToken({ userId: user.id, tokenVersion: user.tokenVersion }, deps.secret, started);
      const pair = { accessToken: access.token, refreshToken, accessTokenExpiresAt: access.expiresAt };
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
