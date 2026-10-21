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
  /** Text across system and turns. Podcast prompts carry a week of entries. */
  maxInputChars: 200_000,
  /** Journal image analysis sends photos as base64 image blocks. */
  maxImages: 10,
  maxImageBase64Chars: 20_000_000,
  maxOutputTokens: 8192,
  defaultOutputTokens: 2000,
} as const;

type TextBlock = { type: 'text'; text: string };
type ImageBlock = { type: 'image'; source: { type: 'base64'; media_type: string; data: string } };
export type Turn = { role: 'user' | 'assistant'; content: string | Array<TextBlock | ImageBlock> };
const IMAGE_TYPES = new Set(['image/jpeg', 'image/png', 'image/gif', 'image/webp']);

export type GuardResult =
  | { ok: true; messages: Turn[]; system?: string; maxTokens: number; at: number }
  | { ok: false; status: number; error: string };

const HOUR = 60 * 60 * 1000;
const DAY = 24 * HOUR;

/** Call timestamps per user. */
export class CallLog {
  private calls = new Map<string, number[]>();
  private lastSweep = 0;
  record(userId: string, now: number): void {
    this.sweep(now);
    const kept = (this.calls.get(userId) ?? []).filter((t) => now - t < DAY);
    kept.push(now);
    this.calls.set(userId, kept);
  }
  /** Give a call back when the provider failed, so outages don't use up quota. */
  refund(userId: string, at: number): void {
    const list = this.calls.get(userId);
    if (!list) return;
    const i = list.lastIndexOf(at);
    if (i >= 0) list.splice(i, 1);
  }
  /** Forget users with no calls in the last day (at most once an hour). */
  private sweep(now: number): void {
    if (now - this.lastSweep < HOUR) return;
    this.lastSweep = now;
    for (const [id, list] of this.calls) if (!list.some((t) => now - t < DAY)) this.calls.delete(id);
  }
  size(): number {
    return this.calls.size;
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

  // User/assistant turns only, each either plain text or text + base64 image blocks
  // (journal image analysis). No tools, documents or other block types.
  const messages: Turn[] = [];
  let textChars = typeof b.systemPrompt === 'string' ? b.systemPrompt.length : 0;
  let images = 0;
  let imageChars = 0;
  for (const m of raw as Array<Record<string, unknown>>) {
    if (m.role !== 'user' && m.role !== 'assistant') return { ok: false, status: 400, error: 'messages must be user/assistant turns' };
    if (typeof m.content === 'string') {
      textChars += m.content.length;
      messages.push({ role: m.role, content: m.content });
      continue;
    }
    if (!Array.isArray(m.content)) return { ok: false, status: 400, error: 'message content must be text or blocks' };
    const blocks: Array<TextBlock | ImageBlock> = [];
    for (const block of m.content as Array<Record<string, unknown>>) {
      if (block?.type === 'text' && typeof block.text === 'string') {
        textChars += block.text.length;
        blocks.push({ type: 'text', text: block.text });
      } else if (block?.type === 'image') {
        const src = block.source as Record<string, unknown> | undefined;
        if (src?.type !== 'base64' || typeof src.data !== 'string' || !IMAGE_TYPES.has(String(src.media_type))) {
          return { ok: false, status: 400, error: 'images must be base64 jpeg, png, gif or webp' };
        }
        images++;
        imageChars += src.data.length;
        blocks.push({ type: 'image', source: { type: 'base64', media_type: String(src.media_type), data: src.data } });
      } else {
        return { ok: false, status: 400, error: 'only text and image blocks are allowed' };
      }
    }
    messages.push({ role: m.role, content: blocks });
  }
  const system = typeof b.systemPrompt === 'string' ? b.systemPrompt : undefined;
  if (textChars > CLAUDE_LIMITS.maxInputChars || images > CLAUDE_LIMITS.maxImages || imageChars > CLAUDE_LIMITS.maxImageBase64Chars) {
    return { ok: false, status: 413, error: 'Request too large' };
  }

  const asked = Number(b.maxTokens ?? CLAUDE_LIMITS.defaultOutputTokens);
  const maxTokens = Number.isFinite(asked) && asked > 0 ? Math.min(Math.floor(asked), CLAUDE_LIMITS.maxOutputTokens) : CLAUDE_LIMITS.defaultOutputTokens;

  log.record(userId, now);
  return { ok: true, messages, system, maxTokens, at: now };
}
