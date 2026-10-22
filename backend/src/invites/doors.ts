import type { Request, Response, NextFunction, Router } from 'express';
import { z } from 'zod';
import type { DoorFactory } from '../doors/door.js';
import { DoorError, sendError } from '../doors/errors.js';
import type { Limiter } from '../doors/limits.js';
import type { AccessStore } from '../access/store.js';
import { hashCode, inviteLink, mintCodes, normaliseCode, openCode } from './codes.js';
import type { InviteStore } from './store.js';

/**
 * The signed-in invite doors (BE0.12, contract 00 §4):
 *   GET  /v2/access          your access state, and whether you're waiting
 *   POST /v2/waitlist        join the waitlist (once; waitlisted people only)
 *   POST /v2/invites/redeem  let yourself in with a code (5 per 10 minutes per person, 20 per address)
 *   GET  /v2/invites/mine    your three invites, with their links while unused
 * All four are open to waitlisted people: contract 00 §4 keeps its own doors
 * open (a waitlisted person simply has no invites yet).
 */
export interface InviteDoorDeps {
  access: AccessStore;
  invites: InviteStore;
  limiter: Limiter;
  now: () => number;
  /** INVITE_CODE_KEY; null until the founder sets it (then minting refuses). */
  codeKey: string | null;
  baseUrl: string;
}

/** Each person who gets in receives this many single-use invites (founder, 21 Oct). */
export const INVITES_EACH = 3;

/**
 * The link for a sealed code, or null when it can't be opened: a code sealed
 * under an earlier INVITE_CODE_KEY (the key was rotated) or a damaged value
 * loses its link, and "your invites" still answers instead of a 500.
 */
export function linkFor(sealed: string, codeKey: string, baseUrl: string): string | null {
  try {
    return inviteLink(baseUrl, openCode(sealed, codeKey));
  } catch {
    return null;
  }
}

const Empty = z.object({}).strict();
const WaitlistBody = z.object({ reason: z.string().max(280).nullable().optional() }).strict();
const RedeemBody = z.object({ code: z.string().min(1).max(64) }).strict();

export function mountInviteDoors(router: Router, door: DoorFactory, deps: InviteDoorDeps): void {
  router.get('/access', door({
    name: 'access.get',
    bucket: 'read',
    openToWaitlisted: true,
    request: Empty,
    call: async (ctx) => ({ onWaitlist: await deps.access.onWaitlist(ctx.userId) }),
    map: (r, ctx) => ({ state: ctx.access, onWaitlist: r.onWaitlist }),
  }));

  router.post('/waitlist', door({
    name: 'waitlist.join',
    bucket: 'write',
    openToWaitlisted: true,
    request: WaitlistBody,
    call: async (ctx, body) => ({
      onWaitlist: await deps.access.joinWaitlist(ctx.userId, body.reason ?? null, new Date(ctx.now).toISOString()),
    }),
    map: (r) => r,
  }));

  // Per address as well as per person: one device can't try codes faster by
  // signing in as several people.
  const perAddress = (req: Request, res: Response, next: NextFunction) => {
    const taken = deps.limiter.take(`ip:${req.ip ?? 'unknown'}`, 'redeemAddress', deps.now());
    if (!taken.ok) {
      sendError(res, new DoorError('rate_limited', { retryAfterSeconds: taken.retryAfterSeconds }));
      return;
    }
    next();
  };
  router.post('/invites/redeem', perAddress, door({
    name: 'invites.redeem',
    bucket: 'redeem',
    openToWaitlisted: true,
    request: RedeemBody,
    call: async (ctx, body) => {
      const code = normaliseCode(body.code);
      if (!code) throw new DoorError('invite_invalid');
      if (!deps.codeKey) throw new Error('invites.redeem: INVITE_CODE_KEY is not set');
      // The three new invites are minted first, so the redeem is one transaction.
      const fresh = mintCodes(INVITES_EACH, deps.codeKey);
      const result = await deps.invites.redeem({
        userId: ctx.userId, codeHash: hashCode(code), nowIso: new Date(ctx.now).toISOString(), newHashes: fresh.hashes, newSealed: fresh.sealed,
      });
      switch (result.outcome) {
        case 'redeemed': return { state: 'approved' as const, invitedBy: result.invitedBy };
        case 'already_in': return { state: result.access, invitedBy: null };
        case 'used': throw new DoorError('invite_used');
        case 'expired': throw new DoorError('invite_expired');
        case 'no_user': throw new DoorError('unauthenticated');
        default: throw new DoorError('invite_invalid');
      }
    },
    map: (r) => ({ access: { state: r.state }, invitedBy: r.invitedBy }),
  }));

  router.get('/invites/mine', door({
    name: 'invites.mine',
    bucket: 'read',
    openToWaitlisted: true,
    request: Empty,
    call: (ctx) => deps.invites.mine(ctx.userId),
    map: (rows) => ({
      invites: rows.map((r) => ({
        id: r.id,
        link: !r.used && r.sealed && deps.codeKey ? linkFor(r.sealed, deps.codeKey, deps.baseUrl) : null,
        createdAt: r.createdAt,
        state: r.used ? 'used' : 'unused',
        usedBy: r.used ? r.usedBy : null,
      })),
    }),
  }));
}
