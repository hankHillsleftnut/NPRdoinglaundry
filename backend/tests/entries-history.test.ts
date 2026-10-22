/**
 * BE1.5 over HTTP on the real app (harness), with entries on a real Postgres
 * (PGlite, migrations 022 and 023, run as service_role): the drawer's pages
 * never skip or repeat, search escapes the person's wildcards and reports
 * UTF-16 ranges, and one entry is the caller's own or not there.
 */
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import test, { after, before } from 'node:test';
import { asServiceRole, freshDatabase, insertUser, type PGlite } from './support/database.js';
import { pgliteRpc } from './support/pglite-rpc.js';
import { doorSuite } from './support/door-suite.js';
import { startHarness, type Harness } from './support/harness.js';
import { supabaseEntryStore, type EntryStore } from '../src/entries/store.js';
import { LIST_LIMIT, MAX_QUERY_UNITS, decodeCursor, encodeCursor, likePattern, matchRanges } from '../src/entries/doors.js';

const FIXTURES = join(__dirname, '..', '..', 'docs', 'team', 'contracts', 'fixtures', '02');
const fixture = <T = unknown>(name: string) => (JSON.parse(readFileSync(join(FIXTURES, name), 'utf8')) as { data: T }).data;
const data = <T>(body: unknown) => (body as { data: T }).data;
const code = (body: unknown) => (body as { error?: { code?: string } }).error?.code;
type Entry = { id: string; kind: string; text: string; createdAt: string; day: string; reading: string; clientEntryId?: string; matches?: { start: number; length: number }[] };
type Page = { entries: Entry[]; nextCursor: string | null };

const T0 = Date.parse('2026-10-21T23:00:00.000Z');
const USER = '11111111-1111-4111-8111-111111111111';
const OTHER = '22222222-2222-4222-8222-222222222222';
let db: PGlite;
let entries: EntryStore;

function asService<T extends object>(store: T): T {
  return Object.fromEntries(Object.entries(store).map(([k, fn]) => [k, (...a: unknown[]) => asServiceRole(db, () => (fn as (...x: unknown[]) => Promise<unknown>)(...a))])) as T;
}

before(async () => {
  db = await freshDatabase();
  entries = asService(supabaseEntryStore(pgliteRpc(db)));
  for (const id of [USER, OTHER]) await db.query(`INSERT INTO users (id, apple_user_id, access) VALUES ($1, $2, 'member')`, [id, `apple-${id}`]);
});
after(async () => { await db.close(); });

const harness = () => startHarness({ entries, now: T0 });
async function person(h: Harness): Promise<string> {
  const id = await insertUser(db);
  await db.query(`UPDATE users SET access = 'member' WHERE id = $1`, [id]);
  h.users.set(id, { id, appleUserId: `apple-${id}`, access: 'member' });
  return id;
}
const as = (h: Harness, id: string, extra: Record<string, string> = {}) => ({ Authorization: `Bearer ${h.asUser(id)}`, ...extra });
const list = (h: Harness, id: string, query = '', extra: Record<string, string> = {}) => h.request('GET', `/v2/entries${query ? `?${query}` : ''}`, undefined, as(h, id, extra));
const get = (h: Harness, id: string, entryId: string) => h.request('GET', `/v2/entries/${entryId}`, undefined, as(h, id));

const statusOf = { read: 'completed', reading: 'processing', waiting: 'pending', failed: 'failed' } as const;
const typeOf = { typed: 'journal_entry', voice: 'voice_journal', imported: 'shared_link', conversation: 'conversation' } as const;
/** A row as a fixture describes it (ids fixed), or a plain one. */
const insert = (user: string, e: { id?: string; type?: string; text: string; at: string; status?: string; clientEntryId?: string }) => db.query<{ id: string }>(
  `INSERT INTO raw_content (id, user_id, content_type, content, content_date, metadata, processing_status, created_at)
   VALUES (COALESCE($1, uuid_generate_v4()), $2, $3, $4, $5, $6, $7, $5) RETURNING id`,
  [e.id ?? null, user, e.type ?? 'journal_entry', e.text, e.at, JSON.stringify(e.clientEntryId ? { client_entry_id: e.clientEntryId } : {}), e.status ?? 'completed'],
).then((r) => r.rows[0]!.id);
const insertFixture = (user: string, e: Entry) => insert(user, {
  id: e.id, type: typeOf[e.kind as keyof typeof typeOf], text: e.text, at: e.createdAt, status: statusOf[e.reading as keyof typeof statusOf], ...(e.clientEntryId ? { clientEntryId: e.clientEntryId } : {}),
});

test('the list, its last page, search and one entry equal the contract fixtures exactly', async () => {
  const h = await harness();
  try {
    const sam = await person(h);
    const page = fixture<Page>('entries.list.json');
    for (const e of page.entries) await insertFixture(sam, e);
    // Noise: records of their own and another person's words.
    await insert(sam, { type: 'calendar', text: 'dentist 15:00', at: '2026-10-21T15:00:00.000Z' });
    await insert(await person(h), { text: 'someone else today', at: '2026-10-21T19:00:00.000Z' });
    const first = await list(h, sam, 'limit=3');
    assert.equal(first.status, 200);
    assert.deepEqual(data(first.body), page, 'newest first, with the cursor of the last entry');
    const after102 = encodeCursor({ atUs: Date.parse(page.entries[1]!.createdAt) * 1000, id: page.entries[1]!.id });
    assert.deepEqual(data((await list(h, sam, `cursor=${after102}&limit=3`)).body), fixture('entries.list.last.json'), 'a short page is the end');
    assert.deepEqual(data((await list(h, sam, `cursor=${encodeURIComponent(page.nextCursor!)}`)).body), { entries: [], nextCursor: null }, 'past the end');
    assert.deepEqual(data((await list(h, sam, 'q=canal')).body), fixture('entries.search.json'));
    assert.deepEqual(data((await list(h, sam, 'q=zebra')).body), fixture('entries.search.empty.json'));
    const astral = fixture<Page>('entries.search.astral.json');
    await insertFixture(sam, astral.entries[0]!);
    const canals = data<Page>((await list(h, sam, 'q=Canal')).body);
    assert.deepEqual(canals.entries.map((e) => e.id), [page.entries[1]!.id, astral.entries[0]!.id], 'newest first, any case');
    assert.deepEqual(canals.entries[1], astral.entries[0], 'the astral fixture exactly: units, not scalars');
    assert.deepEqual(data((await get(h, sam, page.entries[2]!.id)).body), fixture('entry.json'));
    assert.equal(h.agentCalls.length, 0, 'the brain is never called');
    assert.equal(h.logLines.join('').includes('canal'), false, 'no words in the log');
  } finally {
    await h.close();
  }
});

test('paging never repeats or skips an entry, even with equal timestamps (*)', async () => {
  const h = await harness();
  try {
    const sam = await person(h);
    const ids = new Set<string>();
    for (let i = 0; i < 7; i++) ids.add(await insert(sam, { text: `same moment ${i}`, at: '2026-10-19T10:00:00.000Z' }));
    for (let i = 0; i < 4; i++) ids.add(await insert(sam, { text: `later ${i}`, at: `2026-10-20T10:00:0${i}.000Z` }));
    const seen: string[] = [];
    let cursor: string | null = null;
    let pages = 0;
    do {
      const page: Page = data<Page>((await list(h, sam, `limit=3${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ''}`)).body);
      seen.push(...page.entries.map((e) => e.id));
      cursor = page.nextCursor;
      pages++;
      assert.ok(pages < 10, 'the walk ends');
    } while (cursor);
    assert.equal(new Set(seen).size, seen.length, 'no entry twice');
    assert.deepEqual(new Set(seen), ids, 'every entry once');
    // A new entry arriving mid-walk sits above the first page and shifts nothing below the cursor.
    const firstPage = data<Page>((await list(h, sam, 'limit=3')).body);
    await insert(sam, { text: 'brand new', at: '2026-10-21T12:00:00.000Z' });
    const secondPage = data<Page>((await list(h, sam, `limit=3&cursor=${encodeURIComponent(firstPage.nextCursor!)}`)).body);
    assert.equal(secondPage.entries.some((e) => firstPage.entries.some((f) => f.id === e.id)), false);
    assert.equal(secondPage.entries.some((e) => e.text === 'brand new'), false);
  } finally {
    await h.close();
  }
});

test('search escapes % _ and \\, matches every occurrence case-insensitively, and reports UTF-16 ranges (*)', async () => {
  const h = await harness();
  try {
    const sam = await person(h);
    for (const text of ['50% done', '50 percent done', 'a_b', 'a-b', 'back\\slash', 'Canal, canal, CANAL', '😀😀 canal boat']) {
      await insert(sam, { text, at: '2026-10-20T10:00:00.000Z' });
    }
    const texts = async (q: string) => data<Page>((await list(h, sam, `q=${encodeURIComponent(q)}`)).body).entries.map((e) => [e.text, e.matches] as const);
    assert.deepEqual((await texts('50%')).map(([t]) => t), ['50% done'], 'a percent sign is a percent sign');
    assert.deepEqual((await texts('a_b')).map(([t]) => t), ['a_b'], 'an underscore is an underscore');
    assert.deepEqual((await texts('\\')).map(([t]) => t), ['back\\slash']);
    const many = (await texts('canal')).find(([t]) => t.startsWith('Canal'))!;
    assert.deepEqual(many[1], [{ start: 0, length: 5 }, { start: 7, length: 5 }, { start: 14, length: 5 }], 'all occurrences, any case');
    const astral = (await texts('canal')).find(([t]) => t.startsWith('😀'))!;
    assert.deepEqual(astral[1], [{ start: 5, length: 5 }], 'two emoji are four UTF-16 units, not two');
    assert.equal(likePattern('a%b_c\\d'), '%a\\%b\\_c\\\\d%');
    assert.deepEqual(matchRanges('Ab ab', 'AB'), [{ start: 0, length: 2 }, { start: 3, length: 2 }]);
  } finally {
    await h.close();
  }
});

test('NUL in a search is invalid_request before the entry store is called', async (t) => {
  const listStore = t.mock.method(entries, 'list');
  const h = await harness();
  try {
    const sam = await person(h);
    for (const q of ['\0', '\0canal', 'ca\0nal', 'canal\0']) {
      const response = await list(h, sam, `q=${encodeURIComponent(q)}`);
      assert.equal(response.status, 400);
      assert.equal(code(response.body), 'invalid_request');
    }
    assert.equal(listStore.mock.callCount(), 0);
    for (const q of ['x', 'x'.repeat(MAX_QUERY_UNITS)]) {
      assert.equal((await list(h, sam, `q=${q}`)).status, 200);
    }
  } finally {
    await h.close();
  }
});

test('a malformed cursor, limit or q is invalid_request; the default page is 50 and the ceiling 100', async () => {
  const h = await harness();
  try {
    const sam = await person(h);
    for (const bad of ['cursor=not-base64-of-anything', `cursor=${Buffer.from('12|not-a-uuid').toString('base64url')}`, 'limit=0', 'limit=101', 'limit=abc', 'limit=1.5', 'q=', `q=${'x'.repeat(MAX_QUERY_UNITS + 1)}`, 'userId=x']) {
      assert.equal(code((await list(h, sam, bad)).body), 'invalid_request', bad);
    }
    assert.equal(decodeCursor(Buffer.from('99999999999999999999|11111111-1111-4111-8111-111111111111').toString('base64url')), null, 'a moment past the safe range');
    for (let i = 0; i < LIST_LIMIT.max + 1; i++) await insert(sam, { text: `n ${i}`, at: new Date(T0 - 100_000 - i * 1000).toISOString() });
    assert.equal(data<Page>((await list(h, sam)).body).entries.length, LIST_LIMIT.default);
    assert.equal(data<Page>((await list(h, sam, 'limit=100')).body).entries.length, LIST_LIMIT.max);
    assert.equal(data<Page>((await list(h, sam, 'limit=1')).body).entries[0]!.text, 'n 0', 'newest first');
  } finally {
    await h.close();
  }
});

test("another person's entry is not_found on get, as is a record of your own and an id that isn't there (*)", async () => {
  const h = await harness();
  try {
    const [sam, priya] = [await person(h), await person(h)];
    const hers = await insert(priya, { text: 'priya wrote this', at: '2026-10-20T10:00:00.000Z' });
    const record = await insert(sam, { type: 'calendar', text: 'a meeting', at: '2026-10-20T10:00:00.000Z' });
    const mine = await insert(sam, { text: 'mine', at: '2026-10-20T10:00:00.000Z' });
    assert.equal((await get(h, sam, mine)).status, 200);
    const theirs = await get(h, sam, hers);
    assert.equal(theirs.status, 404);
    assert.equal(code(theirs.body), 'not_found');
    assert.equal(JSON.stringify(theirs.body).includes('priya'), false);
    assert.equal(code((await get(h, sam, record)).body), 'not_found', 'records are not entries');
    assert.equal(code((await get(h, sam, '00000000-0000-4000-8000-00000000dead')).body), 'not_found');
    assert.equal(code((await get(h, sam, 'not-a-uuid')).body), 'invalid_request');
    assert.equal(data<Page>((await list(h, sam)).body).entries.some((e) => e.text.includes('priya')), false, 'the list is yours alone');
    assert.equal(data<{ entry: Entry }>((await get(h, sam, mine, )).body).entry.day, '2026-10-20');
    const zoned = await h.request('GET', `/v2/entries/${mine}`, undefined, as(h, sam, { 'X-Time-Zone': 'Pacific/Kiritimati' }));
    assert.equal(data<{ entry: Entry }>(zoned.body).entry.day, '2026-10-21', 'day follows the zone (UTC+14)');
  } finally {
    await h.close();
  }
});

// The door suites. "another user's id" is a row of OTHER's; USER's own row is the entry fixture.
const stores = () => ({ entries });
const stored = fixture<{ entry: Entry }>('entry.json').entry;
const seedOwn = async () => { await db.query(`DELETE FROM raw_content WHERE id = $1`, [stored.id]); await insertFixture(USER, stored); };

doorSuite({
  method: 'GET', path: '/v2/entries', bucket: 'read',
  invalid: { query: 'userId=someone' },
  expect: () => ({ entries: [], nextCursor: null }),
  stores, now: T0,
});

doorSuite({
  method: 'GET', path: `/v2/entries/${stored.id}`, bucket: 'read',
  invalid: { query: 'all=true' },
  otherUsersThing: async () => `/v2/entries/${await insert(OTHER, { text: 'theirs', at: '2026-10-20T10:00:00.000Z' })}`,
  pathFor: () => `/v2/entries/${stored.id}`,
  setup: () => seedOwn(),
  expect: () => fixture('entry.json'),
  stores, now: T0,
});
