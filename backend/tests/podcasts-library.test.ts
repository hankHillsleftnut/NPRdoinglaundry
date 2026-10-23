/**
 * BE3.x.lib: GET /v2/podcasts, the podcasts library (contract 03 §2), against
 * a real Postgres (PGlite: root migration 004's podcast_episodes plus the
 * brain's audio_path, and the agent's daily_briefs), with the door suite and
 * the scope's own tests. The brain is never called by this door.
 */
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import test, { before } from 'node:test';
import { freshDatabase, type PGlite } from './support/database.js';
import { createAgentBriefTables, createAgentPodcastColumns } from './support/agent-tables.js';
import { pgliteQuery } from './support/pglite-query.js';
import { doorSuite } from './support/door-suite.js';
import { startHarness, type Harness } from './support/harness.js';
import { createV2Router } from '../src/doors/router.js';
import { supabaseBriefStore, type BriefDbClient, type BriefStore } from '../src/briefs/store.js';
import { EPISODE_COLUMNS, supabasePodcastStore, type PodcastStore } from '../src/podcasts/store.js';
import {
  beforeFor, briefTitle, compare, decodeCursor, encodeCursor, LibraryOut, stampMicros, type Library, type Position,
} from '../src/podcasts/map.js';

const FIXTURES = join(__dirname, '..', '..', 'docs', 'team', 'contracts', 'fixtures', '03');
const fixture = (name: string) => JSON.parse(readFileSync(join(FIXTURES, name), 'utf8')) as { data: unknown };
const USER = '11111111-1111-4111-8111-111111111111';
const OTHER = '22222222-2222-4222-8222-222222222222';
const USER_EPISODE = '00000000-0000-4000-8000-000000000301';
const USER_BRIEF = '00000000-0000-4000-8000-000000000302';
/** Words that must never leave the database through this door. */
const SECRET = 'secret-words-never-listed';

let db: PGlite;
let podcasts: PodcastStore;
let briefs: BriefStore;
let h: Harness;

type Ep = { id?: string; title?: string; status?: string; type?: string; number?: number | null; seconds?: number | null; created: string;
  from?: string | null; to?: string | null; audio?: string | null };
async function insertEpisode(userId: string, e: Ep): Promise<string> {
  const { rows } = await db.query<{ id: string }>(
    `INSERT INTO podcast_episodes (id, user_id, title, description, script, outline, generation_type, status, episode_number, duration_seconds, created_at, covers_period_start, covers_period_end, audio_path)
     VALUES (COALESCE($1::uuid, uuid_generate_v4()), $2, $3, $4, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13) RETURNING id`,
    [e.id ?? null, userId, e.title ?? 'an episode', SECRET, JSON.stringify({ plan: SECRET }), e.type ?? 'weekly', e.status ?? 'ready',
      e.number === undefined ? 1 : e.number, e.seconds === undefined ? 300 : e.seconds, e.created,
      e.from === undefined ? '2027-01-01T00:00:00Z' : e.from, e.to === undefined ? '2027-01-14T00:00:00Z' : e.to,
      e.audio === undefined ? 'u/episode.mp3' : e.audio],
  );
  return rows[0]!.id;
}

type Br = { id?: string; date: string; created: string; kind?: 'brief' | 'quiet'; through?: string; audio?: { seconds: number; first: string } };
async function insertBrief(userId: string, b: Br): Promise<string> {
  const { rows } = await db.query<{ id: string }>(
    `INSERT INTO daily_briefs (id, user_id, brief_date, kind, through_line, spine_movement, items, created_at, audio_status, audio_path, audio_duration_seconds, audio_parts)
     VALUES (COALESCE($1::uuid, uuid_generate_v4()), $2, $3, $4, $5, 'planner v2', '[]', $6, $7, $8, $9, $10) RETURNING id`,
    [b.id ?? null, userId, b.date, b.kind ?? 'brief', b.through ?? `a quieter monday than usual. ${SECRET}`, b.created,
      b.audio ? 'ready' : 'none', b.audio ? 'u/brief.mp3' : null, b.audio?.seconds ?? null,
      JSON.stringify(b.audio ? [{ index: 0, startSeconds: 0, text: b.audio.first }] : [])],
  );
  return rows[0]!.id;
}

const stores = () => ({ podcasts, briefs });

before(async () => {
  db = await freshDatabase();
  await createAgentBriefTables(db);
  await createAgentPodcastColumns(db);
  podcasts = supabasePodcastStore(pgliteQuery(db));
  briefs = supabaseBriefStore(pgliteQuery(db));
  for (const id of [USER, OTHER]) await db.query(`INSERT INTO users (id, apple_user_id) VALUES ($1, $2)`, [id, `apple-${id}`]);
  await insertEpisode(USER, { id: USER_EPISODE, title: 'the week the plan met the calendar', number: 6, seconds: 612, created: '2027-01-14T16:00:02.114Z' });
  await insertBrief(USER, { id: USER_BRIEF, date: '2027-01-15', created: '2027-01-15T07:58:00.000Z', audio: { seconds: 248, first: 'a quieter monday than usual.' } });
  await insertEpisode(OTHER, { title: 'not yours', created: '2027-01-15T09:00:00.000Z' });
  await insertBrief(OTHER, { date: '2027-01-15', created: '2027-01-15T09:00:00.000Z' });
  h = await startHarness({ podcasts, briefs });
});
test.after(() => h.close());

/** What the suite's person's library is. */
const userLibrary = (): Library => ({
  hero: {
    id: USER_EPISODE, kind: 'weekly', number: 6, title: 'the week the plan met the calendar', durationSeconds: 612, timing: 'estimated',
    createdAt: '2027-01-14T16:00:02.114Z', coversFrom: '2027-01-01', coversTo: '2027-01-14', hasAudio: true,
  },
  upcoming: { state: 'none' },
  items: [{ kind: 'brief', brief: { id: USER_BRIEF, date: '2027-01-15', title: 'a quieter monday than usual', durationSeconds: 248, hasAudio: true } }],
  nextCursor: null,
});

doorSuite({
  method: 'GET', path: '/v2/podcasts', bucket: 'read',
  invalid: { query: 'limit=0' },
  // Through the real /v2 router, with the stores on this database.
  v2Router: (door, deps) => createV2Router(door, { ...deps, podcasts: stores() }),
  expect: () => userLibrary(),
});

// ── The scope's tests ────────────────────────────────────────────────────────

const code = (body: unknown) => (body as { error?: { code?: string } }).error?.code;
const data = (body: unknown) => LibraryOut.parse((body as { data: unknown }).data);
let uid = 0;
async function person(): Promise<{ id: string; auth: Record<string, string> }> {
  const id = `44444444-4444-4444-8444-${String(++uid).padStart(12, '0')}`;
  await db.query(`INSERT INTO users (id, apple_user_id) VALUES ($1, $2)`, [id, `apple-${id}`]);
  return { id, auth: { Authorization: `Bearer ${h.asUser(id)}` } };
}
const library = async (auth: Record<string, string>, query = '') => {
  const res = await h.request('GET', `/v2/podcasts${query ? `?${query}` : ''}`, undefined, auth);
  assert.equal(res.status, 200, JSON.stringify(res.body));
  return data(res.body);
};
const idOf = (item: Library['items'][number]) => (item.kind === 'episode' ? item.episode.id : item.kind === 'brief' ? item.brief.id : 'unknown');

/** Every page from the first, by following nextCursor. */
async function walk(auth: Record<string, string>, limit: number): Promise<{ hero: string | null; ids: string[]; pages: Library[] }> {
  const pages: Library[] = [];
  let cursor: string | null = null;
  do {
    const page: Library = await library(auth, `limit=${limit}${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ''}`);
    pages.push(page);
    cursor = page.nextCursor;
    assert.ok(pages.length < 50, 'paging ends');
  } while (cursor);
  return { hero: pages[0]!.hero?.id ?? null, ids: pages.flatMap((p) => p.items.map(idOf)), pages };
}

test('the newest ready episode is the hero and is never in items; the rest merge newest first', async () => {
  const p = await person();
  const hero = await insertEpisode(p.id, { created: '2027-01-10T16:00:00.000Z', title: 'newest' });
  const older = await insertEpisode(p.id, { created: '2027-01-03T16:00:00.000Z', title: 'older' });
  const b1 = await insertBrief(p.id, { date: '2027-01-12', created: '2027-01-12T08:00:00.000Z' });
  const b0 = await insertBrief(p.id, { date: '2027-01-05', created: '2027-01-05T08:00:00.000Z' });
  const lib = await library(p.auth);
  assert.equal(lib.hero?.id, hero);
  assert.deepEqual(lib.items.map(idOf), [b1, b0, older]);
  assert.deepEqual(lib.upcoming, { state: 'none' });
  for (const limit of [1, 2, 3]) {
    const all = await walk(p.auth, limit);
    assert.deepEqual(all.ids, [b1, b0, older], `limit ${limit}`);
    assert.ok(!all.ids.includes(hero), 'the hero is never repeated');
    for (const later of all.pages.slice(1)) {
      assert.equal(later.hero, null, 'the hero comes on the first page only');
      assert.equal('upcoming' in later, false, 'upcoming comes on the first page only');
    }
  }
});

test('items sharing one timestamp page without repeats or gaps, episodes before briefs, then by id', async () => {
  const p = await person();
  const at = '2027-01-08T12:00:00.000Z';
  const hero = await insertEpisode(p.id, { created: '2027-01-09T12:00:00.000Z' });
  const e = [
    await insertEpisode(p.id, { id: '00000000-0000-4000-8000-0000000003a1', created: at }),
    await insertEpisode(p.id, { id: '00000000-0000-4000-8000-0000000003a2', created: at }),
  ];
  const b = [
    await insertBrief(p.id, { id: '00000000-0000-4000-8000-0000000003b1', date: '2027-01-06', created: at }),
    await insertBrief(p.id, { id: '00000000-0000-4000-8000-0000000003b2', date: '2027-01-07', created: at }),
  ];
  const last = await insertEpisode(p.id, { created: '2027-01-01T12:00:00.000Z' });
  const expected = [e[1]!, e[0]!, b[1]!, b[0]!, last];
  for (const limit of [1, 2, 3, 4, 50]) {
    const all = await walk(p.auth, limit);
    assert.equal(all.hero, hero);
    assert.deepEqual(all.ids, expected, `limit ${limit}: every item once, in order`);
  }
});

test('quiet briefs, generating and failed episodes never appear', async () => {
  const p = await person();
  const ready = await insertEpisode(p.id, { created: '2027-01-02T16:00:00.000Z' });
  await insertEpisode(p.id, { created: '2027-01-09T16:00:00.000Z', status: 'generating' });
  await insertEpisode(p.id, { created: '2027-01-08T16:00:00.000Z', status: 'failed' });
  await insertBrief(p.id, { date: '2027-01-07', created: '2027-01-07T08:00:00.000Z', kind: 'quiet', through: "nothing new since your last brief. i'll keep listening." });
  const brief = await insertBrief(p.id, { date: '2027-01-06', created: '2027-01-06T08:00:00.000Z' });
  const lib = await library(p.auth);
  assert.equal(lib.hero?.id, ready, 'the newest READY episode, not a newer one being made');
  assert.deepEqual(lib.items.map(idOf), [brief]);
});

test('a tampered or undecodable cursor is invalid_request', async () => {
  const p = await person();
  const good: Position = { at: '2027-01-08T12:00:00.000Z', kind: 'episode', id: USER_EPISODE };
  const raw = (s: string) => Buffer.from(s, 'utf8').toString('base64url');
  for (const cursor of [
    'not a cursor!', raw('2027-01-08T12:00:00.000Z|goal|00000000-0000-4000-8000-000000000301'),
    raw('yesterday|episode|00000000-0000-4000-8000-000000000301'), raw('2027-01-08T12:00:00.000Z|episode|1 OR 1=1'),
    raw('2027-01-08T12:00:00.000Z|episode'), raw(JSON.stringify({ d: '2027-01-08' })), `${encodeCursor(good)}!`,
  ]) {
    const res = await h.request('GET', `/v2/podcasts?cursor=${encodeURIComponent(cursor)}`, undefined, p.auth);
    assert.equal(res.status, 400, cursor);
    assert.equal(code(res.body), 'invalid_request');
  }
  assert.equal((await h.request('GET', '/v2/podcasts?limit=51', undefined, p.auth)).status, 400, 'limit is 1-50');
  assert.deepEqual(decodeCursor(encodeCursor(good)), good);
});

test("another person's episodes and briefs never appear, on any page", async () => {
  const a = await person(), b = await person();
  const mine = await insertEpisode(a.id, { created: '2027-01-02T16:00:00.000Z' });
  const myBrief = await insertBrief(a.id, { date: '2027-01-01', created: '2027-01-01T08:00:00.000Z' });
  // b's rows are newer and older than a's, so a missing owner filter would show on either side.
  const theirs = [
    await insertEpisode(b.id, { created: '2027-01-12T16:00:00.000Z' }),
    await insertEpisode(b.id, { created: '2026-12-01T16:00:00.000Z' }),
    await insertBrief(b.id, { date: '2027-01-11', created: '2027-01-11T08:00:00.000Z' }),
    await insertBrief(b.id, { date: '2026-12-02', created: '2026-12-02T08:00:00.000Z' }),
  ];
  for (const limit of [1, 20]) {
    const all = await walk(a.auth, limit);
    assert.equal(all.hero, mine);
    assert.deepEqual(all.ids, [myBrief]);
    const text = JSON.stringify(all.pages);
    for (const id of theirs) assert.ok(!text.includes(id), 'never another person\'s row');
  }
  // A cursor made from b's own position lists only a's rows from there.
  const fromTheirs = encodeCursor({ at: '2027-01-12T16:00:00.000Z', kind: 'episode', id: theirs[0]! });
  const page = await library(a.auth, `cursor=${encodeURIComponent(fromTheirs)}`);
  assert.deepEqual(page.items.map(idOf), [myBrief]);
  assert.equal(page.hero, null);
});

test('the store asks for named columns only: never the embedding, script, outline or description', async () => {
  const selected: string[] = [];
  const recording = pgliteQuery(db);
  const spy: BriefDbClient = { from: (t) => { const f = recording.from(t); return { ...f, select: (c) => { selected.push(c); return f.select(c); } }; } };
  await supabasePodcastStore(spy).library(USER, { at: '2027-02-01T00:00:00.000Z', tie: 'all' }, 5);
  assert.ok(selected.length >= 2, 'both the older and the tied query were checked');
  for (const cols of [...selected, EPISODE_COLUMNS]) {
    const names = cols.split(',').map((c) => c.trim());
    assert.ok(!names.includes('*'));
    for (const banned of ['summary_embedding', 'script', 'outline', 'description']) assert.ok(!names.includes(banned), banned);
  }
  const res = await h.request('GET', '/v2/podcasts', undefined, { Authorization: `Bearer ${h.asUser(USER)}` });
  assert.ok(!JSON.stringify(res.body).includes(SECRET), 'no script, outline, description or brief words in the answer');
});

test('an empty account is the empty fixture', async () => {
  const p = await person();
  const res = await h.request('GET', '/v2/podcasts', undefined, p.auth);
  assert.deepEqual(res.body, fixture('podcasts.library.empty.json'));
});

test('an unknown generation type is kind unknown and counted in the log; the log has no words', async () => {
  const p = await person();
  await insertEpisode(p.id, { created: '2027-01-09T16:00:00.000Z', type: 'milestone', number: null, seconds: null, from: null, to: null, audio: null, title: `a milestone ${SECRET}` });
  await insertEpisode(p.id, { created: '2027-01-02T16:00:00.000Z', type: 'on_demand' });
  const before = h.logLines.length;
  const lib = await library(p.auth);
  assert.equal(lib.hero?.kind, 'unknown');
  assert.deepEqual(
    { ...lib.hero, title: undefined, id: undefined, createdAt: undefined },
    { kind: 'unknown', durationSeconds: 0, timing: 'unknown', hasAudio: false, title: undefined, id: undefined, createdAt: undefined },
    'no number, no covers dates, no audio when the row has none',
  );
  assert.equal(lib.items[0]?.kind === 'episode' && lib.items[0].episode.kind, 'onDemand');
  const lines = h.logLines.slice(before).map((l) => JSON.parse(l) as Record<string, unknown>).filter((l) => l.door === 'podcasts.library');
  assert.equal(lines.length, 1);
  assert.equal(lines[0]!.userId, p.id);
  assert.equal(lines[0]!.status, 200);
  assert.equal(lines[0]!.events, 2, 'items listed, hero included');
  assert.equal(lines[0]!.nulledFields, 1, 'one unknown kind');
  assert.ok(!h.logLines.join('\n').includes(SECRET) && !h.logLines.join('\n').includes('milestone'), 'never a title in the log');
});

test('listBeforeCreated returns the rows list returns for a plain account, and list is unchanged', async () => {
  const p = await person();
  const ids = [];
  for (let d = 1; d <= 5; d++) ids.push(await insertBrief(p.id, { date: `2027-01-0${d}`, created: `2027-01-0${d}T08:00:00.000Z` }));
  const listed = (await briefs.list(p.id, null, 10)).map((r) => r.id);
  const byCreated = (await briefs.listBeforeCreated(p.id, null, 10)).map((r) => r.id);
  assert.deepEqual(byCreated, listed);
  assert.deepEqual(listed, [...ids].reverse());
  const after = await briefs.listBeforeCreated(p.id, { at: '2027-01-03T08:00:00.000Z', tie: 'none' }, 10);
  assert.deepEqual(after.map((r) => r.id), [ids[1], ids[0]]);
  // A quiet brief: list still shows it (the brief doors are unchanged); the library's method leaves it out.
  const quiet = await insertBrief(p.id, { date: '2027-01-06', created: '2027-01-06T08:00:00.000Z', kind: 'quiet', through: 'quiet.' });
  assert.equal((await briefs.list(p.id, null, 10))[0]!.id, quiet);
  assert.ok(!(await briefs.listBeforeCreated(p.id, null, 10)).some((r) => r.id === quiet));
});

test('a brief is titled by its first sentence, cut at 80, and has a duration only with audio', async () => {
  assert.equal(briefTitle('a quieter monday than usual. the walk came up again.'), 'a quieter monday than usual');
  assert.equal(briefTitle('did you sleep? more later.'), 'did you sleep?');
  assert.equal(briefTitle('no full stop at all'), 'no full stop at all');
  assert.equal(briefTitle('x'.repeat(120)).length, 80);
  const p = await person();
  await insertBrief(p.id, { date: '2027-01-03', created: '2027-01-03T08:00:00.000Z', through: 'two things from the weekend. one more.' });
  const lib = await library(p.auth);
  assert.deepEqual(lib.items, [{ kind: 'brief', brief: { id: (lib.items[0] as { brief: { id: string } }).brief.id, date: '2027-01-03', title: 'two things from the weekend', hasAudio: false } }]);
});

test('order and cursors are exact to the microsecond (the database keeps them; supabase-js returns them)', () => {
  assert.equal(stampMicros('2027-01-08T12:00:00.000100+00:00'), Date.parse('2027-01-08T12:00:00Z') * 1000 + 100);
  assert.equal(stampMicros('2027-01-08T12:00:00Z'), Date.parse('2027-01-08T12:00:00Z') * 1000);
  assert.equal(stampMicros('2027-01-08 12:00:00.5+01'), Date.parse('2027-01-08T11:00:00Z') * 1000 + 500_000);
  assert.equal(stampMicros('tomorrow'), null);
  const a: Position = { at: '2027-01-08T12:00:00.000900+00:00', kind: 'brief', id: '00000000-0000-4000-8000-000000000001' };
  const b: Position = { at: '2027-01-08T12:00:00.000100+00:00', kind: 'episode', id: '00000000-0000-4000-8000-000000000002' };
  assert.ok(compare(a, b) < 0, 'a microsecond later comes first, whatever the kind');
  assert.deepEqual(beforeFor('episode', a), { at: a.at, tie: 'none' });
  assert.deepEqual(beforeFor('brief', a), { at: a.at, tie: { below: a.id } });
  assert.deepEqual(beforeFor('brief', b), { at: b.at, tie: 'all' });
  assert.equal(decodeCursor(encodeCursor(a))?.at, a.at, 'the cursor keeps the microseconds');
});
