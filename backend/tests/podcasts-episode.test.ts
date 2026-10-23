/**
 * BE3.x.ep: GET /v2/episodes/:id, one episode in the legacy shape (contract
 * 03 §3), against a real Postgres (PGlite: root migration 004's
 * podcast_episodes plus the brain's audio_path), with the door suite and the
 * scope's own tests: own episode with and without audio, another person's id
 * and rows not ready answer not_found, the script split, the 1-hour link, the
 * column list and a log line with no words.
 */
import assert from 'node:assert/strict';
import test, { before } from 'node:test';
import { freshDatabase, type PGlite } from './support/database.js';
import { createAgentPodcastColumns } from './support/agent-tables.js';
import { pgliteQuery } from './support/pglite-query.js';
import { doorSuite } from './support/door-suite.js';
import { startHarness, type Harness } from './support/harness.js';
import { createV2Router } from '../src/doors/router.js';
import { supabaseBriefStore } from '../src/briefs/store.js';
import { supabaseSignAudio, SIGNED_AUDIO_TTL_SECONDS, type SignAudio, type SigningClient } from '../src/briefs/audio.js';
import { EPISODE_DETAIL_COLUMNS, PODCAST_AUDIO_BUCKET, supabasePodcastStore, type PodcastDbClient, type PodcastStore } from '../src/podcasts/store.js';
import { EpisodeByIdOut, legacyLines, type Episode } from '../src/podcasts/episode-map.js';
import { scriptLines, sentences } from '../src/podcasts/split.js';

const USER = '11111111-1111-4111-8111-111111111111';
const OTHER = '22222222-2222-4222-8222-222222222222';
const USER_EPISODE = '00000000-0000-4000-8000-000000000401';
const OTHER_EPISODE = '00000000-0000-4000-8000-000000000499';
/** Words that must never reach a log line. */
const SECRET = 'secret-words-never-logged';
const SCRIPT = `Welcome back. Dr. Ames said the week would be slow.\n\nIt wasn't, e.g. on Tuesday. ${SECRET} stayed in.`;
const SCRIPT_LINES = ['Welcome back.', 'Dr. Ames said the week would be slow.', 'It wasn\'t, e.g. on Tuesday.', `${SECRET} stayed in.`];

let db: PGlite;
let h: Harness;
/** Every path the test signer was asked to sign. */
const signed: string[] = [];
let refuseSigning = false;
const signAudio: SignAudio = (path, nowMs) => {
  signed.push(path);
  if (refuseSigning) return Promise.resolve(null);
  return Promise.resolve({ url: `https://storage.test/${PODCAST_AUDIO_BUCKET}/${path}?token=t`, expiresAt: new Date(nowMs + SIGNED_AUDIO_TTL_SECONDS * 1000).toISOString() });
};
/** Every select string the store sent. */
const selects: string[] = [];
let podcasts: PodcastStore;

type Ep = { id?: string; title?: string; status?: string; script?: string; description?: string | null; audio?: string | null; type?: string; seconds?: number | null };
async function insertEpisode(userId: string, e: Ep = {}): Promise<string> {
  const { rows } = await db.query<{ id: string }>(
    `INSERT INTO podcast_episodes (id, user_id, title, description, script, outline, generation_type, status, episode_number, duration_seconds, created_at, covers_period_start, covers_period_end, audio_path)
     VALUES (COALESCE($1::uuid, uuid_generate_v4()), $2, $3, $4, $5, $6, $7, $8, 3, $9, '2027-01-14T16:00:02.114Z', '2027-01-01T00:00:00Z', '2027-01-14T00:00:00Z', $10) RETURNING id`,
    [e.id ?? null, userId, e.title ?? 'the slow week', e.description === undefined ? 'a week about slowing down.' : e.description,
      e.script ?? SCRIPT, JSON.stringify({ plan: SECRET }), e.type ?? 'weekly', e.status ?? 'ready',
      e.seconds === undefined ? 240 : e.seconds, e.audio === undefined ? 'u/episode.mp3' : e.audio],
  );
  return rows[0]!.id;
}

/** The PGlite client, recording every select string. */
function recording(client: PodcastDbClient): PodcastDbClient {
  return { from: (table) => { const t = client.from(table); return { ...t, select: (cols) => { selects.push(cols); return t.select(cols); } }; } };
}

before(async () => {
  db = await freshDatabase();
  await createAgentPodcastColumns(db);
  podcasts = supabasePodcastStore(recording(pgliteQuery(db)), { signAudio });
  for (const id of [USER, OTHER]) await db.query(`INSERT INTO users (id, apple_user_id) VALUES ($1, $2)`, [id, `apple-${id}`]);
  await insertEpisode(USER, { id: USER_EPISODE });
  await insertEpisode(OTHER, { id: OTHER_EPISODE, title: 'not yours' });
  h = await startHarness({ podcasts });
});
test.after(() => h.close());

const NOW = 1_800_000_000_000;
const userEpisode = (): Episode => ({
  id: USER_EPISODE, kind: 'weekly', number: 3, title: 'the slow week', durationSeconds: 240, timing: 'estimated',
  createdAt: '2027-01-14T16:00:02.114Z', coversFrom: '2027-01-01', coversTo: '2027-01-14', hasAudio: true,
  madeFrom: [], chapters: [],
  lines: SCRIPT_LINES.map((text, index) => ({ index, text, chapterIndex: -1, register: 'craft' as const })),
  claims: [],
  audio: {
    url: `https://storage.test/podcast-audio/u/episode.mp3?token=t`,
    expiresAt: new Date(NOW + 3600 * 1000).toISOString(), durationSeconds: 240, mimeType: 'audio/mpeg',
  },
});

doorSuite({
  method: 'GET', path: `/v2/episodes/${USER_EPISODE}`, bucket: 'read',
  invalid: { query: 'audio=please' },
  otherUsersThing: () => `/v2/episodes/${OTHER_EPISODE}`,
  pathFor: (userId) => `/v2/episodes/${userId === OTHER ? OTHER_EPISODE : USER_EPISODE}`,
  v2Router: (door, deps) => createV2Router(door, { ...deps, podcasts: { podcasts, briefs: supabaseBriefStore(pgliteQuery(db)) } }),
  now: NOW,
  expect: () => ({ episode: userEpisode() }),
});

// ── The scope's tests ────────────────────────────────────────────────────────

const code = (body: unknown) => (body as { error?: { code?: string } }).error?.code;
let uid = 0;
async function person(): Promise<{ id: string; auth: Record<string, string> }> {
  const id = `55555555-5555-4555-8555-${String(++uid).padStart(12, '0')}`;
  await db.query(`INSERT INTO users (id, apple_user_id) VALUES ($1, $2)`, [id, `apple-${id}`]);
  return { id, auth: { Authorization: `Bearer ${h.asUser(id)}` } };
}
const get = (auth: Record<string, string>, id: string) => h.request('GET', `/v2/episodes/${id}`, undefined, auth);
async function episode(auth: Record<string, string>, id: string): Promise<Episode> {
  const res = await get(auth, id);
  assert.equal(res.status, 200, JSON.stringify(res.body));
  return EpisodeByIdOut.parse((res.body as { data: unknown }).data).episode;
}

test('own episode with audio: lines from the script, legacy fields, a link signed for the stored path', async () => {
  const p = await person();
  const id = await insertEpisode(p.id, { audio: 'p/one.mp3' });
  signed.length = 0;
  const e = await episode(p.auth, id);
  assert.deepEqual(e.lines.map((l) => l.text), SCRIPT_LINES);
  assert.ok(e.lines.every((l, i) => l.index === i && l.chapterIndex === -1 && l.register === 'craft' && l.startSeconds === undefined && l.claimId === undefined));
  assert.deepEqual([e.chapters, e.claims, e.madeFrom], [[], [], []]);
  assert.equal(e.timing, 'estimated');
  assert.equal(e.hasAudio, true);
  assert.equal(e.audio?.mimeType, 'audio/mpeg');
  assert.equal(e.audio?.durationSeconds, 240);
  assert.deepEqual(signed, ['p/one.mp3'], 'the row\'s own path, signed once');
  assert.equal(e.description, undefined, 'a description only when there are no lines');
});

test('own episode without audio: no audio key, hasAudio false, nothing signed', async () => {
  const p = await person();
  const id = await insertEpisode(p.id, { audio: null });
  signed.length = 0;
  const res = await get(p.auth, id);
  assert.equal(res.status, 200);
  const raw = (res.body as { data: { episode: Record<string, unknown> } }).data.episode;
  assert.equal('audio' in raw, false);
  assert.equal(raw.hasAudio, false);
  assert.deepEqual(signed, []);
});

test('storage refusing the link reads as words only, never hasAudio without audio', async () => {
  const p = await person();
  const id = await insertEpisode(p.id);
  refuseSigning = true;
  try {
    const e = await episode(p.auth, id);
    assert.equal(e.hasAudio, false);
    assert.equal(e.audio, undefined);
    assert.equal(e.lines.length, SCRIPT_LINES.length);
  } finally {
    refuseSigning = false;
  }
});

test('an empty script gives no lines and the description in their place', async () => {
  const p = await person();
  const id = await insertEpisode(p.id, { script: '  \n\n ' });
  const e = await episode(p.auth, id);
  assert.deepEqual(e.lines, []);
  assert.equal(e.description, 'a week about slowing down.');
});

test('another person\'s id answers exactly what a missing id answers: not_found, nothing signed', async () => {
  const p = await person();
  const theirs = await insertEpisode(OTHER, { audio: 'other/secret.mp3' });
  signed.length = 0;
  const other = await get(p.auth, theirs);
  const missing = await get(p.auth, '00000000-0000-4000-8000-0000000004ff');
  assert.equal(other.status, 404);
  assert.equal(code(other.body), 'not_found');
  assert.deepEqual(other.body, missing.body, 'existence never leaks');
  assert.equal(other.status, missing.status);
  assert.deepEqual(signed, [], 'another person\'s audio is never signed');
});

test('generating and failed episodes are not_found, even to their owner', async () => {
  const p = await person();
  for (const status of ['generating', 'failed']) {
    const id = await insertEpisode(p.id, { status });
    const res = await get(p.auth, id);
    assert.equal(res.status, 404, status);
    assert.equal(code(res.body), 'not_found', status);
  }
});

test('an id that is not a UUID is invalid_request, before any read', async () => {
  const p = await person();
  selects.length = 0;
  for (const bad of ['42', 'not-an-id', `${USER_EPISODE}x`]) {
    const res = await get(p.auth, bad);
    assert.equal(res.status, 400, bad);
    assert.equal(code(res.body), 'invalid_request', bad);
  }
  assert.deepEqual(selects, []);
});

test('the select string is closed: never the embedding or the outline', async () => {
  const p = await person();
  const id = await insertEpisode(p.id);
  selects.length = 0;
  await episode(p.auth, id);
  assert.deepEqual(selects, [EPISODE_DETAIL_COLUMNS]);
  for (const cols of selects) {
    assert.ok(!cols.includes('*'));
    assert.ok(!/embedding|outline/.test(cols), cols);
  }
});

test('the log line: door, user, status, ms, line count; never a word, a title or the path', async () => {
  const p = await person();
  const id = await insertEpisode(p.id, { title: `title ${SECRET}`, audio: `path-${SECRET}.mp3`, type: 'milestone' });
  const before = h.logLines.length;
  await episode(p.auth, id);
  await get(p.auth, OTHER_EPISODE);
  const mine = h.logLines.slice(before).map((l) => JSON.parse(l) as Record<string, unknown>).filter((l) => l.door === 'episodes.get');
  assert.equal(mine.length, 2);
  assert.equal(mine[0]!.userId, p.id);
  assert.equal(mine[0]!.status, 200);
  assert.equal(typeof mine[0]!.ms, 'number');
  assert.equal(mine[0]!.events, SCRIPT_LINES.length, 'the line count');
  assert.equal(mine[0]!.nulledFields, 1, 'one unknown kind');
  assert.equal(mine[1]!.status, 404);
  const all = h.logLines.join('\n');
  for (const word of [SECRET, 'Welcome', 'Ames', 'milestone', OTHER_EPISODE]) assert.ok(!all.includes(word), `${word} in the log`);
});

test('a store without the episode method fails closed: internal, never a 404', async () => {
  const lone = await startHarness({ podcasts: { library: () => Promise.resolve([]) } });
  try {
    const res = await lone.request('GET', `/v2/episodes/${USER_EPISODE}`, undefined, { Authorization: `Bearer ${lone.asUser(USER)}` });
    assert.equal(res.status, 500);
    assert.equal(code(res.body), 'internal');
  } finally {
    await lone.close();
  }
});

test('the default signer signs in podcast-audio for one hour, with the store\'s own storage client', async () => {
  const calls: Array<{ bucket: string; path: string; ttl: number }> = [];
  const storage: SigningClient['storage'] = {
    from: (bucket) => ({
      createSignedUrl: (path, ttl) => {
        calls.push({ bucket, path, ttl });
        return Promise.resolve({ data: { signedUrl: `https://s.test/${bucket}/${path}?token=x` }, error: null });
      },
    }),
  };
  const p = await person();
  const id = await insertEpisode(p.id, { audio: 'p/default.mp3' });
  const store = supabasePodcastStore(Object.assign(pgliteQuery(db), { storage }));
  const found = await store.episode!(p.id, id, NOW);
  assert.deepEqual(calls, [{ bucket: 'podcast-audio', path: 'p/default.mp3', ttl: 3600 }]);
  assert.equal(found?.audio?.expiresAt, new Date(NOW + 3600 * 1000).toISOString(), 'expires one hour after the response');
  // And not anyone else's, through the store directly.
  assert.equal(await store.episode!(p.id, OTHER_EPISODE, NOW), null);
});

test('the brief signer keeps the brief bucket by default', async () => {
  const buckets: string[] = [];
  const sign = supabaseSignAudio({ storage: { from: (b) => { buckets.push(b); return { createSignedUrl: () => Promise.resolve({ data: { signedUrl: 'https://s.test/x' }, error: null }) }; } } }, () => undefined);
  await sign('x.mp3', NOW);
  assert.deepEqual(buckets, ['brief-audio']);
});

// ── The split ────────────────────────────────────────────────────────────────

test('split: paragraphs then sentences, whitespace collapsed', () => {
  assert.deepEqual(scriptLines('One.  Two!\nStill two? Three.\r\n\r\nFour'), ['One.', 'Two!', 'Still two?', 'Three.', 'Four']);
  assert.deepEqual(scriptLines(''), []);
  assert.deepEqual(scriptLines('\n\n  \n'), []);
});

test('split: abbreviations, short forms and initials stay inside a sentence', () => {
  assert.deepEqual(sentences('You saw dr. Patel on monday. It helped.'), ['You saw dr. Patel on monday.', 'It helped.']);
  assert.deepEqual(sentences('Small things, e.g. the walk, i.e. the habit. Then sleep.'), ['Small things, e.g. the walk, i.e. the habit.', 'Then sleep.']);
  assert.deepEqual(sentences('Mrs. Lee and J. Smith met at 7 a.m. on site.'), ['Mrs. Lee and J. Smith met at 7 a.m. on site.']);
  assert.deepEqual(sentences('You slept 7.5 hours. Good.'), ['You slept 7.5 hours.', 'Good.']);
});

test('split: closing quotes and brackets stay with their sentence; ellipses end one', () => {
  assert.deepEqual(sentences('You wrote "enough." Then you stopped.'), ['You wrote "enough."', 'Then you stopped.']);
  assert.deepEqual(sentences('(A quiet week.) And then... Monday.'), ['(A quiet week.)', 'And then...', 'Monday.']);
  assert.deepEqual(sentences('Really?! Yes.'), ['Really?!', 'Yes.']);
});

test('lines keep the order and index of the script', () => {
  assert.deepEqual(legacyLines('one. two.\n\nthree.'), [
    { index: 0, text: 'one.', chapterIndex: -1, register: 'craft' },
    { index: 1, text: 'two.', chapterIndex: -1, register: 'craft' },
    { index: 2, text: 'three.', chapterIndex: -1, register: 'craft' },
  ]);
});
