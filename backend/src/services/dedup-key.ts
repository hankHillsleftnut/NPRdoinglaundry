/**
 * Deciding whether two uploads are the same thing.
 *
 * `POST /content` has always inserted whatever it was given. Measured against
 * production on 18 October 2026, one user's 1,000 most recent rows held only
 * 179 distinct pieces of content. One HealthKit day-summary had been written
 * 188 times; one Google Doc 74 times.
 *
 * Storage is the smaller cost. Every insert starts an agent ingest run, so 188
 * copies meant 188 runs. And the pattern promoter decides what counts as a
 * habit by counting how often something recurs -- so duplicates do not merely
 * waste money, they let a sync bug present itself as a person's defining
 * behaviour.
 *
 * The obvious key, (content, content_date), is wrong. It catches the HealthKit
 * copies, which share one date. It misses every one of the 74 Google Doc copies,
 * because the uploader stamped each with a different date. The two duplicate
 * patterns in the real data need different rules.
 *
 * So content types are sorted into three classes, and each class gets one rule.
 * Twenty per-type policies would be twenty chances to be wrong, and every new
 * integration would add another.
 *
 * Everything here is pure -- no database, no clock unless injected -- so the
 * policy can be tested against the exact shapes found in production.
 */
import { createHash } from 'node:crypto';

/**
 * How a content type behaves when it is uploaded more than once.
 *
 * - `machine` -- produced by a sync. Identical text is the same object, whatever
 *   date it was stamped with. A HealthKit summary embeds its own date in the body.
 * - `human` -- written by a person. Identical text on two different days is two
 *   real instances: "went to the gym" on Monday and on Friday are both true, and
 *   swallowing the second would understate a genuine pattern.
 * - `singleton` -- one per user. The latest write is the only one that matters.
 */
export type DedupClass = 'machine' | 'human' | 'singleton';

/** Which rule produced a key. Stored so a later policy change can be re-derived
 *  for only the rows that rule affected, rather than for everything. */
export type DedupStrategy =
  | 'explicit_key'
  | 'provider_object_id'
  | 'sync_day'
  | 'content_hash'
  | 'content_hash_day'
  | 'singleton';

/**
 * Every content type the API accepts, mapped to its class.
 *
 * Deliberately exhaustive rather than defaulting silently: a test asserts every
 * member of ContentTypeSchema appears here, so adding a new human-authored type
 * fails loudly instead of being treated as a machine source and over-deduplicated.
 */
export const CONTENT_TYPE_CLASS: Record<string, DedupClass> = {
  // Written by a person.
  journal_entry: 'human',
  voice_journal: 'human',
  voice_recording: 'human',
  text_entry: 'human',
  video_entry: 'human',

  // One per user.
  onboarding_profile: 'singleton',

  // Produced by a sync.
  google_docs: 'machine',
  healthkit: 'machine',
  calendar: 'machine',
  screen_time: 'machine',
  twitter_bookmarks: 'machine',
  apple_music: 'machine',
  photos: 'machine',
  contacts: 'machine',
  // Gmail carries the person's own words, but for deduplication it is still a
  // synced object: an identical message body is the same email. Whose words
  // they are matters to extraction, not to whether something arrived twice.
  gmail: 'machine',
  spotify: 'machine',
  youtube: 'machine',
  reddit: 'machine',
  x: 'machine',
  tiktok: 'machine',
};

/**
 * The class for a type. An unknown type is treated as `machine`: new types are
 * nearly always integrations, and it is the safer direction -- a machine source
 * wrongly treated as human floods the bank with copies, which is the exact
 * failure this module exists to stop.
 */
export function classOf(contentType: string): DedupClass {
  return CONTENT_TYPE_CLASS[contentType] ?? 'machine';
}

export interface DedupInput {
  userId: string;
  contentType: string;
  content: string;
  /** The effective date of the content, ISO 8601. Callers pass the same default
   *  the route already applies, so "no date given" behaves as "now". */
  contentDate?: string | null;
  metadata?: Record<string, unknown> | null;
  /** An `Idempotency-Key` header. Always wins when present. */
  idempotencyKey?: string | null;
  /**
   * IANA time zone of the writer, for deciding which calendar day a human entry
   * belongs to.
   *
   * Today nothing supplies this. The API's date validation rejects offsets, and
   * iOS sends UTC, so the writer's local day never reaches the server. Without
   * it the day is the UTC day -- which means two identical entries written
   * either side of UTC midnight count as two. That errs toward keeping a
   * duplicate rather than losing a real entry, which is the safe direction. One
   * line on the client (`TimeZone.current.identifier`) closes it.
   */
  timeZone?: string | null;
  /** Injected for testing. Used only when a human entry has no date. */
  now?: Date;
}

export interface DedupResult {
  key: string;
  strategy: DedupStrategy;
  dedupClass: DedupClass;
}

/**
 * Normalise human text for exact-replay detection, and nothing more.
 *
 * Unicode form, trimmed, internal whitespace collapsed, lowercased. No
 * stemming, no punctuation stripping, nothing semantic. The question here is
 * "was this the same upload sent twice", not "do these two entries mean the
 * same thing" -- the second question belongs to the promoter, and answering it
 * here would quietly merge two different thoughts.
 */
export function normalizeForDedup(text: string): string {
  return text.normalize('NFC').trim().replace(/\s+/g, ' ').toLowerCase();
}

/**
 * The calendar day an instant falls on, in a given time zone, as YYYY-MM-DD.
 *
 * Done with Intl rather than by slicing the ISO string, because slicing gives the
 * UTC day regardless of the zone asked for -- the same instant written as
 * "+00:00" and as "-07:00" would land on different days for no reason.
 */
export function localDay(instant: Date, timeZone?: string | null): string {
  const zone = timeZone || 'UTC';
  try {
    const parts = new Intl.DateTimeFormat('en-CA', {
      timeZone: zone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).formatToParts(instant);
    const get = (t: string) => parts.find((p) => p.type === t)?.value ?? '';
    return `${get('year')}-${get('month')}-${get('day')}`;
  } catch {
    // An unrecognised zone from a client should not fail the upload. Fall back
    // to UTC, which is what every request gets today anyway.
    return instant.toISOString().slice(0, 10);
  }
}

function sha256(value: string): string {
  return createHash('sha256').update(value).digest('hex');
}

/**
 * A string identifying one logical piece of content for one user.
 *
 * The parts are joined with a NUL separator so that no two different inputs
 * can concatenate to the same string ("ab" + "c" versus "a" + "bc").
 */
function keyOf(userId: string, contentType: string, scope: string): string {
  return sha256([userId, contentType, scope].join('\u0000'));
}

function stringField(metadata: Record<string, unknown> | null | undefined, field: string): string | null {
  const value = metadata?.[field];
  return typeof value === 'string' && value.trim() !== '' ? value.trim() : null;
}

/**
 * The client's own key for an upload, if it sent one: the Idempotency-Key
 * header, else metadata.client_event_id, trimmed. The one definition both the
 * dedup key and the route's length check use.
 */
export function explicitKeyOf(
  idempotencyKey: string | null | undefined,
  metadata: Record<string, unknown> | null | undefined,
): string | null {
  return (idempotencyKey && idempotencyKey.trim()) || stringField(metadata, 'client_event_id');
}

/**
 * Work out the deduplication key for an upload.
 *
 * Order of precedence:
 *
 * 0. An explicit key -- an `Idempotency-Key` header, or `metadata.client_event_id`.
 *    The caller knows better than any rule whether this is a retry, so this
 *    always wins. It is also the escape hatch: re-uploading a document on
 *    purpose under a new key is never collapsed.
 * 1. `machine` -- the source's own identity when it gives one
 *    (`provider_object_id`, then `sync_day`), else the content alone, date
 *    excluded. Excluding the date is what catches the 74 Google Doc copies.
 * 2. `human` -- the normalised content plus the calendar day. Same text twice in
 *    a day is one entry; the same text on two days is two.
 * 3. `singleton` -- constant per user.
 */
export function deriveDedupKey(input: DedupInput): DedupResult {
  const { userId, contentType, content, metadata } = input;
  const dedupClass = classOf(contentType);

  const explicit = explicitKeyOf(input.idempotencyKey, metadata);
  if (explicit) {
    return { key: keyOf(userId, contentType, `explicit:${explicit}`), strategy: 'explicit_key', dedupClass };
  }

  if (dedupClass === 'singleton') {
    return { key: keyOf(userId, contentType, 'singleton'), strategy: 'singleton', dedupClass };
  }

  if (dedupClass === 'machine') {
    const providerObjectId = stringField(metadata, 'provider_object_id');
    if (providerObjectId) {
      return {
        key: keyOf(userId, contentType, `object:${providerObjectId}`),
        strategy: 'provider_object_id',
        dedupClass,
      };
    }
    const syncDay = stringField(metadata, 'sync_day');
    if (syncDay) {
      return { key: keyOf(userId, contentType, `day:${syncDay}`), strategy: 'sync_day', dedupClass };
    }
    return {
      key: keyOf(userId, contentType, `content:${sha256(content)}`),
      strategy: 'content_hash',
      dedupClass,
    };
  }

  // human
  const instant = input.contentDate ? new Date(input.contentDate) : (input.now ?? new Date());
  const day = Number.isNaN(instant.getTime())
    ? localDay(input.now ?? new Date(), input.timeZone)
    : localDay(instant, input.timeZone);
  return {
    key: keyOf(userId, contentType, `content:${sha256(normalizeForDedup(content))}:day:${day}`),
    strategy: 'content_hash_day',
    dedupClass,
  };
}
