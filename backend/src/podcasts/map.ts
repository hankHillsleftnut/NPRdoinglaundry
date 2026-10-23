import { z } from 'zod';
import type { BriefRow, CreatedBefore } from '../briefs/store.js';
import { hasReadyAudio, textParts } from '../briefs/map.js';
import type { EpisodeRow } from './store.js';

/**
 * The podcasts library as contract 03 §2 shows it (BE3.x.lib). Pure: the
 * door passes rows in and gets the answer out.
 *
 * Order: newest first by creation time; at the same instant an episode comes
 * before a brief, then the higher id first (the stores' `created_at desc, id
 * desc`). The cursor is the last item returned (its exact timestamp, kind and
 * id), and each source is then asked only for what comes after it, so paging
 * never repeats or skips an item that shares a timestamp with another.
 */

const DAY = /^\d{4}-\d{2}-\d{2}$/;

export const EpisodeSummaryOut = z.object({
  id: z.string().uuid(),
  kind: z.enum(['weekly', 'first', 'onDemand', 'unknown']),
  number: z.number().int().optional(),
  title: z.string(),
  about: z.string().optional(),
  durationSeconds: z.number().min(0),
  timing: z.enum(['measured', 'estimated', 'unknown']),
  createdAt: z.string().datetime(),
  coversFrom: z.string().regex(DAY).optional(),
  coversTo: z.string().regex(DAY).optional(),
  hasAudio: z.boolean(),
}).strict();

export const BriefSummaryOut = z.object({
  id: z.string().uuid(),
  date: z.string().regex(DAY),
  title: z.string(),
  durationSeconds: z.number().positive().optional(),
  hasAudio: z.boolean(),
}).strict();

export const LibraryItemOut = z.union([
  z.object({ kind: z.literal('episode'), episode: EpisodeSummaryOut }).strict(),
  z.object({ kind: z.literal('brief'), brief: BriefSummaryOut }).strict(),
  z.object({ kind: z.literal('unknown') }).strict(),
]);

export const UpcomingOut = z.union([
  z.object({ state: z.literal('making'), readyAt: z.string().datetime().optional() }).strict(),
  z.object({ state: z.literal('quietWeek'), line: z.string().min(1), nextAt: z.string().datetime().optional() }).strict(),
  z.object({ state: z.literal('none') }).strict(),
  z.object({ state: z.literal('unknown') }).strict(),
]);

/** `upcoming` comes on the first page only. */
export const LibraryOut = z.object({
  hero: EpisodeSummaryOut.nullable(),
  upcoming: UpcomingOut.optional(),
  items: z.array(LibraryItemOut),
  nextCursor: z.string().nullable(),
}).strict();

export type EpisodeSummary = z.infer<typeof EpisodeSummaryOut>;
export type BriefSummary = z.infer<typeof BriefSummaryOut>;
export type LibraryItem = z.infer<typeof LibraryItemOut>;
export type Library = z.infer<typeof LibraryOut>;

const KINDS: Record<string, EpisodeSummary['kind']> = { weekly: 'weekly', on_demand: 'onDemand' };

/** The contract's `EpisodeSummary`; `unknown` says the generation type had no contract name (counted in the log). */
export function episodeSummary(row: EpisodeRow): { summary: EpisodeSummary; unknown: boolean } {
  const kind = (row.generationType !== null && KINDS[row.generationType]) || 'unknown';
  const measured = row.durationSeconds !== null && Number.isFinite(row.durationSeconds) && row.durationSeconds >= 0;
  return {
    summary: {
      id: row.id,
      kind,
      ...(row.episodeNumber !== null && Number.isInteger(row.episodeNumber) ? { number: row.episodeNumber } : {}),
      title: row.title,
      // `about` arrives with chapters (BE3.0a). No measured column yet: the brain's words/150.
      durationSeconds: measured ? row.durationSeconds! : 0,
      timing: measured ? 'estimated' : 'unknown',
      createdAt: row.createdAt,
      ...(row.coversFrom ? { coversFrom: row.coversFrom } : {}),
      ...(row.coversTo ? { coversTo: row.coversTo } : {}),
      hasAudio: row.hasAudio,
    },
    unknown: kind === 'unknown',
  };
}

export const BRIEF_TITLE_MAX = 80;

/** The first sentence of `text`, its closing full stop dropped, cut at 80. */
export function briefTitle(text: string): string {
  const trimmed = text.trim();
  const end = /[.!?](\s|$)/.exec(trimmed);
  const sentence = end ? trimmed.slice(0, end.index + 1) : trimmed;
  const bare = sentence.endsWith('.') ? sentence.slice(0, -1) : sentence;
  return bare.length > BRIEF_TITLE_MAX ? bare.slice(0, BRIEF_TITLE_MAX).trimEnd() : bare;
}

/** The contract's `BriefSummary`: titled by its first spoken sentence; the words themselves are never listed. */
export function briefSummary(row: BriefRow): BriefSummary {
  const ready = hasReadyAudio(row);
  const first = ready ? row.audioParts[0]?.text : textParts(row)[0]?.text;
  return {
    id: row.id,
    date: row.briefDate,
    title: briefTitle(first ?? row.throughLine),
    ...(ready ? { durationSeconds: row.audioDurationSeconds! } : {}),
    hasAudio: ready,
  };
}

// ── Order and the cursor ─────────────────────────────────────────────────────

export type SourceKind = 'episode' | 'brief';
export interface Position { at: string; kind: SourceKind; id: string }

/** A database timestamp, with or without microseconds and offset. */
const STAMP = /^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2}:\d{2})(?:\.(\d{1,6}))?(Z|[+-]\d{2}(?::?\d{2})?)$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

/** Microseconds since the epoch, exact to the database's precision; null when it is not a timestamp. */
export function stampMicros(at: string): number | null {
  const m = STAMP.exec(at);
  if (!m) return null;
  const zone = m[4] === 'Z' ? 'Z' : m[4]!.length === 3 ? `${m[4]}:00` : m[4]!.replace(/^([+-]\d{2})(\d{2})$/, '$1:$2');
  const seconds = Date.parse(`${m[1]}T${m[2]}${zone}`);
  if (Number.isNaN(seconds)) return null;
  return seconds * 1000 + Number((m[3] ?? '').padEnd(6, '0'));
}

/** Negative when `a` comes first in the library. */
export function compare(a: Position, b: Position): number {
  const t = (stampMicros(b.at) ?? 0) - (stampMicros(a.at) ?? 0);
  if (t !== 0) return t;
  if (a.kind !== b.kind) return a.kind === 'episode' ? -1 : 1;
  return a.id < b.id ? 1 : a.id > b.id ? -1 : 0;
}

/** What one source still has to give after `p`: the stores' half of the cursor. */
export function beforeFor(source: SourceKind, p: Position): CreatedBefore {
  if (source === p.kind) return { at: p.at, tie: { below: p.id } };
  // At the same instant episodes come first: after an episode every brief at that instant is still to come; after a brief no episode is.
  return { at: p.at, tie: source === 'brief' ? 'all' : 'none' };
}

export function encodeCursor(p: Position): string {
  return Buffer.from(`${p.at}|${p.kind}|${p.id}`, 'utf8').toString('base64url');
}

/** The position a cursor names, or null when it isn't one this door made. */
export function decodeCursor(cursor: string): Position | null {
  if (!/^[A-Za-z0-9_-]+$/.test(cursor)) return null;
  const parts = Buffer.from(cursor, 'base64url').toString('utf8').split('|');
  if (parts.length !== 3) return null;
  const [at, kind, id] = parts as [string, string, string];
  if (stampMicros(at) === null || (kind !== 'episode' && kind !== 'brief') || !UUID.test(id)) return null;
  return { at, kind, id };
}

// ── The page ─────────────────────────────────────────────────────────────────

export type Entry =
  | { kind: 'episode'; row: EpisodeRow }
  | { kind: 'brief'; row: BriefRow & { createdKey: string } };

const position = (e: Entry): Position => ({ at: e.row.createdKey, kind: e.kind, id: e.row.id });

/**
 * Merges the two sources (each already in library order, each fetched with at
 * least `limit + 1` rows when it has them) and cuts one page. `hasMore` is true
 * when anything was left over, and the cursor is then the last item returned.
 */
export function mergePage(
  episodes: EpisodeRow[], briefs: Array<BriefRow & { createdKey: string }>, limit: number,
): { page: Entry[]; nextCursor: string | null } {
  const all: Entry[] = [
    ...episodes.map((row) => ({ kind: 'episode' as const, row })),
    ...briefs.map((row) => ({ kind: 'brief' as const, row })),
  ].sort((a, b) => compare(position(a), position(b)));
  const page = all.slice(0, limit);
  const last = page[page.length - 1];
  return { page, nextCursor: all.length > limit && last ? encodeCursor(position(last)) : null };
}

/** The contract's answer for one page. `first` = no cursor was sent. */
export function libraryResponse(hero: EpisodeRow | null, page: Entry[], nextCursor: string | null, first: boolean): { library: Library; unknownKinds: number } {
  let unknownKinds = 0;
  const episode = (row: EpisodeRow): EpisodeSummary => {
    const { summary, unknown } = episodeSummary(row);
    if (unknown) unknownKinds++;
    return summary;
  };
  const items: LibraryItem[] = page.map((e) => (e.kind === 'episode'
    ? { kind: 'episode', episode: episode(e.row) }
    : { kind: 'brief', brief: briefSummary(e.row) }));
  return {
    library: {
      hero: hero ? episode(hero) : null,
      ...(first ? { upcoming: { state: 'none' as const } } : {}),
      items,
      nextCursor,
    },
    unknownKinds,
  };
}
