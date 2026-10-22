import type { Router } from 'express';
import { z } from 'zod';
import type { DoorFactory } from '../doors/door.js';
import { DoorError } from '../doors/errors.js';
import { requestHash } from '../services/content-insert.js';
import type { EntryStore, ListCursor, StoredEntry } from './store.js';

/**
 * The journal's entry doors (BE1.1 and BE1.5, contract 02 §2 and §5):
 *   POST /v2/entries        send an entry into your bank, once (Idempotency-Key = clientEntryId)
 *   GET  /v2/entries/today  your entries on today's calendar day where you are, oldest first
 *   GET  /v2/entries        the drawer: everything you sent, newest first, in keyed pages, with search
 *   GET  /v2/entries/:id    one entry of yours; another person's id is not_found
 * None calls the brain while answering: a new row is handed to ingest after
 * the response (startIngest), and if the brain can't be reached the row stays
 * pending for its next sweep. Nothing here is open to waitlisted people.
 * Editing and deleting are BE1.5b (after Beta 1: a delete must take everything
 * read from the entry with it, which needs the brain's forget route).
 */
export interface EntryDoorDeps {
  entries: EntryStore;
  /** Starts the brain's read of one stored row, after the response; never throws into the door. */
  startIngest: (userId: string, rawContentId: string) => void;
}

/**
 * The content types a person sends, as the agent's planner counts them
 * (agent src/planner/daily.ts SENT_TYPES). "today" lists these and nothing
 * else: never records, mail or others' items. `video_entry` (old video notes)
 * isn't in the agent's set, so old ones don't show; new ones are sent as voice.
 */
export const SENT_TYPES = [
  'text_entry', 'journal_entry', 'voice_recording', 'voice_journal', 'conversation', 'manual_journal', 'link', 'shared_link', 'reference', 'note',
] as const;

/** Contract 02 §5's kind for a stored content type; anything else the person sent is `imported`. */
export function kindOf(contentType: string): Entry['kind'] {
  switch (contentType) {
    case 'text_entry': case 'journal_entry': case 'manual_journal': case 'note': return 'typed';
    case 'voice_recording': case 'voice_journal': return 'voice';
    case 'conversation': return 'conversation';
    default: return 'imported';
  }
}

/** processing_status → reading; a row with no status is still waiting. */
export function readingOf(status: string | null): Entry['reading'] {
  switch (status) {
    case 'processing': return 'reading';
    case 'completed': return 'read';
    case 'failed': return 'failed';
    default: return 'waiting';
  }
}

/** Sent as `typed` → journal_entry, `voice` → voice_journal (the card). */
const CONTENT_TYPE_OF = { typed: 'journal_entry', voice: 'voice_journal' } as const;

/** 1–20,000 UTF-16 code units after trimming (contract 02 §5; zod counts UTF-16 as Swift does). */
export const MAX_ENTRY_UNITS = 20_000;
/** A createdAt further ahead than this is clock skew: stored as the server's now, never refused. */
export const CLOCK_SKEW_MS = 5 * 60_000;
/** "today" never lists more than this; older ones stay in the drawer (BE1.5). */
export const TODAY_LIMIT = 200;
/** The drawer's page: default and ceiling (contract pass §1.5). */
export const LIST_LIMIT = { default: 50, max: 100 } as const;
/** A search is 1–100 characters. */
export const MAX_QUERY_UNITS = 100;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const DAY = /^\d{4}-\d{2}-\d{2}$/;

/** Fixture 02/entry.create.request.json (.voice). Strict: a client-sent userId or any other field is invalid_request. */
export const EntryCreateBody = z.object({
  text: z.string().transform((s) => s.trim()).pipe(z.string().min(1).max(MAX_ENTRY_UNITS)),
  kind: z.enum(['typed', 'voice']),
  clientEntryId: z.string().regex(UUID),
  /** ISO 8601, UTC with a Z (an offset is invalid_request, as on diagnostics). */
  createdAt: z.string().datetime().refine((s) => !Number.isNaN(Date.parse(s))),
}).strict();
export type EntryCreateBody = z.infer<typeof EntryCreateBody>;

const Empty = z.object({}).strict();

/** Query strings arrive as text; a limit must read as a whole number. */
const limitField = z.preprocess(
  (v) => (typeof v === 'string' && /^\d{1,3}$/.test(v) ? Number(v) : v),
  z.number().int().min(1).max(LIST_LIMIT.max).optional(),
);
/** Fixture 02/entries.list.json's query shape; strict, so a client-sent userId is invalid_request. */
export const ListQuery = z.object({
  cursor: z.string().min(1).max(200).optional(),
  limit: limitField,
  q: z.string().min(1).max(MAX_QUERY_UNITS).refine((s) => !s.includes('\0')).optional(),
}).strict();
const EntryId = z.object({ id: z.string().regex(UUID) }).strict();

/** Contract 02 §5's Entry; `matches` only on search (BE1.5). The 02 fixtures are checked against these. */
export const Entry = z.object({
  id: z.string().regex(UUID),
  kind: z.enum(['typed', 'voice', 'conversation', 'imported']),
  text: z.string(),
  createdAt: z.string().datetime(),
  day: z.string().regex(DAY),
  reading: z.enum(['waiting', 'reading', 'read', 'failed']),
  clientEntryId: z.string().regex(UUID).optional(),
  matches: z.array(z.object({ start: z.number().int().min(0), length: z.number().int().positive() }).strict()).optional(),
}).strict();
export type Entry = z.infer<typeof Entry>;
export const EntryResponse = z.object({ entry: Entry }).strict();
export const TodayResponse = z.object({ date: z.string().regex(DAY), entries: z.array(Entry) }).strict();
export type TodayResponse = z.infer<typeof TodayResponse>;
export const ListResponse = z.object({ entries: z.array(Entry), nextCursor: z.string().nullable() }).strict();
export type ListResponse = z.infer<typeof ListResponse>;

/**
 * The page cursor: the last entry's moment in microseconds and its id, as
 * opaque text (base64url of `<us>|<id>`). The app never reads inside it; a
 * cursor that doesn't decode is invalid_request, and the app starts over.
 */
export function encodeCursor(c: ListCursor): string {
  return Buffer.from(`${c.atUs}|${c.id}`, 'utf8').toString('base64url');
}
export function decodeCursor(text: string): ListCursor | null {
  let decoded: string;
  try {
    decoded = Buffer.from(text, 'base64url').toString('utf8');
  } catch {
    return null;
  }
  const m = /^(\d{1,19})\|([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$/.exec(decoded);
  if (!m) return null;
  const atUs = Number(m[1]);
  if (!Number.isSafeInteger(atUs)) return null;
  return { atUs, id: m[2]! };
}

/** `q` as an ILIKE pattern: the person's wildcards are letters, not wildcards. */
export function likePattern(q: string): string {
  return `%${q.replace(/[\\%_]/g, (c) => `\\${c}`)}%`;
}

/**
 * Where `q` occurs in `text`, case-insensitively, as UTF-16 ranges (the unit
 * Swift's NSRange and JavaScript strings share): every non-overlapping
 * occurrence. Lower-casing can change a string's length for a few scripts
 * (İ, ß); the app drops a range that runs past the end (PL3.1d).
 */
export function matchRanges(text: string, q: string): { start: number; length: number }[] {
  const hay = text.toLowerCase();
  const needle = q.toLowerCase();
  const out: { start: number; length: number }[] = [];
  if (needle.length === 0) return out;
  let from = 0;
  for (;;) {
    const at = hay.indexOf(needle, from);
    if (at < 0) return out;
    out.push({ start: at, length: needle.length });
    from = at + needle.length;
  }
}

export function toEntry(e: StoredEntry): Entry {
  return {
    id: e.id,
    kind: kindOf(e.contentType),
    text: e.text,
    createdAt: e.at,
    day: e.day,
    reading: readingOf(e.processingStatus),
    ...(e.clientEntryId !== null ? { clientEntryId: e.clientEntryId } : {}),
  };
}

export function mountEntryDoors(router: Router, door: DoorFactory, deps: EntryDoorDeps): void {
  // "today" is mounted before "/:id"-shaped routes that BE1.5 adds, so the word never reads as an id.
  router.get('/entries/today', door({
    name: 'entries.today',
    bucket: 'read',
    request: Empty,
    call: async (ctx) => {
      const r = await deps.entries.today({ userId: ctx.userId, types: SENT_TYPES, zone: ctx.timeZone, nowIso: new Date(ctx.now).toISOString(), limit: TODAY_LIMIT });
      if (r.outcome === 'no_user') throw new DoorError('unauthenticated');
      return r;
    },
    map: (r): TodayResponse => ({ date: r.date, entries: r.entries.map(toEntry) }),
  }));

  // The drawer: own words, newest first, keyed pages. A full page carries the
  // cursor of its last entry; a short page is the end (so the page after the
  // last full one may be empty, which the app treats as the end too).
  router.get('/entries', door({
    name: 'entries.list',
    bucket: 'read',
    request: ListQuery,
    call: async (ctx, query) => {
      const cursor = query.cursor === undefined ? null : decodeCursor(query.cursor);
      if (query.cursor !== undefined && cursor === null) throw new DoorError('invalid_request');
      const limit = query.limit ?? LIST_LIMIT.default;
      const r = await deps.entries.list({
        userId: ctx.userId, types: SENT_TYPES, zone: ctx.timeZone, limit, cursor, pattern: query.q === undefined ? null : likePattern(query.q),
      });
      if (r.outcome === 'no_user') throw new DoorError('unauthenticated');
      return { entries: r.entries, limit, q: query.q ?? null };
    },
    map: (r): ListResponse => {
      const last = r.entries[r.entries.length - 1];
      const nextCursor = r.entries.length === r.limit && last && last.atUs !== null ? encodeCursor({ atUs: last.atUs, id: last.id }) : null;
      return {
        entries: r.entries.map((e) => (r.q === null ? toEntry(e) : { ...toEntry(e), matches: matchRanges(e.text, r.q) })),
        nextCursor,
      };
    },
  }));

  // One entry. The function filters by the caller, so another person's id and
  // a missing one are the same not_found (door step 5: never forbidden).
  router.get('/entries/:id', door({
    name: 'entries.get',
    bucket: 'read',
    request: EntryId,
    call: async (ctx, { id }) => {
      const r = await deps.entries.get({ userId: ctx.userId, id, types: SENT_TYPES, zone: ctx.timeZone });
      if (r.outcome === 'no_user') throw new DoorError('unauthenticated');
      if (r.entry === null) throw new DoorError('not_found');
      return r.entry;
    },
    map: (e) => ({ entry: toEntry(e) }),
  }));

  // The send. Once per clientEntryId: the key in the header must be the body's
  // id (lowercased both sides), the fingerprint is kind + text (never createdAt,
  // so clamping skew can't turn a retry into a mismatch), and a replay gets the
  // stored row with no second read. 201 new, 200 replay, 409 mismatch.
  router.post('/entries', door({
    name: 'entries.create',
    bucket: 'write',
    request: EntryCreateBody,
    call: async (ctx, body) => {
      const key = ctx.idempotencyKey?.toLowerCase();
      const clientEntryId = body.clientEntryId.toLowerCase();
      if (key !== clientEntryId) throw new DoorError('invalid_request');
      const contentType = CONTENT_TYPE_OF[body.kind];
      // The person's moment, unless their clock is ahead: then it is now, and counted.
      const sent = Date.parse(body.createdAt);
      const skewed = sent > ctx.now + CLOCK_SKEW_MS;
      const result = await deps.entries.create({
        userId: ctx.userId, clientEntryId, contentType, text: body.text, contentDateIso: new Date(skewed ? ctx.now : sent).toISOString(),
        requestHash: requestHash(contentType, body.text), appVersion: ctx.appVersion, zone: ctx.timeZone, nowIso: new Date(ctx.now).toISOString(),
      });
      if (result.outcome === 'mismatch' || result.outcome === 'no_user') {
        throw new DoorError(result.outcome === 'mismatch' ? 'idempotency_mismatch' : 'unauthenticated');
      }
      if (result.outcome === 'created') deps.startIngest(ctx.userId, result.entry.id);
      return { created: result.outcome === 'created', entry: result.entry, skewed };
    },
    map: (r) => ({ entry: toEntry(r.entry) }),
    status: (r) => (r.created ? 201 : 200),
    // Counted once, when the entry is stored; a replay of a clamped entry is not a second skew.
    logCounts: (r) => (r.skewed && r.created ? { clockSkew: 1 } : {}),
  }));
}
