import { Router } from 'express';
import { z } from 'zod';
import type { DoorFactory } from './door.js';
import { DoorError, sendError } from './errors.js';
import { DiagnosticsReport } from '../diagnostics/schema.js';
import type { DiagnosticsStore } from '../diagnostics/store.js';

/**
 * The `/v2` router. Mounted in index.ts behind the auth middleware; public
 * `/v2` routes (sign-in, meta, the public waitlist) are mounted before it in
 * later bytes.
 */
export interface V2RouterDeps {
  diagnostics?: DiagnosticsStore;
}

/** A report is at most 2 MB as sent (docs/team/flows/diagnostics.md). */
export const MAX_REPORT_BYTES = 2 * 1024 * 1024;

export function createV2Router(door: DoorFactory, deps: V2RouterDeps = {}): Router {
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
  const diagnostics = deps.diagnostics;
  if (diagnostics) {
    router.post('/diagnostics', (req, res, next) => {
      const declared = Number(req.header('content-length') ?? 0);
      const key = req.header('Idempotency-Key');
      const reportId = (req.body as { reportId?: unknown } | undefined)?.reportId;
      // Too big as sent, or a key that isn't this report's id: refused before the kit runs.
      if (declared > MAX_REPORT_BYTES || (key !== undefined && key !== reportId)) {
        sendError(res, new DoorError('invalid_request'));
        return;
      }
      next();
    }, door({
      name: 'diagnostics.create',
      bucket: 'write',
      request: DiagnosticsReport,
      call: async (ctx, report) => {
        const saved = await diagnostics.save(ctx.userId, report, ctx.now);
        if (saved.outcome === 'mismatch') throw new DoorError('idempotency_mismatch');
        return saved;
      },
      map: (saved) => ({ reference: saved.reference }),
    }));
  }

  // Any other /v2 path: the envelope's 404, not the old routes' body.
  router.use((_req, res) => {
    sendError(res, new DoorError('not_found'));
  });

  return router;
}
