/**
 * BE1.3 + BE1.3b: the brief doors, against a real Postgres (PGlite with the
 * agent's daily_briefs table as its migrations define it), with the door suite
 * on each door and the pass's own tests (BE1.3-BE1.4.md §4.1). The brain is
 * never called by these doors; audio signing is a fake that records what it
 * was asked to sign.
 */
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import test, { before } from 'node:test';
import express from 'express';
import { applyMigration, freshDatabase, type PGlite } from './support/database.js';
import { createAgentBriefTables } from './support/agent-tables.js';
import { pgliteQuery } from './support/pglite-query.js';
import { doorSuite } from './support/door-suite.js';
import { startHarness, type Harness } from './support/harness.js';
import { supabaseBriefStore, type BriefStore } from '../src/briefs/store.js';
import { createDoorKit } from '../src/doors/door.js';
import { createV2Router } from '../src/doors/router.js';
import { mountBriefDoors } from '../src/briefs/doors.js';
import { decodeCursor, encodeCursor, nextBriefAt, MAKING_GRACE_MS } from '../src/briefs/map.js';
import { supabaseSignAudio } from '../src/briefs/audio.js';
import type { SignAudio } from '../src/briefs/audio.js';

const FIXTURES = join(__dirname, '..', '..', 'docs', 'team', 'contracts', 'fixtures', '02');
const fixture = (name: string) => JSON.parse(readFileSync(join(FIXTURES, name), 'utf8')) as { data: unknown };
const USER = '11111111-1111-4111-8111-111111111111';
const OTHER = '22222222-2222-4222-8222-222222222222';
const USER_BRIEF = '00000000-0000-4000-8000-000000000201';
const OTHER_BRIEF = '00000000-0000-4000-8000-000000000299';
const ENTRY = '00000000-0000-4000-8000-000000000103';
/** The harness clock: 2027-01-15T08:00:00.000Z. */
const NOW = 1_800_000_000_000;
const TODAY = new Date(NOW).toISOString().slice(0, 10);
const CREATED = '2027-01-15T07:58:00.000Z';

let db: PGlite;
let briefs: BriefStore;
const signed: string[] = [];
const signAudio: SignAudio = async (path, nowMs) => { signed.push(path); return { url: `https://signed.test/brief-audio/${path}?token=t`, expiresAt: new Date(nowMs + 3600_000).toISOString() }; };

type Row = { id?: string; date?: string; kind?: 'brief' | 'quiet'; through?: string; v2?: boolean; items?: unknown[]; created?: string;
  audio?: { status: string; path?: string | null; seconds?: number | null; parts?: unknown[]; updatedAt?: string | null } };
async function insertBrief(userId: string, r: Row = {}): Promise<string> {
  const { rows } = await db.query<{ id: string }>(
    `INSERT INTO daily_briefs (id, user_id, brief_date, kind, through_line, spine_movement, items, created_at, audio_status, audio_path, audio_duration_seconds, audio_parts, audio_updated_at)
     VALUES (COALESCE($1::uuid, uuid_generate_v4()), $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13) RETURNING id`,
    [r.id ?? null, userId, r.date ?? TODAY, r.kind ?? 'brief', r.through ?? 'the through line.', r.v2 ? 'planner v2' : 'complicates',
      JSON.stringify(r.items ?? [{ text: 'you slept short.', why: null, quote: '', sourceRef: { raw_content_id: ENTRY } }, { text: 'the call is at ten.', why: 'here for your goal: ship', quote: '', sourceRef: { raw_content_id: '' } }]),
      r.created ?? CREATED, r.audio?.status ?? 'none', r.audio?.path ?? null, r.audio?.seconds ?? null, JSON.stringify(r.audio?.parts ?? []), r.audio?.updatedAt ?? null],
  );
  return rows[0]!.id;
}
const setSwitch = (userId: string, on: boolean) => db.query(`UPDATE users SET daily_brief_enabled = $2 WHERE id = $1`, [userId, on]);

before(async () => {
  db = await freshDatabase();
  await createAgentBriefTables(db);
  briefs = supabaseBriefStore(pgliteQuery(db));
  for (const id of [USER, OTHER]) await db.query(`INSERT INTO users (id, apple_user_id, daily_brief_enabled) VALUES ($1, $2, true)`, [id, `apple-${id}`]);
  await insertBrief(USER, { id: USER_BRIEF });
  await insertBrief(OTHER, { id: OTHER_BRIEF });
  // The pass's own tests share one app over this database (started here, after the store exists).
  h = await startHarness({ briefs, signAudio });
});
const stores = () => ({ briefs, signAudio });

/** What the suite's person's seeded brief maps to (a v1 row, no audio). */
const userBrief = () => ({
  id: USER_BRIEF, date: TODAY, kind: 'brief',
  parts: [
    { text: 'you slept short.', sources: [{ kind: 'entry', id: ENTRY }] },
    { text: 'the call is at ten.', why: 'here for your goal: ship', sources: [] },
  ],
  createdAt: CREATED,
});

doorSuite({
  method: 'GET', path: '/v2/briefs/latest', bucket: 'read',
  invalid: { query: `userId=${OTHER}` },
  expect: () => ({ brief: userBrief(), enabled: true, nextAt: null }),
  stores,
});

doorSuite({
  method: 'GET', path: '/v2/briefs', bucket: 'read',
  invalid: { query: 'limit=0' },
  expect: () => ({ briefs: [userBrief()], nextCursor: null }),
  stores,
});

doorSuite({
  method: 'GET', path: `/v2/briefs/${USER_BRIEF}`, bucket: 'read',
  invalid: { query: 'audio=please' },
  otherUsersThing: () => `/v2/briefs/${OTHER_BRIEF}`,
  pathFor: (userId) => `/v2/briefs/${userId === OTHER ? OTHER_BRIEF : USER_BRIEF}`,
  expect: () => ({ brief: userBrief() }),
  stores,
});

doorSuite({
  method: 'PUT', path: '/v2/briefs/enabled', bucket: 'write',
  validBody: JSON.parse(readFileSync(join(FIXTURES, 'briefs.enabled.request.json'), 'utf8')),
  invalid: { body: { enabled: 'yes' } },
  expect: () => fixture('briefs.enabled.response.json').data,
  stores,
});

// ── The pass's tests (§4.1) ──────────────────────────────────────────────────

const code = (body: unknown) => (body as { error?: { code?: string } }).error?.code;
const data = <T>(body: unknown) => (body as { data: T }).data;
let h: Harness;
let uid = 0;
/** A fresh person with the switch on: in the users table and in the harness's token table. */
async function person(on = true): Promise<{ id: string; auth: Record<string, string> }> {
  const id = `33333333-3333-4333-8333-${String(++uid).padStart(12, '0')}`;
  await db.query(`INSERT INTO users (id, apple_user_id, daily_brief_enabled) VALUES ($1, $2, $3)`, [id, `apple-${id}`, on]);
  return { id, auth: { Authorization: `Bearer ${h.asUser(id)}` } };
}
const get = (path: string, auth: Record<string, string>) => h.request('GET', path, undefined, auth);

test.after(() => h.close());

test('latest maps a v1, a v2 and a quiet brief to readable parts', async () => {
  const v1 = await person(), v2 = await person(), quiet = await person();
  await insertBrief(v1.id);
  await insertBrief(v2.id, { v2: true, through: 'a quieter start than usual.\n\nthe walk by the canal keeps coming up.', items: [{ planId: 'q:1', register: 'asked', text: 'answer', why: null, quote: '', sourceRef: { raw_content_id: ENTRY } }] });
  await insertBrief(quiet.id, { kind: 'quiet', through: "nothing new since your last brief. i'll keep listening.", items: [] });
  const a = data<{ brief: { parts: Array<{ text: string; why?: string; sources: unknown[] }> } }>((await get('/v2/briefs/latest', v1.auth)).body).brief;
  assert.deepEqual(a.parts, [{ text: 'you slept short.', sources: [{ kind: 'entry', id: ENTRY }] }, { text: 'the call is at ten.', why: 'here for your goal: ship', sources: [] }]);
  const b = data<{ brief: { parts: Array<{ text: string }> } }>((await get('/v2/briefs/latest', v2.auth)).body).brief;
  assert.deepEqual(b.parts, [{ text: 'a quieter start than usual.', sources: [] }, { text: 'the walk by the canal keeps coming up.', sources: [] }]);
  assert.ok(!JSON.stringify(b).includes('"answer"'), 'v2 bookkeeping items are never shown');
  const q = data<{ brief: { kind: string; parts: Array<{ text: string }> } }>((await get('/v2/briefs/latest', quiet.auth)).body).brief;
  assert.equal(q.kind, 'quiet');
  assert.deepEqual(q.parts, [{ text: "nothing new since your last brief. i'll keep listening.", sources: [] }]);
  for (const r of [a, b, q]) assert.equal('audio' in r, false, 'no audio until it is ready');
});

test('latest is null while the switch is off, even with a row', async () => {
  const p = await person(false);
  await insertBrief(p.id);
  const res = await get('/v2/briefs/latest', p.auth);
  assert.equal(res.status, 200);
  assert.deepEqual(data(res.body), { brief: null, enabled: false, nextAt: null });
  await setSwitch(p.id, true);
  assert.notEqual(data<{ brief: unknown }>((await get('/v2/briefs/latest', p.auth)).body).brief, null);
});

test('a fresh person is switched on without doing anything, and switching off sticks (founder, 22 Oct; migration 026) (*)', async () => {
  // Created the way sign-in creates a person: nothing says anything about the brief.
  const id = `33333333-3333-4333-8333-${String(++uid).padStart(12, '0')}`;
  await db.query(`INSERT INTO users (id, apple_user_id) VALUES ($1, $2)`, [id, `apple-${id}`]);
  const auth = { Authorization: `Bearer ${h.asUser(id)}` };
  assert.deepEqual(data(( await get('/v2/briefs/latest', auth)).body), { brief: null, enabled: true, nextAt: null }, 'on by default');
  assert.deepEqual(data((await h.request('PUT', '/v2/briefs/enabled', { enabled: false }, auth)).body), { enabled: false });
  assert.equal(data<{ enabled: boolean }>((await get('/v2/briefs/latest', auth)).body).enabled, false, 'off once they say so');
  await insertBrief(id);
  assert.equal(data<{ brief: unknown }>((await get('/v2/briefs/latest', auth)).body).brief, null, 'and a brief made meanwhile stays hidden');
});

test('migration 026 switches on everyone who existed before it, and new people after it', async () => {
  const old = await freshDatabase({ before: '026_brief_on_by_default.sql' });
  try {
    await createAgentBriefTables(old);
    const before = (await old.query<{ id: string }>(`INSERT INTO users (apple_user_id) VALUES ('apple-before-026') RETURNING id`)).rows[0]!.id;
    assert.equal((await old.query<{ on: boolean }>(`SELECT daily_brief_enabled AS "on" FROM users WHERE id = $1`, [before])).rows[0]!.on, false, "the brain's 128 made it off");
    await applyMigration(old, '026_brief_on_by_default.sql');
    assert.equal((await old.query<{ on: boolean }>(`SELECT daily_brief_enabled AS "on" FROM users WHERE id = $1`, [before])).rows[0]!.on, true, 'switched on once');
    const after = (await old.query<{ on: boolean }>(`INSERT INTO users (apple_user_id) VALUES ('apple-after-026') RETURNING daily_brief_enabled AS "on"`)).rows[0]!;
    assert.equal(after.on, true, 'the default is on');
    await old.query(`UPDATE users SET daily_brief_enabled = false WHERE id = $1`, [before]);
    await applyMigration(old, '026_brief_on_by_default.sql');
    assert.equal((await old.query<{ on: boolean }>(`SELECT daily_brief_enabled AS "on" FROM users WHERE id = $1`, [before])).rows[0]!.on, true, 'applying it again is the same one-time switch-on (idempotent file)');
  } finally {
    await old.close();
  }
});

test('latest carries nextAt from the run time, null without one', async () => {
  // The rule: today's run until an hour past it, then tomorrow's; null when unset or malformed.
  const at = (iso: string) => Date.parse(iso);
  assert.equal(nextBriefAt(at('2027-01-15T06:00:00Z'), '08:00'), '2027-01-15T08:00:00.000Z');
  assert.equal(nextBriefAt(at('2027-01-15T08:59:59Z'), '08:00'), '2027-01-15T08:00:00.000Z', 'a late run is still on its way');
  assert.equal(nextBriefAt(at('2027-01-15T09:00:00Z'), '08:00'), '2027-01-16T08:00:00.000Z');
  assert.equal(nextBriefAt(at('2027-01-15T09:00:00Z'), null), null);
  assert.equal(nextBriefAt(at('2027-01-15T09:00:00Z'), '8am'), null);
  assert.equal(nextBriefAt(at('2027-01-15T09:00:00Z'), '25:00'), null);
  // At the door, with a run time set (the real app reads it from DAILY_BRIEF_UTC_TIME).
  const withRun = await startHarness({
    briefs, signAudio,
    v2Router: (door, deps) => {
      const router = express.Router();
      mountBriefDoors(router, door, { ...deps.briefs, runTimeUtc: '08:00' });
      return router;
    },
  });
  try {
    const p = await person(false);
    await db.query(`UPDATE users SET daily_brief_enabled = true WHERE id = $1`, [p.id]);
    const auth = { Authorization: `Bearer ${withRun.asUser(p.id)}` };
    // The harness clock is 08:00Z: today's run, within the hour's grace.
    assert.equal(data<{ nextAt: string }>((await withRun.request('GET', '/v2/briefs/latest', undefined, auth)).body).nextAt, '2027-01-15T08:00:00.000Z');
    withRun.clock.now += 61 * 60_000;
    assert.equal(data<{ nextAt: string }>((await withRun.request('GET', '/v2/briefs/latest', undefined, auth)).body).nextAt, '2027-01-16T08:00:00.000Z');
  } finally {
    await withRun.close();
  }
  // Without one, the default harness answers null (the suite above checks the full body).
  assert.equal(data<{ nextAt: unknown }>((await get('/v2/briefs/latest', (await person()).auth)).body).nextAt, null);
});

test('a brief whose audio is still being made is not yet latest; stuck for 15 minutes it is served as text', async () => {
  const p = await person();
  const id = await insertBrief(p.id, { audio: { status: 'making', updatedAt: new Date(NOW - 60_000).toISOString() } });
  assert.deepEqual(data((await get('/v2/briefs/latest', p.auth)).body), { brief: null, enabled: true, nextAt: null });
  h.clock.now = NOW + MAKING_GRACE_MS;
  try {
    const served = data<{ brief: { id: string; audio?: unknown } }>((await get('/v2/briefs/latest', p.auth)).body).brief;
    assert.equal(served.id, id);
    assert.equal('audio' in served, false);
  } finally {
    h.clock.now = NOW;
  }
  // A making row with no audio timestamp counts from its creation: it can't hide forever.
  const stale = await person();
  const staleId = await insertBrief(stale.id, { created: new Date(NOW - MAKING_GRACE_MS).toISOString(), audio: { status: 'making', updatedAt: null } });
  assert.equal(data<{ brief: { id: string } | null }>((await get('/v2/briefs/latest', stale.auth)).body).brief?.id, staleId);
});

test('audio is present only when ready, signed, expiring in an hour, with a startSeconds on every part; parts with audio come from audio_parts', async () => {
  const p = await person();
  const spoken = [{ index: 0, startSeconds: 0, text: 'you slept short, as spoken.' }, { index: 1, startSeconds: 41.5, text: 'the call is at ten, as spoken.' }];
  const id = await insertBrief(p.id, { audio: { status: 'ready', path: `${p.id}/b.mp3`, seconds: 74.2, parts: spoken, updatedAt: CREATED } });
  signed.length = 0;
  const brief = data<{ brief: { audio: { url: string; expiresAt: string; durationSeconds: number }; parts: Array<{ text: string; why?: string; sources: unknown[]; startSeconds: number }> } }>(
    (await get('/v2/briefs/latest', p.auth)).body).brief;
  assert.deepEqual(signed, [`${p.id}/b.mp3`]);
  assert.deepEqual(brief.audio, { url: `https://signed.test/brief-audio/${p.id}/b.mp3?token=t`, expiresAt: new Date(NOW + 3600_000).toISOString(), durationSeconds: 74.2 });
  assert.deepEqual(brief.parts, [
    { text: 'you slept short, as spoken.', sources: [{ kind: 'entry', id: ENTRY }], startSeconds: 0 },
    { text: 'the call is at ten, as spoken.', why: 'here for your goal: ship', sources: [], startSeconds: 41.5 },
  ], 'the spoken words, with the v1 why and sources by index');
  // By id too; never in the list.
  assert.equal(data<{ brief: { audio?: unknown } }>((await get(`/v2/briefs/${id}`, p.auth)).body).brief.audio !== undefined, true);
  const listed = data<{ briefs: Array<{ audio?: unknown; parts: Array<{ startSeconds?: number }> }> }>((await get('/v2/briefs', p.auth)).body).briefs[0]!;
  assert.equal('audio' in listed, false);
  assert.equal(listed.parts[0]!.startSeconds, undefined);
  // Failed audio: text only, nothing signed.
  signed.length = 0;
  const failed = await person();
  await insertBrief(failed.id, { audio: { status: 'failed' } });
  assert.equal('audio' in data<{ brief: object }>((await get('/v2/briefs/latest', failed.auth)).body).brief, false);
  assert.deepEqual(signed, []);
});

test('the list pages newest first with an opaque cursor', async () => {
  const p = await person();
  for (const [i, date] of ['2027-01-13', '2027-01-14', '2027-01-15'].entries()) await insertBrief(p.id, { date, created: `${date}T07:58:00.000Z`, through: `brief ${i}` });
  const first = data<{ briefs: Array<{ date: string }>; nextCursor: string }>((await get('/v2/briefs?limit=2', p.auth)).body);
  assert.deepEqual(first.briefs.map((b) => b.date), ['2027-01-15', '2027-01-14']);
  assert.match(first.nextCursor, /^[A-Za-z0-9_-]+$/, 'opaque, not a label');
  assert.equal(decodeCursor(first.nextCursor), '2027-01-14');
  const second = data<{ briefs: Array<{ date: string }>; nextCursor: string | null }>((await get(`/v2/briefs?limit=2&cursor=${first.nextCursor}`, p.auth)).body);
  assert.deepEqual(second.briefs.map((b) => b.date), ['2027-01-13']);
  assert.equal(second.nextCursor, null);
  for (const bad of ['cursor-2', encodeCursor('not a date'), Buffer.from('{"d":1}').toString('base64url')]) {
    const res = await get(`/v2/briefs?cursor=${bad}`, p.auth);
    assert.equal(res.status, 400, bad);
    assert.equal(code(res.body), 'invalid_request');
  }
  assert.equal((await get('/v2/briefs?limit=51', p.auth)).status, 400);
});

test('the switch only accepts true or false', async () => {
  const p = await person(false);
  for (const body of [{ enabled: 'true' }, { enabled: 1 }, { enabled: null }, {}, { enabled: true, extra: 1 }]) {
    const res = await h.request('PUT', '/v2/briefs/enabled', body, p.auth);
    assert.equal(res.status, 400, JSON.stringify(body));
    assert.equal(code(res.body), 'invalid_request');
  }
  assert.deepEqual(data((await h.request('PUT', '/v2/briefs/enabled', { enabled: true }, p.auth)).body), { enabled: true });
  assert.equal((await db.query<{ on: boolean }>(`SELECT daily_brief_enabled AS "on" FROM users WHERE id = $1`, [p.id])).rows[0]!.on, true);
  assert.deepEqual(data((await h.request('PUT', '/v2/briefs/enabled', { enabled: false }, p.auth)).body), { enabled: false });
  assert.deepEqual(data((await get('/v2/briefs/latest', p.auth)).body), { brief: null, enabled: false, nextAt: null });
});

// ── Two users ────────────────────────────────────────────────────────────────

test("latest never returns another person's brief", async () => {
  const alice = await person(), bob = await person();
  await insertBrief(bob.id, { through: 'bob only.' });
  assert.deepEqual(data((await get('/v2/briefs/latest', alice.auth)).body), { brief: null, enabled: true, nextAt: null });
  assert.deepEqual(data<{ briefs: unknown[] }>((await get('/v2/briefs', alice.auth)).body).briefs, []);
});

test("briefs/:id for another person's brief is not_found", async () => {
  const alice = await person(), bob = await person();
  const id = await insertBrief(bob.id);
  const res = await get(`/v2/briefs/${id}`, alice.auth);
  assert.equal(res.status, 404);
  assert.equal(code(res.body), 'not_found');
  assert.equal((await get(`/v2/briefs/${id}`, bob.auth)).status, 200);
});

test("a signed audio URL is only ever minted for the requester's own brief", async () => {
  const alice = await person(), bob = await person();
  const bobs = await insertBrief(bob.id, { audio: { status: 'ready', path: `${bob.id}/b.mp3`, seconds: 10, parts: [{ index: 0, startSeconds: 0, text: 'x' }], updatedAt: CREATED } });
  signed.length = 0;
  await get('/v2/briefs/latest', alice.auth);
  await get(`/v2/briefs/${bobs}`, alice.auth);
  await get('/v2/briefs', alice.auth);
  assert.deepEqual(signed, [], "nothing of bob's was signed for alice");
  await get(`/v2/briefs/${bobs}`, bob.auth);
  assert.deepEqual(signed, [`${bob.id}/b.mp3`]);
});

test('the real signer asks storage for an hour on the private bucket, and a refusal is null, logged by code', async () => {
  const asked: Array<{ bucket: string; path: string; ttl: number }> = [];
  const logged: string[] = [];
  const ok = supabaseSignAudio({ storage: { from: (bucket) => ({ createSignedUrl: async (path, ttl) => { asked.push({ bucket, path, ttl }); return { data: { signedUrl: 'https://s/x?token=1' }, error: null }; } }) } }, (l) => logged.push(l));
  assert.deepEqual(await ok('u/b.mp3', NOW), { url: 'https://s/x?token=1', expiresAt: new Date(NOW + 3600_000).toISOString() });
  assert.deepEqual(asked, [{ bucket: 'brief-audio', path: 'u/b.mp3', ttl: 3600 }]);
  const refused = supabaseSignAudio({ storage: { from: () => ({ createSignedUrl: async () => ({ data: null, error: { statusCode: '404', message: 'Object not found: u/b.mp3 secret words' } }) }) } }, (l) => logged.push(l));
  assert.equal(await refused('u/b.mp3', NOW), null);
  const thrown = supabaseSignAudio({ storage: { from: () => ({ createSignedUrl: async () => { throw new Error('fetch failed: u/b.mp3 secret words'); } }) } }, (l) => logged.push(l));
  assert.equal(await thrown('u/b.mp3', NOW), null, 'a rejection is a text-only brief, not a 500');
  assert.deepEqual(logged, ['[briefs] audio link not signed (404)', '[briefs] audio link not signed (exception)']);
});
