/**
 * The structured log for `/v2` doors: one JSON line per request on stdout.
 *
 * Privacy is enforced here, not by convention (context.md §3: counts and types
 * only, never a person's words). The line has a fixed set of fields, none of
 * which is free text:
 *   - numbers are numbers (non-finite becomes null);
 *   - every string must match a narrow pattern (an id, a door name, an error
 *     code, an app version), or it is written as "invalid";
 *   - anything else passed in, even through a cast, is dropped.
 * So a caller can't leak an entry, a message or an agent error through this
 * log even by mistake. tests/door-log.test.ts holds the field list fixed.
 */

export interface DoorLogLine {
  /** The door's name, e.g. `entries.create`. */
  door: string;
  userId: string;
  status: number;
  /** The contract's error code on failure, e.g. `rate_limited`. */
  code?: string;
  /** Total time in the door, milliseconds. */
  ms: number;
  /** Time waiting on the agent, milliseconds. */
  agentMs?: number;
  /** Model spend the agent reported for this request, dollars. */
  costUsd?: number;
  /** The X-App-Version header, e.g. `1.0 (42)`. */
  appVersion?: string;
}

/** The only fields a door log line can have, in output order. */
export const DOOR_LOG_FIELDS = ['door', 'userId', 'status', 'code', 'ms', 'agentMs', 'costUsd', 'appVersion'] as const;

// Compile-time: DOOR_LOG_FIELDS and DoorLogLine name exactly the same keys.
type Same<A, B> = [A] extends [B] ? ([B] extends [A] ? true : false) : false;
const fieldsMatchType: Same<(typeof DOOR_LOG_FIELDS)[number], keyof DoorLogLine> = true;
void fieldsMatchType;

const PATTERNS: Record<'door' | 'userId' | 'code' | 'appVersion', RegExp> = {
  door: /^[a-z][a-z0-9._-]{0,63}$/,
  userId: /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i,
  code: /^[a-z][a-z_]{0,39}$/,
  appVersion: /^[0-9][0-9A-Za-z.]{0,15}( \([0-9]{1,8}\))?$/,
};

const INVALID = 'invalid';

function safeString(field: keyof typeof PATTERNS, value: unknown): string {
  return typeof value === 'string' && PATTERNS[field].test(value) ? value : INVALID;
}

function safeNumber(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

/** Builds the line exactly as it will be written; exported for tests. */
export function doorLogLine(entry: DoorLogLine): Record<string, string | number | null> {
  const line: Record<string, string | number | null> = {
    door: safeString('door', entry.door),
    userId: safeString('userId', entry.userId),
    status: safeNumber(entry.status),
  };
  if (entry.code !== undefined) line.code = safeString('code', entry.code);
  line.ms = safeNumber(entry.ms);
  if (entry.agentMs !== undefined) line.agentMs = safeNumber(entry.agentMs);
  if (entry.costUsd !== undefined) line.costUsd = safeNumber(entry.costUsd);
  if (entry.appVersion !== undefined) line.appVersion = safeString('appVersion', entry.appVersion);
  return line;
}

export function createLog(write: (line: string) => void = (line) => { process.stdout.write(line); }) {
  return {
    door(entry: DoorLogLine): void {
      write(`${JSON.stringify(doorLogLine(entry))}\n`);
    },
  };
}

export const log = createLog();
