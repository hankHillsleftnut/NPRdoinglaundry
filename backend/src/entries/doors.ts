import type { Router } from 'express';
import { z } from 'zod';
import type { DoorFactory } from '../doors/door.js';
import { DoorError } from '../doors/errors.js';
import { requestHash } from '../services/content-insert.js';
import type { EntryStore, StoredEntry } from './store.js';

/**
 * The journal's sending doors (BE1.1, contract 02 §2 and §5):
 *   POST /v2/entries        send an entry into your bank, once (Idempotency-Key = clientEntryId)
 *   GET  /v2/entries/today  your entries on today's calendar day where you are, oldest first
 * Neither calls the brain while answering: a new row is handed to ingest after
 * the response (startIngest), and if the brain can't be reached the row stays
 * pending for its next sweep. Nothing here is open to waitlisted people.
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
    logCounts: (r) => (r.skewed ? { clockSkew: 1 } : {}),
  }));
}
