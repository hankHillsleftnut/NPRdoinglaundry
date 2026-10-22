/**
 * The structured log for `/v2` doors: one JSON line per request on stdout.
 *
 * Privacy is enforced here, not by convention (context.md §3: counts and types
 * only, never a person's words). The line has a fixed set of fields, none of
 * which is free text:
 *   - numbers are numbers (non-finite becomes null), including the size and
 *     counts a door may add (`sizeBytes`, `events`, `requests`, `failures`,
 *     `crashes`, `nulledFields`, `dropped`); `reuse` is written only as `true`;
 *   - `code` must be one of the contract's error codes (a closed list);
 *   - `userId` must be a UUID, or null on public doors (sign-in, waitlist);
 *   - `appVersion` must be digits and dots, like `1.0 (42)`;
 *   - anything that fails its check is written as "invalid";
 *   - anything else passed in, even through a cast, is dropped.
 * `door` is the one string that is only shape-checked (a short lowercase
 * slug): door names are constants in the code, never request data, so that
 * check guards against a mistake, not against content.
 * So a caller can't leak an entry, a message or an agent error through this
 * log even by mistake. tests/door-log.test.ts holds the field list fixed.
 *
 * Writing never throws: a logging failure must never affect a request.
 */

import { DOOR_ERROR_CODES, type DoorErrorCode } from '../doors/errors.js';

export { DOOR_ERROR_CODES, type DoorErrorCode };

const KNOWN_CODES: ReadonlySet<string> = new Set(DOOR_ERROR_CODES);

export interface DoorLogLine {
  /** The door's name, a constant in the code, e.g. `entries.create`. */
  door: string;
  /** null on public doors, where there is no signed-in user. */
  userId: string | null;
  status: number;
  /** The contract's error code on failure, e.g. `rate_limited`. */
  code?: DoorErrorCode;
  /** Total time in the door, milliseconds. */
  ms: number;
  /** Time waiting on the agent, milliseconds. */
  agentMs?: number;
  /** Model spend the agent reported for this request, dollars. */
  costUsd?: number;
  /** The X-App-Version header, e.g. `1.0 (42)`. Optional until BE0.10 requires it. */
  appVersion?: string;
  /** Size of what a door stored, bytes (diagnostics reports). */
  sizeBytes?: number;
  /** How many events, requests, failures and crashes a stored report holds (diagnostics). */
  events?: number;
  requests?: number;
  failures?: number;
  crashes?: number;
  /** How many fields of a stored report were dropped as malformed (diagnostics). */
  nulledFields?: number;
  /** How many items the door left out of its answer because the contract has no name for them (guesses). */
  dropped?: number;
  /** auth.refresh only: a rotated refresh token was used again (a possible stolen copy). Written only when true. */
  reuse?: boolean;
}

/** The numeric size and count fields a door may add to its line (DoorSpec.logCounts). */
export type DoorLogCounts = Pick<DoorLogLine, 'sizeBytes' | 'events' | 'requests' | 'failures' | 'crashes' | 'nulledFields' | 'dropped'>;
export const DOOR_LOG_COUNT_FIELDS = ['sizeBytes', 'events', 'requests', 'failures', 'crashes', 'nulledFields', 'dropped'] as const;

/** The only fields a door log line can have, in output order. */
export const DOOR_LOG_FIELDS = [
  'door', 'userId', 'status', 'code', 'ms', 'agentMs', 'costUsd', 'appVersion', 'sizeBytes', 'events', 'requests', 'failures', 'crashes', 'nulledFields',
  'dropped', 'reuse',
] as const;

// Compile-time: DOOR_LOG_FIELDS and DoorLogLine name exactly the same keys.
type Same<A, B> = [A] extends [B] ? ([B] extends [A] ? true : false) : false;
const fieldsMatchType: Same<(typeof DOOR_LOG_FIELDS)[number], keyof DoorLogLine> = true;
void fieldsMatchType;

const PATTERNS: Record<'door' | 'userId' | 'appVersion', RegExp> = {
  door: /^[a-z][a-z0-9._-]{0,63}$/,
  userId: /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i,
  appVersion: /^\d{1,4}(\.\d{1,4}){0,2}( \(\d{1,8}(\.\d{1,8}){0,2}\))?$/,
};

const INVALID = 'invalid';

function safeString(field: keyof typeof PATTERNS, value: unknown): string {
  return typeof value === 'string' && PATTERNS[field].test(value) ? value : INVALID;
}

function safeNumber(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

/** Builds the line exactly as it will be written; exported for tests. */
export function doorLogLine(entry: DoorLogLine): Record<string, string | number | boolean | null> {
  const line: Record<string, string | number | boolean | null> = {
    door: safeString('door', entry.door),
    userId: entry.userId === null ? null : safeString('userId', entry.userId),
    status: safeNumber(entry.status),
  };
  if (entry.code !== undefined) {
    line.code = typeof entry.code === 'string' && KNOWN_CODES.has(entry.code) ? entry.code : INVALID;
  }
  line.ms = safeNumber(entry.ms);
  if (entry.agentMs !== undefined) line.agentMs = safeNumber(entry.agentMs);
  if (entry.costUsd !== undefined) line.costUsd = safeNumber(entry.costUsd);
  if (entry.appVersion !== undefined) line.appVersion = safeString('appVersion', entry.appVersion);
  for (const field of DOOR_LOG_COUNT_FIELDS) {
    if (entry[field] !== undefined) line[field] = safeNumber(entry[field]);
  }
  if (entry.reuse === true) line.reuse = true;
  return line;
}

export function createLog(write: (line: string) => void = (line) => { process.stdout.write(line); }) {
  return {
    door(entry: DoorLogLine): void {
      try {
        write(`${JSON.stringify(doorLogLine(entry))}\n`);
      } catch {
        // Nowhere safe to report it; dropping one log line beats failing a request.
      }
    },
  };
}

export const log = createLog();
