import { z } from 'zod';
import type { BriefRow } from './store.js';

/**
 * The brief as contract 02 §3 shows it, from a `daily_briefs` row. Pure: the
 * signed link, when there is one, is passed in.
 *
 * Parts (one rule, shared with the agent's `briefPartsOf`):
 *   - with audio `ready`, the parts ARE `audio_parts`, what was actually
 *     spoken, so `startSeconds` can never land on the wrong sentence
 *     (pass F7); `why` and `sources` come from the v1 item at the same index;
 *   - v1 rows (any `spine_movement` but `'planner v2'`): one part per item,
 *     `why` when the item has one, `sources` the entry it quotes;
 *   - v2 rows: `through_line` split at blank lines, no sources; the v2
 *     `items` are bookkeeping and are never shown;
 *   - quiet: one part, the agent's own line.
 */

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const PLANNER_V2 = 'planner v2';

export const SourceRefOut = z.object({
  kind: z.enum(['entry', 'fact', 'answer', 'pattern', 'saved', 'turn']),
  id: z.string().min(1),
  label: z.string().optional(),
}).strict();

export const BriefPartOut = z.object({
  text: z.string().min(1),
  why: z.string().optional(),
  sources: z.array(SourceRefOut),
  startSeconds: z.number().min(0).optional(),
}).strict();

export const BriefAudioOut = z.object({
  url: z.string().url(),
  expiresAt: z.string().datetime(),
  durationSeconds: z.number().positive(),
}).strict();

export const BriefOut = z.object({
  id: z.string().uuid(),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  kind: z.enum(['brief', 'quiet']),
  parts: z.array(BriefPartOut).min(1),
  audio: BriefAudioOut.optional(),
  createdAt: z.string().datetime(),
}).strict();

export const LatestOut = z.object({
  brief: BriefOut.nullable(),
  enabled: z.boolean(),
  nextAt: z.string().datetime().nullable(),
}).strict();

export const BriefPageOut = z.object({
  briefs: z.array(BriefOut),
  nextCursor: z.string().nullable(),
}).strict();

export const EnabledOut = z.object({ enabled: z.boolean() }).strict();
export const BriefByIdOut = z.object({ brief: BriefOut }).strict();

export type BriefPart = z.infer<typeof BriefPartOut>;
export type Brief = z.infer<typeof BriefOut>;
export type SignedLink = { url: string; expiresAt: string };

function v1Part(item: BriefRow['items'][number]): Omit<BriefPart, 'startSeconds'> | null {
  const text = typeof item.text === 'string' ? item.text.trim() : '';
  if (!text) return null;
  const why = typeof item.why === 'string' && item.why.trim() ? item.why : undefined;
  const entry = item.sourceRef?.raw_content_id;
  const sources = typeof entry === 'string' && UUID.test(entry) ? [{ kind: 'entry' as const, id: entry }] : [];
  return { text, ...(why ? { why } : {}), sources };
}

/** The spoken parts of a row without audio: the split rule the agent applies too. */
export function textParts(row: BriefRow): BriefPart[] {
  if (row.kind === 'quiet') return [{ text: row.throughLine, sources: [] }];
  if (row.spineMovement === PLANNER_V2) {
    return row.throughLine.split(/\n\s*\n/).map((t) => t.trim()).filter(Boolean).map((text) => ({ text, sources: [] }));
  }
  return row.items.map(v1Part).filter((p): p is NonNullable<typeof p> => p !== null);
}

/** The parts when audio is ready: what was spoken, with where each starts. */
function spokenParts(row: BriefRow): BriefPart[] {
  const v1 = row.spineMovement === PLANNER_V2 ? [] : row.items.map(v1Part);
  return row.audioParts.map((p, i) => {
    const from = v1[p.index] ?? null;
    return { text: p.text, ...(from?.why ? { why: from.why } : {}), sources: from?.sources ?? [], startSeconds: i === 0 ? 0 : p.startSeconds };
  });
}

export function hasReadyAudio(row: BriefRow): boolean {
  return row.audioStatus === 'ready' && row.audioPath !== null && row.audioDurationSeconds !== null && row.audioDurationSeconds > 0 && row.audioParts.length > 0;
}

/** The contract's `Brief`. `link` is used only when the row's audio is ready. */
export function briefResponse(row: BriefRow, link: SignedLink | null): Brief {
  const withAudio = hasReadyAudio(row) && link !== null && row.kind !== 'quiet';
  const parts = withAudio ? spokenParts(row) : textParts(row);
  return {
    id: row.id,
    date: row.briefDate,
    kind: row.kind,
    parts: parts.length ? parts : [{ text: row.throughLine, sources: [] }],
    ...(withAudio ? { audio: { url: link.url, expiresAt: link.expiresAt, durationSeconds: row.audioDurationSeconds! } } : {}),
    createdAt: row.createdAt,
  };
}

/** A brief still being voiced for less than this is not yet `latest` (pass F3); longer, the synthesiser died and the text is served. */
export const MAKING_GRACE_MS = 15 * 60 * 1000;

export function stillMaking(row: BriefRow, nowMs: number): boolean {
  if (row.audioStatus !== 'making') return false;
  const since = row.audioUpdatedAt ? nowMs - Date.parse(row.audioUpdatedAt) : 0;
  return since < MAKING_GRACE_MS;
}

/** After the run time, the brief is still "on its way" for this long before `nextAt` moves to tomorrow (a late run). */
export const RUN_GRACE_MS = 60 * 60 * 1000;

/**
 * When the next brief runs: today's `HH:MM` UTC until an hour past it, then
 * tomorrow's. Null when no run time is configured (production, D10). BE6.1a
 * replaces this with each person's own time through the same field.
 */
export function nextBriefAt(nowMs: number, utcTime: string | null): string | null {
  const m = utcTime ? /^(\d{2}):(\d{2})$/.exec(utcTime) : null;
  if (!m) return null;
  const hours = Number(m[1]), minutes = Number(m[2]);
  if (hours > 23 || minutes > 59) return null;
  const now = new Date(nowMs);
  const today = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), hours, minutes);
  return new Date(nowMs < today + RUN_GRACE_MS ? today : today + 24 * 60 * 60 * 1000).toISOString();
}

/** An opaque page cursor: the last page's oldest `brief_date` (unique per person). */
export function encodeCursor(briefDate: string): string {
  return Buffer.from(JSON.stringify({ d: briefDate }), 'utf8').toString('base64url');
}

export function decodeCursor(cursor: string): string | null {
  try {
    const parsed = JSON.parse(Buffer.from(cursor, 'base64url').toString('utf8')) as { d?: unknown };
    return typeof parsed.d === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(parsed.d) ? parsed.d : null;
  } catch {
    return null;
  }
}
