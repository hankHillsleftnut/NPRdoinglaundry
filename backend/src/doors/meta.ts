import { Router, type Request, type Response } from 'express';
import { DoorError, sendError } from './errors.js';
import type { Limiter } from './limits.js';
import type { DoorLogLine } from '../utils/log.js';
import type { AppVersions } from './versions.js';

/**
 * `GET /v2/meta` (public; contract 00 §5): the version floor, the newest
 * version, the server's clock and where it runs, so a test build can show
 * which server it's on and an old build can be sent to update before it
 * signs in. No token, no user, no database; limited per address. This door
 * never answers update_required: it is how an old app learns that it is one.
 */
export interface MetaRouteDeps {
  versions: AppVersions;
  limiter: Limiter;
  now: () => number;
  log: { door(line: DoorLogLine): void };
}

export interface MetaResponse {
  minVersion: string;
  latestVersion: string;
  serverTime: string;
  environment: AppVersions['environment'];
}

export function createMetaRouter(deps: MetaRouteDeps): Router {
  const router = Router();
  router.get('/', (req: Request, res: Response) => {
    const started = deps.now();
    const taken = deps.limiter.take(`ip:${req.ip ?? 'unknown'}`, 'read', started);
    if (!taken.ok) {
      const sent = sendError(res, new DoorError('rate_limited', { retryAfterSeconds: taken.retryAfterSeconds }));
      deps.log.door({ door: 'meta', userId: null, status: sent.status, code: sent.code, ms: deps.now() - started });
      return;
    }
    const data: MetaResponse = {
      minVersion: deps.versions.minVersion,
      latestVersion: deps.versions.latestVersion,
      serverTime: new Date(started).toISOString(),
      environment: deps.versions.environment,
    };
    res.setHeader('Cache-Control', 'no-store');
    res.status(200).json({ success: true, data });
    deps.log.door({ door: 'meta', userId: null, status: 200, ms: deps.now() - started });
  });
  return router;
}
