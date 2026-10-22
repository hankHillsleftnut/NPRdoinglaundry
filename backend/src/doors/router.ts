import { Router } from 'express';
import { z } from 'zod';
import type { DoorFactory } from './door.js';
import { DoorError, sendError } from './errors.js';
import { DiagnosticsReport } from '../diagnostics/schema.js';
import type { DiagnosticsStore } from '../diagnostics/store.js';
import { mountInviteDoors, type InviteDoorDeps } from '../invites/doors.js';
import { mountBriefDoors, type BriefDoorDeps } from '../briefs/doors.js';

/**
 * The `/v2` router. Mounted in index.ts behind the auth middleware; public
 * `/v2` routes (sign-in, meta, the public waitlist) are mounted before it in
 * later bytes.
 */
export interface V2RouterDeps {
  diagnostics: DiagnosticsStore;
  invites: InviteDoorDeps;
  briefs: BriefDoorDeps;
}

/**
 * A report is at most 2 MB (docs/team/flows/diagnostics.md), counted after
 * gzip is undone, so a small compressed body can't unpack past it. app.ts
 * gives this route its own body parser with this limit, ahead of the 10 MB one.
 */
export const MAX_REPORT_BYTES = 2 * 1024 * 1024;

export function createV2Router(door: DoorFactory, deps: V2RouterDeps): Router {
  const router = Router();

  // The sample door: proves the kit end to end without the agent.
  router.get('/ping', door({
    name: 'ping',
    bucket: 'read',
    request: z.object({}).strict(),
    call: async (ctx) => ({ userId: ctx.userId }),
    map: (r) => r,
  }));

  // DG.1: "send a report". The bundle is checked strictly (diagnostics/schema.ts:
  // nothing in it can carry a person's words except their labelled note) and
  // stored under the sender's id for 30 days; the answer is a short reference.
  const { diagnostics } = deps;
  router.post('/diagnostics', (req, res, next) => {
    // The report id is the Idempotency-Key, required as on every write door.
    const key = req.header('Idempotency-Key');
    const reportId = (req.body as { reportId?: unknown } | undefined)?.reportId;
    if (key === undefined || key !== reportId) {
      sendError(res, new DoorError('invalid_request'));
      return;
    }
    next();
  }, door({
    name: 'diagnostics.create',
    bucket: 'write',
    // Anyone signed in may send a report, waitlisted or not (diagnostics.md).
    openToWaitlisted: true,
    request: DiagnosticsReport,
    call: async (ctx, report) => {
      const saved = await diagnostics.save(ctx.userId, report, ctx.now);
      if (saved.outcome === 'mismatch') throw new DoorError('idempotency_mismatch');
      return saved;
    },
    map: (saved) => ({ reference: saved.reference }),
    logCounts: (saved) => ({
      sizeBytes: saved.sizeBytes,
      events: saved.counts.events,
      requests: saved.counts.requests,
      failures: saved.counts.failures,
      crashes: saved.counts.crashes,
      nulledFields: saved.counts.nulledEnvironment,
    }),
  }));

  // Access, the waitlist and invites (BE0.12).
  mountInviteDoors(router, door, deps.invites);

  // Today's brief, the list, one brief, the switch (BE1.3, BE1.3b).
  mountBriefDoors(router, door, deps.briefs);

  // Any other /v2 path: the envelope's 404, not the old routes' body.
  router.use((_req, res) => {
    sendError(res, new DoorError('not_found'));
  });

  return router;
}
