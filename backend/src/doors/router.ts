import { Router } from 'express';
import { z } from 'zod';
import type { DoorFactory } from './door.js';
import { DoorError, sendError } from './errors.js';

/**
 * The `/v2` router. Mounted in index.ts behind the auth middleware; public
 * `/v2` routes (sign-in, meta, the public waitlist) are mounted before it in
 * later bytes.
 */
export function createV2Router(door: DoorFactory): Router {
  const router = Router();

  // The sample door: proves the kit end to end without the agent.
  router.get('/ping', door({
    name: 'ping',
    bucket: 'read',
    request: z.object({}).strict(),
    call: async (ctx) => ({ userId: ctx.userId }),
    map: (r) => r,
  }));

  // Any other /v2 path: the envelope's 404, not the old routes' body.
  router.use((_req, res) => {
    sendError(res, new DoorError('not_found'));
  });

  return router;
}
