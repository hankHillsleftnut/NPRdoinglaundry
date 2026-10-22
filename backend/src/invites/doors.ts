import type { Request, Response, NextFunction, Router } from 'express';
import { z } from 'zod';
import type { DoorFactory } from '../doors/door.js';
import { DoorError, sendError } from '../doors/errors.js';
import type { Limiter } from '../doors/limits.js';
import type { AccessStore } from '../access/store.js';
import { localDay } from '../services/dedup-key.js';
import { hashCode, inviteLink, mintCodes, normaliseCode, openCode } from './codes.js';
import type { InviteFace, InviteStore } from './store.js';

/**
 * The signed-in invite doors (BE0.12 and BE2.0b, contract 00 §4 and 01 §2):
 *   GET  /v2/access          your access state, and whether you're waiting
 *   POST /v2/waitlist        join the waitlist (once; waitlisted people only)
 *   POST /v2/invites/check   what the ticket says, or why it can't be used; spends nothing
 *                            (20 per 10 minutes per person, 60 per address, its own buckets)
 *   POST /v2/invites/redeem  let yourself in with a code (5 per 10 minutes per person, 20 per address);
 *                            the tear: idempotent for the redeemer, and by Idempotency-Key
 *   GET  /v2/invites/mine    your three invites, with their links while unused
 * All five are open to waitlisted people: contract 00 §4 keeps its own doors
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
/** Check and redeem take the same body (fixtures 00/redeem.request.json, 01/invite.check.request.json). */
export const CodeBody = z.object({ code: z.string().min(1).max(64) }).strict();

/** The tear's key is the UUID the app makes at touch-down (contract 01 §2.3), sent in either case. */
const IDEMPOTENCY_KEY = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const DAY = /^\d{4}-\d{2}-\d{2}$/;
const TicketFace = z.object({
  from: z.string().nullable(),
  kind: z.enum(['member', 'founder', 'review']),
  serial: z.number().int().positive(),
  issuedOn: z.string().regex(DAY),
}).strict();

/** What the doors answer (contract 01 §2.2 and §2.3); the 01 fixtures are checked against these. */
export const CheckResponse = z.union([
  z.object({ usable: z.literal(true), face: TicketFace }).strict(),
  z.object({ usable: z.literal(false), reason: z.literal('yours'), face: TicketFace }).strict(),
  z.object({ usable: z.literal(false), reason: z.literal('alreadyIn'), face: z.null() }).strict(),
]);
export const RedeemResponse = z.object({
  access: z.object({ state: z.enum(['waitlisted', 'approved', 'member', 'staff', 'suspended']) }).strict(),
  invitedBy: z.string().nullable(),
  invite: z.object({ serial: z.number().int().positive(), redeemedOn: z.string().regex(DAY) }).strict().nullable(),
}).strict();
export type CheckResponse = z.infer<typeof CheckResponse>;
export type RedeemResponse = z.infer<typeof RedeemResponse>;

/**
 * The day an invite was made, for the face. Contract 01 §1 says the inviter's
 * zone, but nothing writes users.time_zone yet (BE2.0b contract pass, Q5), so
 * it is the UTC date until something does; near midnight it can be a day off.
 */
export function issuedOn(face: InviteFace): string {
  return localDay(new Date(face.createdAt), 'UTC');
}

const toFace = (face: InviteFace) => ({ from: face.from, kind: face.kind, serial: face.serial, issuedOn: issuedOn(face) });

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
  // signing in as several people. Check and redeem count in separate buckets,
  // so looking at a code never uses up the tear's tries.
  const perAddress = (bucket: 'redeemAddress' | 'inviteCheckAddress') => (req: Request, res: Response, next: NextFunction) => {
    const taken = deps.limiter.take(`ip:${req.ip ?? 'unknown'}`, bucket, deps.now());
    if (!taken.ok) {
      sendError(res, new DoorError('rate_limited', { retryAfterSeconds: taken.retryAfterSeconds }));
      return;
    }
    next();
  };

  // The print (contract 01 §2.2): read-only, and the sealed code is never
  // opened. The decision order is redeem's, so the check always agrees with
  // the tear that follows; "yours" comes before "already in" because after the
  // tear the caller is approved (a relaunch between the tear and "begin").
  router.post('/invites/check', perAddress('inviteCheckAddress'), door({
    name: 'invites.check',
    bucket: 'inviteCheck',
    openToWaitlisted: true,
    request: CodeBody,
    call: async (ctx, body) => {
      const code = normaliseCode(body.code);
      if (!code) throw new DoorError('invite_invalid');
      const result = await deps.invites.check({ userId: ctx.userId, codeHash: hashCode(code), nowIso: new Date(ctx.now).toISOString() });
      switch (result.outcome) {
        case 'usable': return { usable: true as const, face: toFace(result.face) };
        case 'yours': return { usable: false as const, reason: 'yours' as const, face: toFace(result.face) };
        case 'already_in': return { usable: false as const, reason: 'alreadyIn' as const, face: null };
        case 'used': throw new DoorError('invite_used');
        case 'expired': throw new DoorError('invite_expired');
        case 'no_user': throw new DoorError('unauthenticated');
        default: throw new DoorError('invite_invalid');
      }
    },
    map: (r): CheckResponse => r,
  }));

  // The tear (contract 00 §4, amended by 01 §2.3). Idempotent for the redeemer
  // twice over: the same person redeeming a code they already spent gets the
  // same 200 (the SQL's own-retry path, whatever key they send), and the
  // Idempotency-Key the app makes at touch-down is kept on the spent row, so a
  // retry with a lost response is answered before the code is looked up and
  // the same key with another code is a mismatch. The key is optional in
  // Beta 1 (BE0.12's clients send none); when sent it must be a UUID, as the
  // row stores it. A replay counts toward the limit like any request.
  router.post('/invites/redeem', perAddress('redeemAddress'), door({
    name: 'invites.redeem',
    bucket: 'redeem',
    openToWaitlisted: true,
    request: CodeBody,
    call: async (ctx, body) => {
      if (ctx.idempotencyKey !== null && !IDEMPOTENCY_KEY.test(ctx.idempotencyKey)) throw new DoorError('invalid_request');
      const code = normaliseCode(body.code);
      if (!code) throw new DoorError('invite_invalid');
      if (!deps.codeKey) throw new Error('invites.redeem: INVITE_CODE_KEY is not set');
      // The three new invites are minted first, so the redeem is one transaction.
      const fresh = mintCodes(INVITES_EACH, deps.codeKey);
      const result = await deps.invites.redeem({
        userId: ctx.userId, codeHash: hashCode(code), nowIso: new Date(ctx.now).toISOString(), newHashes: fresh.hashes, newSealed: fresh.sealed,
        redeemKey: ctx.idempotencyKey === null ? null : ctx.idempotencyKey.toLowerCase(),
        // The stub's date: the tear's calendar day where the person is (X-Time-Zone), UTC without a usable header.
        redeemedOn: localDay(new Date(ctx.now), ctx.timeZone),
      });
      switch (result.outcome) {
        case 'redeemed': return { state: 'approved' as const, invitedBy: result.invitedBy, invite: { serial: result.serial, redeemedOn: result.redeemedOn } };
        case 'already_in': return { state: result.access, invitedBy: null, invite: null };
        case 'mismatch': throw new DoorError('idempotency_mismatch');
        case 'used': throw new DoorError('invite_used');
        case 'expired': throw new DoorError('invite_expired');
        case 'no_user': throw new DoorError('unauthenticated');
        default: throw new DoorError('invite_invalid');
      }
    },
    map: (r): RedeemResponse => ({ access: { state: r.state }, invitedBy: r.invitedBy, invite: r.invite }),
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
