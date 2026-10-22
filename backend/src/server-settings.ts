import type { Express, RequestHandler } from 'express';
import type { Server } from 'node:http';
import rateLimit from 'express-rate-limit';

/**
 * Settings the server needs to know who its clients are and to keep its
 * connections healthy behind Render's proxy. Kept out of index.ts so each can
 * be tested on a bare Express app.
 */

/**
 * Render terminates TLS at one proxy, so without this every request's `req.ip`
 * is the proxy's address and the IP limiter puts every user in one bucket.
 * Exactly one hop is trusted: a client can't spoof its address by sending its
 * own X-Forwarded-For, because only the last entry (added by Render) is used.
 */
export function trustRenderProxy(app: Express): void {
  app.set('trust proxy', 1);
}

/**
 * Paths the global IP limiter never counts: the health check (Render polls it)
 * and `/v2`, whose doors have their own per-user limits (BE0.1).
 */
export function skipsGlobalLimit(path: string): boolean {
  return path === '/health' || path === '/v2' || path.startsWith('/v2/');
}

export function globalLimiter(opts: { windowMs: number; max: number }): RequestHandler {
  return rateLimit({
    windowMs: opts.windowMs,
    max: opts.max,
    skip: (req) => skipsGlobalLimit(req.path),
    message: {
      success: false,
      error: 'Too many requests, please try again later',
    },
  });
}

/**
 * `headersTimeout` must be above `keepAliveTimeout`, or Node can close a reused
 * connection while the proxy is sending the next request on it, which the
 * proxy reports as a 502.
 */
export const SERVER_TIMEOUTS = {
  /** Podcast generation with v3 TTS can take several minutes. */
  timeout: 300_000,
  keepAliveTimeout: 120_000,
  headersTimeout: 125_000,
} as const;

export function applyServerTimeouts(server: Server): void {
  server.timeout = SERVER_TIMEOUTS.timeout;
  server.keepAliveTimeout = SERVER_TIMEOUTS.keepAliveTimeout;
  server.headersTimeout = SERVER_TIMEOUTS.headersTimeout;
}
