import type { Request, RequestHandler, Response } from 'express';
import type { ZodType, ZodTypeDef } from 'zod';
import type { DoorLogCounts, DoorLogLine } from '../utils/log.js';
import type { AgentCallOptions, AgentDoorClient } from './agent.js';
import { DoorError, fromAgentError, sendError, type DoorErrorCode } from './errors.js';
import { checkSpendCap, type LimitBucket, type Limiter } from './limits.js';

/**
 * A door: one authenticated `/v2` route that safely exposes one brain
 * capability to the app (backend-engineer.md §4). Every door is built here, so
 * the steps below happen in the same order for all of them and none can be
 * skipped:
 *
 *   1. the user comes from the token (`req.user`, set by the auth middleware),
 *      never from the client;
 *   2. the per-user limit for the door's bucket is taken (before anything
 *      else runs, so bad bodies and id probing are limited too); expensive
 *      doors also check the rolling daily spend;
 *   3. the request is validated with the door's zod schema (strict schemas
 *      reject unknown fields, including a client-sent `userId`); a failure is
 *      `invalid_request` with nothing echoed back;
 *   4. `owns` (when the door names a thing by id) answers `not_found`, never
 *      forbidden, so ids can't be probed;
 *   5. `call` runs (usually one agent request), then `map` shapes the answer to
 *      the contract;
 *   6. one content-free log line is written (utils/log.ts).
 * Every failure, thrown or rejected, ends in the error envelope; nothing falls
 * through to the app-wide error handler.
 *
 * Spend: the cap check (step 2) and recording the spend a call reports happen
 * at different times, so several expensive calls started together can each
 * pass the check and together overshoot the cap by up to their combined cost.
 * The overshoot is bounded by the expensive bucket's 10-a-minute limit, and the
 * agent's own spend guard (agent src/pipelines/spend-guard.ts) stays the
 * backstop for everything, including background work no door sees.
 */

export interface DoorContext {
  userId: string;
  /** The agent client; calls through it are timed for the log. */
  agent: AgentDoorClient;
  /** The X-Time-Zone header when it names a real IANA zone; read only until users.time_zone exists (BE0.4). */
  timeZone: string | null;
  now: number;
}

export interface DoorSpec<Req, AgentRes, Res> {
  /** A constant like `entries.create`; it is what the log records. */
  name: string;
  bucket: LimitBucket;
  request: ZodType<Req, ZodTypeDef, unknown>;
  owns?: (ctx: DoorContext, req: Req) => Promise<boolean>;
  call: (ctx: DoorContext, req: Req) => Promise<AgentRes>;
  map: (result: AgentRes, ctx: DoorContext) => Res;
  /** The model spend (dollars) the agent reported for this call, if any. */
  cost?: (result: AgentRes) => number | undefined;
  /** HTTP status on success (default 200). */
  successStatus?: number;
  /** Sizes and counts for the log line on success (numbers only, by type and in the log). */
  logCounts?: (result: AgentRes) => DoorLogCounts;
}

export interface DoorKitDeps {
  agent: AgentDoorClient;
  limiter: Limiter;
  log: { door(line: DoorLogLine): void };
  now: () => number;
  /**
   * Where our own bugs go (Sentry in production): an unexpected throw, or an
   * agent 400 (the door sent something the agent refused). Never the client.
   */
  reportBug: (err: unknown, door: string) => void;
}

function validTimeZone(value: string | undefined): string | null {
  if (!value || value.length > 64) return null;
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: value });
    return value;
  } catch {
    return null;
  }
}

/** The request as one object: path params win over body or query fields of the same name. */
function requestInput(req: Request): unknown {
  const source = req.method === 'GET' || req.method === 'DELETE' ? req.query : req.body;
  const fields = source && typeof source === 'object' && !Array.isArray(source) ? source : {};
  return { ...fields, ...req.params };
}

export function createDoorKit(deps: DoorKitDeps) {
  return function door<Req, AgentRes, Res>(spec: DoorSpec<Req, AgentRes, Res>): RequestHandler {
    return (req: Request, res: Response) => {
      const started = deps.now();
      let agentMs = 0;
      const timedAgent: AgentDoorClient = {
        get: <T>(path: string, opts: AgentCallOptions) => timed(() => deps.agent.get<T>(path, opts)),
        post: <T>(path: string, body: unknown, opts: AgentCallOptions) => timed(() => deps.agent.post<T>(path, body, opts)),
        put: <T>(path: string, body: unknown, opts: AgentCallOptions) => timed(() => deps.agent.put<T>(path, body, opts)),
      };
      async function timed<T>(fn: () => Promise<T>): Promise<T> {
        const t0 = deps.now();
        try {
          return await fn();
        } finally {
          agentMs += deps.now() - t0;
        }
      }

      // Reporting a bug must never itself break the answer.
      const report = (err: unknown) => {
        try {
          deps.reportBug(err, spec.name);
        } catch {
          // Nowhere left to report to; the client still gets its envelope.
        }
      };

      const userId = req.user?.id ?? null;
      const appVersion = req.header('X-App-Version');
      let costUsd: number | undefined;
      let counts: DoorLogCounts = {};

      const finish = (status: number, code?: DoorErrorCode) => {
        deps.log.door({
          door: spec.name,
          userId,
          status,
          ...(code ? { code } : {}),
          ms: deps.now() - started,
          ...(agentMs > 0 ? { agentMs } : {}),
          ...(costUsd !== undefined ? { costUsd } : {}),
          ...(appVersion !== undefined ? { appVersion } : {}),
          ...counts,
        });
      };

      const run = async () => {
        if (!userId) throw new DoorError('unauthenticated');
        const ctx: DoorContext = { userId, agent: timedAgent, timeZone: validTimeZone(req.header('X-Time-Zone')), now: started };

        const taken = deps.limiter.take(userId, spec.bucket, started);
        if (!taken.ok) throw new DoorError('rate_limited', { retryAfterSeconds: taken.retryAfterSeconds });
        if (spec.bucket === 'expensive') {
          const spend = checkSpendCap(deps.limiter, userId, started);
          if (spend.over) throw new DoorError('spend_limited', { retryAfterSeconds: spend.retryAfterSeconds });
        }

        const parsed = spec.request.safeParse(requestInput(req));
        if (!parsed.success) throw new DoorError('invalid_request');

        if (spec.owns && !(await spec.owns(ctx, parsed.data))) throw new DoorError('not_found');

        let result: AgentRes;
        try {
          result = await spec.call(ctx, parsed.data);
        } catch (err) {
          if (err instanceof DoorError) throw err;
          const mapped = fromAgentError(err);
          if (mapped.isBug) report(err);
          throw mapped.error;
        }
        const reported = spec.cost?.(result);
        if (typeof reported === 'number' && Number.isFinite(reported) && reported > 0) {
          costUsd = reported;
          deps.limiter.recordSpend(userId, reported, deps.now());
        }
        const data = spec.map(result, ctx);
        if (spec.logCounts) counts = spec.logCounts(result);
        res.status(spec.successStatus ?? 200).json({ success: true, data });
        finish(spec.successStatus ?? 200);
      };

      run().catch((err: unknown) => {
        if (res.headersSent) {
          report(err);
          finish(res.statusCode, 'internal');
          return;
        }
        if (!(err instanceof DoorError)) report(err);
        const sent = sendError(res, err);
        finish(sent.status, sent.code);
      });
    };
  };
}

export type DoorFactory = ReturnType<typeof createDoorKit>;
