import assert from 'node:assert/strict';
import test from 'node:test';
import {
  CONTENT_TYPE_CLASS,
  classOf,
  deriveDedupKey,
  localDay,
  normalizeForDedup,
} from '../src/services/dedup-key.js';
import { ContentTypeSchema } from '../src/types/index.js';

/**
 * The first tests in the backend.
 *
 * Every case below is built from a shape measured in production on
 * 18 October 2026, not from an imagined one. The two duplicate patterns found
 * there need different rules, and a single test against the obvious key --
 * (content, content_date) -- would pass for one and fail silently for the other.
 */

const USER = '7e0acfa3-fda9-4a0b-a4ec-3fca7a323266';

function distinctKeys(results: { key: string }[]): number {
  return new Set(results.map((r) => r.key)).size;
}

test('the HealthKit copies collapse to one: 188 uploads, one day, thirteen upload dates', () => {
  // The largest duplicate group in production. Identical text, one
  // content_date, uploaded on thirteen different days.
  const body = 'Apple Health summary for May 17, 2026:\n\nSteps: 14060\nActive Energy: 612 kcal';
  const keys = Array.from({ length: 188 }, () =>
    deriveDedupKey({
      userId: USER,
      contentType: 'healthkit',
      content: body,
      contentDate: '2026-05-17T00:00:00Z',
    }),
  );

  assert.equal(distinctKeys(keys), 1, '188 identical summaries are one summary');
  assert.equal(keys[0]!.strategy, 'content_hash');
});

test('the Google Doc copies collapse too: one body, 74 different dates', () => {
  // The case that makes (content, content_date) the wrong key. The uploader
  // stamped every copy of the same document with a different date.
  const body = '1. Describe your company or idea in a single sentence\r\nRetrospect is...';
  const keys = Array.from({ length: 74 }, (_, i) =>
    deriveDedupKey({
      userId: USER,
      contentType: 'google_docs',
      content: body,
      contentDate: new Date(Date.UTC(2026, 4, 1 + (i % 28), i % 24)).toISOString(),
    }),
  );

  assert.equal(distinctKeys(keys), 1, 'the date is excluded for synced content, so all 74 are one');
});

test('a source that names its own object is keyed on that, not on its text', () => {
  // iOS already sends a day key for HealthKit through the integrations path.
  // When a source gives an identity, it beats hashing -- and it survives a
  // re-sync in which one number ticked over.
  const a = deriveDedupKey({
    userId: USER,
    contentType: 'healthkit',
    content: 'Steps: 14060',
    metadata: { sync_day: '2026-05-17' },
  });
  const b = deriveDedupKey({
    userId: USER,
    contentType: 'healthkit',
    content: 'Steps: 14061',
    metadata: { sync_day: '2026-05-17' },
  });

  assert.equal(a.strategy, 'sync_day');
  assert.equal(a.key, b.key, 'same day, updated figure: same object');
});

test('provider object id wins over sync day', () => {
  const r = deriveDedupKey({
    userId: USER,
    contentType: 'gmail',
    content: 'anything',
    metadata: { provider_object_id: 'msg-123', sync_day: '2026-05-17' },
  });
  assert.equal(r.strategy, 'provider_object_id');
});

test('the same sentence on two different days is two entries — the over-dedup guard', () => {
  // The opposite failure. Somebody who goes to the gym on Monday and on Friday
  // has two real instances, and the pattern promoter counts instances. Merging
  // these would understate a real habit.
  const monday = deriveDedupKey({
    userId: USER,
    contentType: 'journal_entry',
    content: 'went to the gym',
    contentDate: '2026-10-12T08:00:00Z',
  });
  const friday = deriveDedupKey({
    userId: USER,
    contentType: 'journal_entry',
    content: 'went to the gym',
    contentDate: '2026-10-16T08:00:00Z',
  });

  assert.notEqual(monday.key, friday.key, 'two days, two entries');
  assert.equal(monday.strategy, 'content_hash_day');
});

test('the same sentence twice in one day is one entry', () => {
  // A double-tap, or a retry from the transcript screen, which stamps each
  // attempt with a fresh Date() -- so exact-timestamp matching would miss it.
  const morning = deriveDedupKey({
    userId: USER,
    contentType: 'journal_entry',
    content: 'went to the gym',
    contentDate: '2026-10-12T08:00:00Z',
  });
  const noon = deriveDedupKey({
    userId: USER,
    contentType: 'journal_entry',
    content: 'went to the gym',
    contentDate: '2026-10-12T12:00:00Z',
  });

  assert.equal(morning.key, noon.key);
});

test('normalisation catches trivial differences and nothing more', () => {
  assert.equal(normalizeForDedup('  Went to   the GYM \n'), 'went to the gym');

  // Punctuation is kept on purpose. Normalising further would start deciding
  // that two different sentences mean the same thing, which is the promoter's
  // job, not this one's.
  assert.notEqual(normalizeForDedup('went to the gym.'), normalizeForDedup('went to the gym?'));
});

test('the calendar day is computed in the writer\'s zone, not by slicing the string', () => {
  // One instant, two zones. 06:30 UTC on 13 Oct is still 12 Oct in Los Angeles.
  const instant = new Date('2026-10-13T06:30:00Z');
  assert.equal(localDay(instant, 'UTC'), '2026-10-13');
  assert.equal(localDay(instant, 'America/Los_Angeles'), '2026-10-12');
});

test('with a time zone, entries either side of UTC midnight but on one local day are one entry', () => {
  // 17:00 and 23:00 in Los Angeles are 00:00 and 06:00 UTC the next day. Same
  // local day; without the zone they would split across two UTC days.
  const evening = deriveDedupKey({
    userId: USER,
    contentType: 'journal_entry',
    content: 'long day',
    contentDate: '2026-10-13T00:00:00Z',
    timeZone: 'America/Los_Angeles',
  });
  const night = deriveDedupKey({
    userId: USER,
    contentType: 'journal_entry',
    content: 'long day',
    contentDate: '2026-10-13T06:00:00Z',
    timeZone: 'America/Los_Angeles',
  });

  assert.equal(evening.key, night.key);
});

test('without a time zone the boundary is UTC midnight — the known, safe-direction gap', () => {
  // Nothing sends a zone today: the API rejects offsets and iOS sends UTC. So
  // identical entries straddling UTC midnight count as two. That keeps a
  // duplicate rather than losing a real entry, which is the right way to fail.
  const before = deriveDedupKey({
    userId: USER,
    contentType: 'journal_entry',
    content: 'long day',
    contentDate: '2026-10-12T23:30:00Z',
  });
  const after = deriveDedupKey({
    userId: USER,
    contentType: 'journal_entry',
    content: 'long day',
    contentDate: '2026-10-13T00:30:00Z',
  });

  assert.notEqual(before.key, after.key);
});

test('an unknown time zone falls back to UTC instead of failing the upload', () => {
  assert.equal(localDay(new Date('2026-10-13T06:30:00Z'), 'Not/A_Zone'), '2026-10-13');
});

test('an explicit idempotency key always wins', () => {
  // The escape hatch: the caller knows whether this is a retry better than
  // any rule does, including for a document re-uploaded on purpose.
  const a = deriveDedupKey({
    userId: USER,
    contentType: 'google_docs',
    content: 'same body',
    idempotencyKey: 'upload-1',
  });
  const b = deriveDedupKey({
    userId: USER,
    contentType: 'google_docs',
    content: 'same body',
    idempotencyKey: 'upload-2',
  });

  assert.equal(a.strategy, 'explicit_key');
  assert.notEqual(a.key, b.key, 'two keys, two uploads, even with identical content');
});

test('onboarding is one per user, however many times it is sent', () => {
  // Two separate screens in the iOS app each post an onboarding profile today.
  const first = deriveDedupKey({ userId: USER, contentType: 'onboarding_profile', content: 'v1' });
  const second = deriveDedupKey({ userId: USER, contentType: 'onboarding_profile', content: 'v2' });

  assert.equal(first.strategy, 'singleton');
  assert.equal(first.key, second.key);
});

test('keys never collide across users or across content types', () => {
  const base = { contentType: 'healthkit', content: 'Steps: 1' };
  const userA = deriveDedupKey({ ...base, userId: 'a' });
  const userB = deriveDedupKey({ ...base, userId: 'b' });
  const otherType = deriveDedupKey({ ...base, userId: 'a', contentType: 'screen_time' });

  assert.notEqual(userA.key, userB.key);
  assert.notEqual(userA.key, otherType.key);
});

test('every accepted content type has an explicit class', () => {
  // The guard that keeps this correct as integrations are added. A new
  // human-authored type silently defaulting to `machine` would have its
  // repeated entries merged; this fails loudly instead.
  const unmapped = ContentTypeSchema.options.filter((t) => !(t in CONTENT_TYPE_CLASS));
  assert.deepEqual(unmapped, [], `add these to CONTENT_TYPE_CLASS: ${unmapped.join(', ')}`);
});

test('an unknown type is treated as machine, the safe direction', () => {
  assert.equal(classOf('some_future_integration'), 'machine');
});
