import type { Router } from 'express';
import { z } from 'zod';
import type { DoorFactory } from '../doors/door.js';
import { DoorError } from '../doors/errors.js';
import type { BriefRow, BriefStore } from './store.js';
import type { SignAudio } from './audio.js';
import { briefResponse, decodeCursor, encodeCursor, hasReadyAudio, nextBriefAt, stillMaking, type SignedLink } from './map.js';

/**
 * Today's brief (BE1.3, BE1.3b; contract 02 §3, 03 §6):
 *   GET /v2/briefs/latest   { brief, enabled, nextAt }   the brief card
 *   GET /v2/briefs          { briefs, nextCursor }       the list, newest first, no audio
 *   GET /v2/briefs/:id      { brief }                    one brief, with audio when ready (03 §6)
 *   PUT /v2/briefs/enabled  { enabled }                  the switch
 * All read and write the shared database (daily_briefs, users): the brain is
 * never called, so the card keeps working when the brain is down.
 */
export interface BriefDoorDeps {
  briefs: BriefStore;
  signAudio: SignAudio;
  /** `HH:MM` UTC when briefs run (DAILY_BRIEF_UTC_TIME); null where none run. */
  runTimeUtc: string | null;
}

const Empty = z.object({}).strict();
const ListQuery = z.object({
  cursor: z.string().min(1).max(200).optional(),
  limit: z.coerce.number().int().min(1).max(50).optional(),
}).strict();
const ById = z.object({ id: z.string().uuid() }).strict();
const EnabledBody = z.object({ enabled: z.boolean() }).strict();

export const LIST_DEFAULT_LIMIT = 20;

export function mountBriefDoors(router: Router, door: DoorFactory, deps: BriefDoorDeps): void {
  const link = async (row: BriefRow, nowMs: number): Promise<SignedLink | null> =>
    (hasReadyAudio(row) ? deps.signAudio(row.audioPath!, nowMs) : null);

  router.get('/briefs/latest', door({
    name: 'briefs.latest',
    bucket: 'read',
    request: Empty,
    call: async (ctx) => {
      const enabled = await deps.briefs.enabled(ctx.userId);
      if (enabled === null) throw new DoorError('unauthenticated');
      const nextAt = nextBriefAt(ctx.now, deps.runTimeUtc);
      // Off: no brief, whatever is stored (the person turned it off).
      if (!enabled) return { row: null, link: null, enabled, nextAt };
      const row = await deps.briefs.latest(ctx.userId);
      // Being voiced: not yet today's brief (briefs are audio); after the grace, the text is served.
      if (!row || stillMaking(row, ctx.now)) return { row: null, link: null, enabled, nextAt };
      return { row, link: await link(row, ctx.now), enabled, nextAt };
    },
    map: (r) => ({ brief: r.row ? briefResponse(r.row, r.link) : null, enabled: r.enabled, nextAt: r.nextAt }),
  }));

  // Before `/briefs/:id`, so the word is never read as an id.
  router.put('/briefs/enabled', door({
    name: 'briefs.enabled',
    bucket: 'write',
    request: EnabledBody,
    call: async (ctx, body) => {
      if (!(await deps.briefs.setEnabled(ctx.userId, body.enabled))) throw new DoorError('unauthenticated');
      return { enabled: body.enabled };
    },
    map: (r) => r,
  }));

  router.get('/briefs', door({
    name: 'briefs.list',
    bucket: 'read',
    request: ListQuery,
    call: async (ctx, q) => {
      const before = q.cursor === undefined ? null : decodeCursor(q.cursor);
      if (q.cursor !== undefined && before === null) throw new DoorError('invalid_request');
      const limit = q.limit ?? LIST_DEFAULT_LIMIT;
      const rows = await deps.briefs.list(ctx.userId, before, limit + 1);
      const page = rows.slice(0, limit);
      return { page, nextCursor: rows.length > limit ? encodeCursor(page[page.length - 1]!.briefDate) : null };
    },
    // No audio in the list (contract 02 §3): every row maps as text.
    map: (r) => ({ briefs: r.page.map((row) => briefResponse(row, null)), nextCursor: r.nextCursor }),
  }));

  router.get('/briefs/:id', door({
    name: 'briefs.get',
    bucket: 'read',
    request: ById,
    owns: async (ctx, req) => (await deps.briefs.byId(ctx.userId, req.id)) !== null,
    call: async (ctx, req) => {
      const row = await deps.briefs.byId(ctx.userId, req.id);
      if (!row) throw new DoorError('not_found');
      return { row, link: await link(row, ctx.now) };
    },
    map: (r) => ({ brief: briefResponse(r.row, r.link) }),
  }));
}
