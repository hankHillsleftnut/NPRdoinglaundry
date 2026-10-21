/**
 * Limits for POST /claude/generate (M14 B0.3).
 *
 * The route used to let any signed-in user send any prompt, of any size, as
 * often as the global rate limit allowed, on the server's Anthropic key. Until
 * the app moves to purpose-specific routes (X05/X07), every call passes here:
 * per-user hourly and daily caps, a cap on input size, plain user/assistant
 * text turns only, and an output cap. Counts live in memory: one instance on
 * Render today; a shared store comes with B1.10's spend limits.
 */
export const CLAUDE_LIMITS = {
  perHour: 30,
  perDay: 120,
  maxInputChars: 60_000,
  maxOutputTokens: 8192,
  defaultOutputTokens: 2000,
} as const;

export type Turn = { role: 'user' | 'assistant'; content: string };

export type GuardResult =
  | { ok: true; messages: Turn[]; system?: string; maxTokens: number }
  | { ok: false; status: number; error: string };

const HOUR = 60 * 60 * 1000;
const DAY = 24 * HOUR;

/** Call timestamps per user. */
export class CallLog {
  private calls = new Map<string, number[]>();
  record(userId: string, now: number): void {
    const kept = (this.calls.get(userId) ?? []).filter((t) => now - t < DAY);
    kept.push(now);
    this.calls.set(userId, kept);
  }
  count(userId: string, now: number, window: number): number {
    return (this.calls.get(userId) ?? []).filter((t) => now - t < window).length;
  }
}

export function guardClaudeRequest(
  userId: string | undefined,
  body: unknown,
  log: CallLog,
  now: number = Date.now(),
): GuardResult {
  if (!userId) return { ok: false, status: 401, error: 'Sign in required' };
  if (log.count(userId, now, HOUR) >= CLAUDE_LIMITS.perHour || log.count(userId, now, DAY) >= CLAUDE_LIMITS.perDay) {
    return { ok: false, status: 429, error: 'Too many requests. Try again later.' };
  }

  const b = (body ?? {}) as Record<string, unknown>;
  const raw = Array.isArray(b.messages)
    ? b.messages
    : typeof b.userMessage === 'string'
      ? [{ role: 'user', content: b.userMessage }]
      : null;
  if (!raw || raw.length === 0) return { ok: false, status: 400, error: 'messages or userMessage is required' };

  // Only plain text turns: no images, tools or other content blocks.
  const messages: Turn[] = [];
  for (const m of raw as Array<Record<string, unknown>>) {
    if ((m.role !== 'user' && m.role !== 'assistant') || typeof m.content !== 'string') {
      return { ok: false, status: 400, error: 'messages must be user/assistant text' };
    }
    messages.push({ role: m.role, content: m.content });
  }
  const system = typeof b.systemPrompt === 'string' ? b.systemPrompt : undefined;
  const inputChars = messages.reduce((n, m) => n + m.content.length, 0) + (system?.length ?? 0);
  if (inputChars > CLAUDE_LIMITS.maxInputChars) return { ok: false, status: 413, error: 'Request too large' };

  const asked = Number(b.maxTokens ?? CLAUDE_LIMITS.defaultOutputTokens);
  const maxTokens = Number.isFinite(asked) && asked > 0 ? Math.min(Math.floor(asked), CLAUDE_LIMITS.maxOutputTokens) : CLAUDE_LIMITS.defaultOutputTokens;

  log.record(userId, now);
  return { ok: true, messages, system, maxTokens };
}
