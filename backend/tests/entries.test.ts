/**
 * BE1.1 over HTTP on the real app (harness), with entries on a real Postgres
 * (PGlite, migration 022's functions, run as service_role): one send is one
 * row and one read, a retry is the same row and no second read, the same key
 * with other words is a mismatch, and "today" is the person's own words on
 * their own calendar day. The brain's hand-off is a recorder here.
 */
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import test, { after, before } from 'node:test';
import { asServiceRole, freshDatabase, insertUser, type PGlite } from './support/database.js';
import { pgliteRpc } from './support/pglite-rpc.js';
import { startHarness, type Harness } from './support/harness.js';
import { supabaseEntryStore, type EntryStore } from '../src/entries/store.js';
import { CLOCK_SKEW_MS, MAX_ENTRY_UNITS, SENT_TYPES, TODAY_LIMIT } from '../src/entries/doors.js';

const FIXTURES = join(__dirname, '..', '..', 'docs', 'team', 'contracts', 'fixtures', '02');
const fixture = <T = unknown>(name: string) => JSON.parse(readFileSync(join(FIXTURES, name), 'utf8')) as T;
const data = <T>(body: unknown) => (body as { data: T }).data;
const code = (body: unknown) => (body as { error?: { code?: string } }).error?.code;
type Entry = { id: string; kind: string; text: string; createdAt: string; day: string; reading: string; clientEntryId?: string };

/** 21 Oct, 23:00Z: the fixtures' day in UTC. */
const T0 = Date.parse('2026-10-21T23:00:00.000Z');
let db: PGlite;
let entries: EntryStore;

function asService<T extends object>(store: T): T {
  return Object.fromEntries(Object.entries(store).map(([k, fn]) => [k, (...a: unknown[]) => asServiceRole(db, () => (fn as (...x: unknown[]) => Promise<unknown>)(...a))])) as T;
}

before(async () => {
  db = await freshDatabase();
  entries = asService(supabaseEntryStore(pgliteRpc(db)));
});
after(async () => { await db.close(); });

let seq = 0;
const uuid = () => `00000000-0000-4000-8000-${String(++seq).padStart(12, '0')}`;

async function harness(now = T0) {
  const ingested: { userId: string; id: string }[] = [];
  const h = await startHarness({ entries, now, startIngest: (userId, id) => { ingested.push({ userId, id }); } });
  return Object.assign(h, { ingested });
}
async function person(h: Harness, firstName?: string): Promise<string> {
  const id = await insertUser(db);
  await db.query(`UPDATE users SET access = 'member', first_name = $2 WHERE id = $1`, [id, firstName ?? null]);
  h.users.set(id, { id, appleUserId: `apple-${id}`, access: 'member' });
  return id;
}
const as = (h: Harness, id: string, extra: Record<string, string> = {}) => ({ Authorization: `Bearer ${h.asUser(id)}`, 'X-App-Version': '1.0 (42)', ...extra });
const draft = (over: Partial<{ text: string; kind: string; clientEntryId: string; createdAt: string }> = {}) =>
  ({ text: 'dentist at 3 today, dreading it', kind: 'typed', clientEntryId: uuid(), createdAt: '2026-10-21T13:02:11.410Z', ...over });
/** Sends with the key the app sends: the body's clientEntryId, lowercase, unless `key` says otherwise. */
const send = (h: Harness, id: string, body: Record<string, unknown>, extra: Record<string, string> = {}, key?: string | null) =>
  h.request('POST', '/v2/entries', body, as(h, id, { ...(key === null ? {} : { 'Idempotency-Key': key ?? String(body.clientEntryId) }), ...extra }));
const today = (h: Harness, id: string, extra: Record<string, string> = {}) => h.request('GET', '/v2/entries/today', undefined, as(h, id, extra));
const rows = async (userId: string) => (await db.query<{ content_type: string; content: string; content_date: string; status: string; metadata: Record<string, unknown> }>(
  `SELECT content_type, content, content_date, processing_status AS status, metadata FROM raw_content WHERE user_id = $1 ORDER BY content_date, id`, [userId])).rows;

test('a send creates one row and one ingest, in the shape of the contract fixture', async () => {
  const h = await harness();
  try {
    const sam = await person(h);
    const body = fixture<{ clientEntryId: string; text: string; createdAt: string }>('entry.create.request.json');
    const res = await send(h, sam, body);
    assert.equal(res.status, 201);
    const expected = fixture<{ data: { entry: Entry } }>('entry.create.response.json').data.entry;
    const got = data<{ entry: Entry }>(res.body).entry;
    assert.deepEqual(got, { ...expected, id: got.id }, 'the fixture, bar the row id');
    assert.deepEqual(h.ingested, [{ userId: sam, id: got.id }], 'one read started, for this row');
    const [row] = await rows(sam);
    assert.equal(row!.content_type, 'journal_entry');
    assert.equal(row!.status, 'pending');
    assert.equal(new Date(row!.content_date).toISOString(), body.createdAt, "the person's moment, not the server's");
    assert.deepEqual(Object.keys(row!.metadata).sort(), ['app_version', 'client_entry_id', 'request_hash']);
    assert.equal(row!.metadata.app_version, '1.0 (42)');

    const voice = await send(h, sam, fixture('entry.create.request.voice.json'));
    assert.equal(voice.status, 201);
    assert.equal(data<{ entry: Entry }>(voice.body).entry.kind, 'voice');
    assert.equal((await rows(sam))[1]!.content_type, 'voice_journal');
    assert.equal(h.ingested.length, 2);
    assert.equal(h.logLines.join('').includes('dentist'), false, 'no words in the log');
    assert.equal(h.logLines.join('').includes(body.clientEntryId), false, 'no ids either');
  } finally {
    await h.close();
  }
});

test('ten retries with the same key make one row and one ingest, and answer 200 with the stored entry', async () => {
  const h = await harness();
  try {
    const sam = await person(h);
    const body = draft();
    const first = await send(h, sam, body);
    assert.equal(first.status, 201);
    const retries = await Promise.all(Array.from({ length: 10 }, () => send(h, sam, body)));
    for (const r of retries) {
      assert.equal(r.status, 200, 'a replay');
      assert.deepEqual(r.body, first.body, 'the stored entry, byte for byte');
    }
    assert.equal((await rows(sam)).length, 1);
    assert.equal(h.ingested.length, 1, 'no second read');
    const upper = await send(h, sam, { ...body, clientEntryId: body.clientEntryId.toUpperCase() }, {}, body.clientEntryId.toUpperCase());
    assert.equal(upper.status, 200, 'the key compares case-insensitively');
    assert.deepEqual(upper.body, first.body);
    // At once: two retries racing for the first write still make one row.
    const race = draft();
    const results = await Promise.all([send(h, sam, race), send(h, sam, race)]);
    assert.deepEqual(results.map((r) => r.status).sort(), [200, 201]);
    assert.equal((await rows(sam)).length, 2);
    assert.equal(h.ingested.length, 2);
  } finally {
    await h.close();
  }
});

test('the same key with different text, or a different kind, is idempotency_mismatch and stores nothing (*)', async () => {
  const h = await harness();
  try {
    const sam = await person(h);
    const body = draft();
    assert.equal((await send(h, sam, body)).status, 201);
    const words = await send(h, sam, { ...body, text: 'something else entirely' });
    assert.equal(words.status, 409);
    assert.equal(code(words.body), 'idempotency_mismatch');
    const kind = await send(h, sam, { ...body, kind: 'voice' });
    assert.equal(code(kind.body), 'idempotency_mismatch', 'the same key sent as voice is not a second row');
    const later = await send(h, sam, { ...body, createdAt: '2026-10-21T13:02:12.000Z' });
    assert.equal(later.status, 200, 'createdAt is not part of the fingerprint: a clamped retry is still a replay');
    const padded = await send(h, sam, { ...body, text: `  ${body.text}\n` });
    assert.equal(padded.status, 200, 'trimmed text compares equal');
    assert.equal((await rows(sam)).length, 1);
    assert.equal(h.ingested.length, 1);
  } finally {
    await h.close();
  }
});

test('a future createdAt is clamped to now and counted, not refused (*)', async () => {
  const h = await harness();
  try {
    const sam = await person(h);
    const ahead = await send(h, sam, draft({ createdAt: new Date(T0 + CLOCK_SKEW_MS + 60_000).toISOString() }));
    assert.equal(ahead.status, 201);
    assert.equal(data<{ entry: Entry }>(ahead.body).entry.createdAt, new Date(T0).toISOString(), "the server's now");
    const line = JSON.parse(h.logLines.find((l) => l.includes('entries.create'))!) as Record<string, unknown>;
    assert.equal(line.clockSkew, 1, 'counted');
    assert.equal(Object.keys(line).includes('text'), false);
    const within = await send(h, sam, draft({ createdAt: new Date(T0 + CLOCK_SKEW_MS - 1000).toISOString() }));
    assert.equal(data<{ entry: Entry }>(within.body).entry.createdAt, new Date(T0 + CLOCK_SKEW_MS - 1000).toISOString(), 'a little ahead is kept');
    const old = await send(h, sam, draft({ createdAt: '2025-01-01T00:00:00.000Z' }));
    assert.equal(old.status, 201, 'no floor: an old offline entry is never thrown away');
    assert.equal(data<{ entry: Entry }>(old.body).entry.day, '2025-01-01');
    assert.equal(h.logLines.filter((l) => l.includes('clockSkew')).length, 1, 'only the clamped one is counted');
  } finally {
    await h.close();
  }
});

test('the Idempotency-Key must be present and equal to clientEntryId; the body is strict', async () => {
  const h = await harness();
  try {
    const sam = await person(h);
    const body = draft();
    assert.equal(code((await send(h, sam, body, {}, null)).body), 'invalid_request', 'missing');
    assert.equal(code((await send(h, sam, body, {}, uuid())).body), 'invalid_request', 'another id');
    assert.equal(code((await send(h, sam, { ...body, userId: sam })).body), 'invalid_request', 'a client-sent userId');
    assert.equal(code((await send(h, sam, { ...body, text: '   ' })).body), 'invalid_request', 'whitespace only');
    assert.equal(code((await send(h, sam, { ...body, kind: 'imported' })).body), 'invalid_request', 'a read-only kind');
    assert.equal(code((await send(h, sam, { ...body, clientEntryId: 'not-a-uuid' }, {}, 'not-a-uuid')).body), 'invalid_request');
    assert.equal(code((await send(h, sam, { ...body, createdAt: '2026-10-21T13:02:11.410+02:00' })).body), 'invalid_request', 'an offset');
    assert.equal(code((await send(h, sam, { ...body, createdAt: '2026-10-21' })).body), 'invalid_request', 'a bare date');
    assert.equal(code((await send(h, sam, { ...body, text: 'x'.repeat(MAX_ENTRY_UNITS + 1) })).body), 'invalid_request', 'over 20,000 units');
    assert.equal(code((await send(h, sam, { ...body, text: '😀'.repeat(MAX_ENTRY_UNITS / 2 + 1) })).body), 'invalid_request', 'counted in UTF-16 units, as the phone counts');
    assert.equal((await rows(sam)).length, 0, 'nothing stored');
    assert.equal(h.ingested.length, 0);
    assert.equal((await send(h, sam, { ...body, text: 'x'.repeat(MAX_ENTRY_UNITS) })).status, 201, 'exactly 20,000 is fine');
  } finally {
    await h.close();
  }
});

test('today follows X-Time-Zone, not UTC, and stores the zone on the person for the next request without one (*)', async () => {
  // 07:30Z on the 22nd is 23:30 on the 21st in Anchorage (UTC−8 in October).
  const h = await harness(Date.parse('2026-10-22T07:30:00.000Z'));
  try {
    const sam = await person(h);
    const zone = { 'X-Time-Zone': 'America/Anchorage' };
    const sent = await send(h, sam, draft({ createdAt: '2026-10-22T06:00:00.000Z' }), zone);
    assert.equal(data<{ entry: Entry }>(sent.body).entry.day, '2026-10-21', 'the entry belongs to the evening of the 21st where they are');
    const local = data<{ date: string; entries: Entry[] }>((await today(h, sam, zone)).body);
    assert.equal(local.date, '2026-10-21');
    assert.equal(local.entries.length, 1);
    assert.equal((await db.query<{ tz: string }>(`SELECT time_zone AS tz FROM users WHERE id = $1`, [sam])).rows[0]!.tz, 'America/Anchorage', 'remembered');
    const remembered = data<{ date: string; entries: Entry[] }>((await today(h, sam)).body);
    assert.deepEqual(remembered, local, 'without the header, the remembered zone');
    const garbage = data<{ date: string }>((await today(h, sam, { 'X-Time-Zone': 'Not/A_Zone' })).body);
    assert.equal(garbage.date, '2026-10-21', 'a header that names no zone is ignored, not stored');
    const fresh = await person(h);
    const utc = data<{ date: string; entries: Entry[] }>((await today(h, fresh)).body);
    assert.deepEqual(utc, { date: '2026-10-22', entries: [] }, 'nothing known: UTC');
    // The same instant, a day earlier for them: still today's list, keyed by the response's date.
    h.clock.now += 24 * 60 * 60 * 1000;
    assert.equal(data<{ entries: Entry[] }>((await today(h, sam, zone)).body).entries.length, 0, "yesterday's entry has left today");
  } finally {
    await h.close();
  }
});

test('today never lists calendar, mail or another person\'s rows, and equals the contract fixture (*)', async () => {
  const h = await harness();
  try {
    const sam = await person(h);
    const priya = await person(h);
    const want = fixture<{ data: { date: string; entries: Entry[] } }>('entries.today.json').data;
    const insert = (user: string, e: { id?: string; type: string; text: string; at: string; status?: string; clientEntryId?: string }) => db.query(
      `INSERT INTO raw_content (id, user_id, content_type, content, content_date, metadata, processing_status, created_at)
       VALUES (COALESCE($1, uuid_generate_v4()), $2, $3, $4, $5, $6, $7, $5)`,
      [e.id ?? null, user, e.type, e.text, e.at, JSON.stringify(e.clientEntryId ? { client_entry_id: e.clientEntryId } : {}), e.status ?? 'pending']);
    const statusOf = { read: 'completed', reading: 'processing', waiting: 'pending', failed: 'failed' } as const;
    const typeOf = { typed: 'journal_entry', voice: 'voice_journal', imported: 'shared_link', conversation: 'conversation' } as const;
    for (const e of want.entries) {
      await insert(sam, { id: e.id, type: typeOf[e.kind as keyof typeof typeOf], text: e.text, at: e.createdAt, status: statusOf[e.reading as keyof typeof statusOf], ...(e.clientEntryId ? { clientEntryId: e.clientEntryId } : {}) });
    }
    // Noise: records and mail of their own, yesterday's and tomorrow's words, and another person's words today.
    await insert(sam, { type: 'calendar', text: 'dentist 15:00', at: '2026-10-21T15:00:00.000Z' });
    await insert(sam, { type: 'gmail', text: 'your appointment is confirmed', at: '2026-10-21T09:00:00.000Z' });
    await insert(sam, { type: 'healthkit', text: 'steps 8000', at: '2026-10-21T22:00:00.000Z' });
    await insert(sam, { type: 'journal_entry', text: 'yesterday', at: '2026-10-20T23:59:59.000Z' });
    await insert(sam, { type: 'journal_entry', text: 'tomorrow', at: '2026-10-22T00:00:00.000Z' });
    await insert(priya, { type: 'journal_entry', text: 'priya today', at: '2026-10-21T12:00:00.000Z' });
    const res = await today(h, sam);
    assert.equal(res.status, 200);
    assert.deepEqual(data(res.body), want, 'the contract fixture exactly: own words, today, oldest first');
    const hers = data<{ entries: Entry[] }>((await today(h, priya)).body).entries;
    assert.deepEqual(hers.map((e) => e.text), ['priya today']);
    assert.equal(h.logLines.join('').includes('priya'), false);
    assert.equal(h.agentCalls.length, 0, 'today never calls the brain');
  } finally {
    await h.close();
  }
});

test('today lists every kind the person sends, maps the rest to imported, and stops at the cap', async () => {
  const h = await harness();
  try {
    const sam = await person(h);
    const kinds: Record<string, string> = {
      text_entry: 'typed', journal_entry: 'typed', manual_journal: 'typed', note: 'typed', voice_recording: 'voice', voice_journal: 'voice',
      conversation: 'conversation', link: 'imported', shared_link: 'imported', reference: 'imported',
    };
    assert.deepEqual(Object.keys(kinds).sort(), [...SENT_TYPES].sort(), "every type in the agent's sent set is mapped");
    let i = 0;
    for (const type of SENT_TYPES) {
      await db.query(`INSERT INTO raw_content (user_id, content_type, content, content_date, created_at) VALUES ($1, $2, $3, $4, $4)`,
        [sam, type, `item ${type}`, new Date(T0 - 3_600_000 + i++ * 1000).toISOString()]);
    }
    await db.query(`INSERT INTO raw_content (user_id, content_type, content, content_date, created_at, processing_status) VALUES ($1, 'journal_entry', 'no status', $2, $2, NULL)`,
      [sam, new Date(T0 - 3_000_000).toISOString()]);
    const listed = data<{ entries: Entry[] }>((await today(h, sam)).body).entries;
    assert.deepEqual(listed.map((e) => [e.text, e.kind]), [...SENT_TYPES.map((t) => [`item ${t}`, kinds[t]]), ['no status', 'typed']]);
    assert.equal(listed[listed.length - 1]!.reading, 'waiting', 'no status is still waiting');
    assert.equal(listed.every((e) => e.clientEntryId === undefined), true, 'no key, no clientEntryId field');

    const more = TODAY_LIMIT + 5 - listed.length;
    const values = Array.from({ length: more }, (_, k) => `('${sam}', 'journal_entry', 'bulk ${k}', '${new Date(T0 - 1_800_000 + k * 1000).toISOString()}', '${new Date(T0 - 1_800_000 + k * 1000).toISOString()}')`);
    await db.query(`INSERT INTO raw_content (user_id, content_type, content, content_date, created_at) VALUES ${values.join(',')}`);
    const capped = data<{ entries: Entry[] }>((await today(h, sam)).body).entries;
    assert.equal(capped.length, TODAY_LIMIT, 'at most 200, the oldest first');
    assert.equal(capped[0]!.text, 'item text_entry');
  } finally {
    await h.close();
  }
});

test('a waitlisted person is refused at both doors; a stale token for a deleted person is unauthenticated', async () => {
  const h = await harness();
  try {
    const w = await person(h);
    await db.query(`UPDATE users SET access = 'waitlisted' WHERE id = $1`, [w]);
    h.users.set(w, { ...h.users.get(w)!, access: 'waitlisted' });
    assert.equal(code((await send(h, w, draft())).body), 'invite_required');
    assert.equal(code((await today(h, w)).body), 'invite_required');
    const gone = await person(h);
    await db.query(`DELETE FROM users WHERE id = $1`, [gone]);
    assert.equal(code((await send(h, gone, draft())).body), 'unauthenticated');
    assert.equal(code((await today(h, gone)).body), 'unauthenticated');
  } finally {
    await h.close();
  }
});
