import type { NextFunction, Request, Response } from 'express';

/**
 * The error envelope every `/v2` door answers with (contract 00 §2):
 * `{ success: false, error: { code, message, retryAfterSeconds? } }`.
 *
 * Codes are a closed list; each has one HTTP status and one plain-words
 * message, safe to show as is, word for word the contract's fixtures
 * (docs/team/contracts/fixtures/00/error.*.json, checked by
 * tests/contract-00-fixtures.test.ts). Nothing from the agent is ever forwarded: its
 * messages can carry raw Postgres text (agent-api-reference §11).
 */
export const DOOR_ERRORS = {
  invalid_request: { status: 400, message: "That didn't look right." },
  invalid_credentials: { status: 401, message: "That didn't work. Nothing is lost; try again." },
  unauthenticated: { status: 401, message: "Please sign in again." },
  session_revoked: { status: 401, message: "Please sign in again." },
  invite_required: { status: 403, message: "You'll need an invite to get in." },
  suspended: { status: 403, message: "Your account is paused." },
  not_found: { status: 404, message: "That isn't here any more." },
  idempotency_mismatch: { status: 409, message: "That was already sent with different words." },
  update_required: { status: 426, message: "There's a new version of Retrospect." },
  rate_limited: { status: 429, message: "Too many tries. Try again in a minute." },
  spend_limited: { status: 429, message: "I've done all I can today. This comes back tomorrow." },
  upstream_timeout: { status: 504, message: "That took too long. Try again." },
  upstream_unavailable: { status: 502, message: "Something's down on our side. Try again soon." },
  internal: { status: 500, message: "Something went wrong on our side." },
  // Contract 00 §4: redeeming an invite.
  invite_invalid: { status: 400, message: "That code doesn't look right." },
  invite_used: { status: 400, message: "That invite has already been used." },
  invite_expired: { status: 400, message: "That invite has expired." },
} as const satisfies Record<string, { status: number; message: string }>;

export type DoorErrorCode = keyof typeof DOOR_ERRORS;
export const DOOR_ERROR_CODES = Object.keys(DOOR_ERRORS) as DoorErrorCode[];

/** Only these two carry retryAfterSeconds (contract 00 §2). */
const RETRYABLE: ReadonlySet<DoorErrorCode> = new Set(['rate_limited', 'spend_limited']);

export class DoorError extends Error {
  readonly code: DoorErrorCode;
  readonly status: number;
  readonly retryAfterSeconds: number | undefined;

  constructor(code: DoorErrorCode, opts: { retryAfterSeconds?: number } = {}) {
    super(DOOR_ERRORS[code].message);
    this.name = 'DoorError';
    this.code = code;
    this.status = DOOR_ERRORS[code].status;
    this.retryAfterSeconds = RETRYABLE.has(code) ? opts.retryAfterSeconds : undefined;
  }
}

export interface ErrorBody {
  success: false;
  error: { code: DoorErrorCode; message: string; retryAfterSeconds?: number };
}

export function errorBody(err: DoorError): ErrorBody {
  return {
    success: false,
    error: {
      code: err.code,
      message: DOOR_ERRORS[err.code].message,
      ...(err.retryAfterSeconds !== undefined ? { retryAfterSeconds: err.retryAfterSeconds } : {}),
    },
  };
}

/** Writes the envelope. Anything that isn't a DoorError is `internal`; its message never leaves. */
export function sendError(res: Response, err: unknown): DoorError {
  const doorError = err instanceof DoorError ? err : new DoorError('internal');
  if (doorError.retryAfterSeconds !== undefined) res.setHeader('Retry-After', String(doorError.retryAfterSeconds));
  res.status(doorError.status).json(errorBody(doorError));
  return doorError;
}

/** A failed agent call, as the door's agent client reports it (agent.ts). */
export type AgentFailure =
  | { kind: 'http'; status: number; spentUsd?: number }
  | { kind: 'timeout' }
  | { kind: 'network' };

export class AgentCallError extends Error {
  readonly failure: AgentFailure;
  constructor(failure: AgentFailure) {
    super(failure.kind === 'http' ? `agent answered ${failure.status}` : `agent ${failure.kind}`);
    this.name = 'AgentCallError';
    this.failure = failure;
  }
}

/**
 * Maps an agent failure to the door's error. An agent 400 means the door sent
 * something the agent didn't accept, which is our bug: it is `invalid_request`
 * to the app and `isBug` for the log. The agent's own message is never used.
 */
export function fromAgentError(err: unknown): { error: DoorError; isBug: boolean } {
  if (!(err instanceof AgentCallError)) return { error: new DoorError('internal'), isBug: true };
  const f = err.failure;
  if (f.kind === 'timeout') return { error: new DoorError('upstream_timeout'), isBug: false };
  if (f.kind === 'network') return { error: new DoorError('upstream_unavailable'), isBug: false };
  if (f.status === 400) return { error: new DoorError('invalid_request'), isBug: true };
  if (f.status === 404) return { error: new DoorError('not_found'), isBug: false };
  if (f.status === 429) {
    return f.spentUsd !== undefined
      ? { error: new DoorError('spend_limited', { retryAfterSeconds: SPEND_RETRY_FALLBACK_SECONDS }), isBug: false }
      : { error: new DoorError('rate_limited', { retryAfterSeconds: RATE_RETRY_FALLBACK_SECONDS }), isBug: false };
  }
  if (f.status >= 500) return { error: new DoorError('upstream_unavailable'), isBug: false };
  return { error: new DoorError('internal'), isBug: true };
}

/** The agent's 429s carry no wait; these are the honest upper bounds of its windows. */
export const RATE_RETRY_FALLBACK_SECONDS = 60;
export const SPEND_RETRY_FALLBACK_SECONDS = 24 * 60 * 60;

/**
 * Mounted on `/v2` after the router: errors raised before a door runs (a body
 * that isn't JSON, one over the size limit) still get the envelope, not the
 * app-wide handler's shape.
 */
export function v2ErrorHandler(err: unknown, _req: Request, res: Response, next: NextFunction): void {
  if (res.headersSent) {
    next(err);
    return;
  }
  // body-parser marks the client's mistakes (bad JSON, too large, wrong
  // charset or encoding) with a 4xx status; those are the request's fault.
  const status = (err as { status?: unknown; statusCode?: unknown } | null);
  const code = typeof status?.status === 'number' ? status.status : typeof status?.statusCode === 'number' ? status.statusCode : 500;
  sendError(res, code < 500 ? new DoorError('invalid_request') : err);
}
