/**
 * BE2.2b.min: first run's answers and complete, against a real Postgres
 * (PGlite: the backend's migrations plus the brain's raw_content columns the
 * door writes). The door suite runs on both doors; the rest proves the rules
 * that keep a person's words theirs: stored once, composed only from their own
 * rows, never read on their own, never in a log line.
 */
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import test, { before } from 'node:test';
import { asServiceRole, freshDatabase, insertUser, type PGlite } from './support/database.js';
import { createAgentRawContentColumns, pgliteOnboarding } from './support/pglite-onboarding.js';
import { doorSuite } from './support/door-suite.js';
import { startHarness, type Harness } from './support/harness.js';
import { userLookupWith, type UserRowsClient } from '../src/middleware/auth.js';
import { supabaseOnboardingStore, type OnboardingStore } from '../src/onboarding/store.js';
import { QUESTION_LINES, answerFingerprint } from '../src/onboarding/profile.js';
import { requestHash } from '../src/services/content-insert.js';
import { deriveDedupKey } from '../src/services/dedup-key.js';

const FIXTURES = join(__dirname, '..', '..', 'docs', 'team', 'contracts', 'fixtures', '01');
const fixture = (name: string) => (JSON.parse(readFileSync(join(FIXTURES, name), 'utf8')) as { data: unknown }).data;
const request = JSON.parse(readFileSync(join(FIXTURES, 'answer.create.request.json'), 'utf8')) as {
  questionKey: string; text: string; given: string; clientEntryId: string; createdAt: string;
};
/** The door suite's two people (support/door-suite.ts). */
const USER = '11111111-1111-4111-8111-111111111111';
const OTHER = '22222222-2222-4222-8222-222222222222';
/** 21 Oct, 23:00Z: the fixtures' day. */
const T0 = Date.parse('2026-10-21T23:00:00.000Z');

let db: PGlite;
let onboarding: OnboardingStore;
function asService<T extends object>(store: T): T {
  return Object.fromEntries(Object.entries(store).map(([k, fn]) => [k, (...a: unknown[]) => asServiceRole(db, () => (fn as (...x: unknown[]) => Promise<unknown>)(...a))])) as T;
}
before(async () => {
  db = await freshDatabase();
  await createAgentRawContentColumns(db);
  onboarding = asService(supabaseOnboardingStore(pgliteOnboarding(db)));
  for (const id of [USER, OTHER]) await db.query(`INSERT INTO users (id, apple_user_id, access) VALUES ($1, $2, 'member')`, [id, `apple-${id}`]);
});

/** The fixture's answer, as the first send stored it (the suite's sends are its replays). */
async function storeFixtureAnswer(): Promise<void> {
  const stored = (fixture('answer.create.response.json') as { answer: { id: string; text: string; createdAt: string; questionKey: string; given: string } }).answer;
  const fp = answerFingerprint(stored);
  const key = deriveDedupKey({ userId: USER, contentType: 'onboarding_answer', content: fp, idempotencyKey: request.clientEntryId }).key;
  await db.query(
    `INSERT INTO raw_content (id, user_id, content_type, content, content_date, metadata, processing_status, authorship, dedup_key, dedup_strategy)
     VALUES ($1, $2, 'onboarding_answer', $3, $4, $5, 'completed', 'self', $6, 'explicit_key') ON CONFLICT DO NOTHING`,
    [stored.id, USER, stored.text, stored.createdAt, JSON.stringify({ questionKey: stored.questionKey, given: stored.given, request_hash: requestHash('onboarding_answer', fp) }), key],
  );
}
const suiteIngested: string[] = [];
const stores = () => ({ onboarding, startIngest: (_u: string, id: string) => { suiteIngested.push(id); } });

doorSuite({
  method: 'POST', path: '/v2/onboarding/answers', bucket: 'write',
  validBody: request,
  invalid: { body: { ...request, questionKey: 'unknown' } },
  headers: { 'Idempotency-Key': request.clientEntryId },
  setup: () => storeFixtureAnswer(),
  expect: () => fixture('answer.create.response.json'),
  stores, now: T0,
});

doorSuite({
  method: 'POST', path: '/v2/onboarding/complete', bucket: 'write',
  validBody: {},
  invalid: { body: { userId: OTHER } },
  expect: () => fixture('onboarding.complete.response.json'),
  stores, now: T0,
});

// ---- The rules, each on fresh people with access read from the database ----

const ingested: string[] = [];
async function harness(store: OnboardingStore = onboarding): Promise<Harness> {
  return startHarness({
    now: T0,
    onboarding: store,
    startIngest: (_u, id) => { ingested.push(id); },
    userLookup: userLookupWith(pgliteOnboarding(db) as unknown as UserRowsClient),
  });
}
async function person(access = 'approved'): Promise<string> {
  const id = await insertUser(db);
  await db.query('UPDATE users SET access = $2 WHERE id = $1', [id, access]);
  return id;
}
let ids = 0;
/** A fresh clientEntryId (deterministic, unique). */
const newId = () => `aaaaaaaa-0000-4000-8000-${String(++ids).padStart(12, '0')}`;
function answer(h: Harness, userId: string, body: Partial<typeof request> & { clientEntryId?: string }, key?: string) {
  const full = { ...request, clientEntryId: newId(), ...body };
  return h.request('POST', '/v2/onboarding/answers', full, {
    Authorization: `Bearer ${h.asUser(userId)}`, 'Idempotency-Key': key ?? full.clientEntryId,
  });
}
async function rows(userId: string) {
  const { rows: r } = await db.query<{ id: string; content_type: string; content: string; processing_status: string; authorship: string | null; metadata: Record<string, unknown> }>(
    `SELECT id, content_type, content, processing_status, authorship, metadata FROM raw_content WHERE user_id = $1 ORDER BY created_at, id`, [userId],
  );
  return { answers: r.filter((x) => x.content_type === 'onboarding_answer'), profiles: r.filter((x) => x.content_type === 'onboarding_profile') };
}
/** The newest profile, as the brain's first pass picks it (newest created_at). */
async function newestProfile(userId: string): Promise<string | null> {
  const { rows: r } = await db.query<{ content: string }>(
    `SELECT content FROM raw_content WHERE user_id = $1 AND content_type = 'onboarding_profile' ORDER BY created_at DESC LIMIT 1`, [userId],
  );
  return r[0]?.content ?? null;
}
const block = (key: keyof typeof QUESTION_LINES, text: string) => `${QUESTION_LINES[key]}\n${text}`;
const code = (body: unknown) => (body as { error?: { code?: string } }).error?.code;
const data = (body: unknown) => (body as { data: { answer: { id: string; text: string; createdAt: string } } }).data;

test('a new answer: 201 with the answer; one answer row (completed, own words, never ingested), one profile row handed to ingest', async () => {
  const h = await harness();
  try {
    const u = await person();
    const before = ingested.length;
    const res = await answer(h, u, { text: '  sam, in london.  ' });
    assert.equal(res.status, 201);
    const a = data(res.body).answer;
    assert.deepEqual({ ...a, id: 'x' }, { id: 'x', questionKey: 'name.place', text: 'sam, in london.', given: 'voice', createdAt: request.createdAt });
    const r = await rows(u);
    assert.equal(r.answers.length, 1);
    assert.equal(r.answers[0]!.id, a.id);
    assert.equal(r.answers[0]!.processing_status, 'completed', 'an answer is never left pending (the brain would wait on it)');
    assert.equal(r.answers[0]!.authorship, 'self');
    assert.equal(r.profiles.length, 1);
    assert.equal(r.profiles[0]!.content, block('name.place', 'sam, in london.'));
    assert.equal(r.profiles[0]!.processing_status, 'pending');
    assert.equal(r.profiles[0]!.authorship, 'self');
    assert.deepEqual(ingested.slice(before), [r.profiles[0]!.id], 'only the profile goes to the brain');
  } finally {
    await h.close();
  }
});

test('a replay is 200 with the same answer: still one answer row and one profile row, nothing more ingested', async () => {
  const h = await harness();
  try {
    const u = await person();
    const clientEntryId = newId();
    const first = await answer(h, u, { clientEntryId, text: 'once' });
    assert.equal(first.status, 201);
    const before = ingested.length;
    for (let i = 0; i < 3; i++) {
      const again = await answer(h, u, { clientEntryId: clientEntryId.toUpperCase(), text: 'once' }, clientEntryId);
      assert.equal(again.status, 200);
      assert.deepEqual(again.body, first.body);
    }
    const r = await rows(u);
    assert.equal(r.answers.length, 1);
    assert.equal(r.profiles.length, 1);
    assert.equal(ingested.length, before);
  } finally {
    await h.close();
  }
});

test('the same key with another body is 409 idempotency_mismatch, and nothing is stored', async () => {
  const h = await harness();
  try {
    const u = await person();
    const clientEntryId = newId();
    assert.equal((await answer(h, u, { clientEntryId, text: 'first words' })).status, 201);
    for (const change of [{ text: 'other words' }, { questionKey: 'care.most' }, { given: 'typed' }]) {
      const res = await answer(h, u, { clientEntryId, text: 'first words', ...change });
      assert.equal(res.status, 409, JSON.stringify(change));
      assert.equal(code(res.body), 'idempotency_mismatch');
    }
    const r = await rows(u);
    assert.equal(r.answers.length, 1);
    assert.equal(r.profiles.length, 1);
  } finally {
    await h.close();
  }
});

test('the Idempotency-Key must be the clientEntryId', async () => {
  const h = await harness();
  try {
    const u = await person();
    const missing = await h.request('POST', '/v2/onboarding/answers', { ...request, clientEntryId: newId() }, { Authorization: `Bearer ${h.asUser(u)}` });
    assert.equal(missing.status, 400);
    const other = await answer(h, u, {}, newId());
    assert.equal(other.status, 400);
    assert.equal(code(other.body), 'invalid_request');
    assert.equal((await rows(u)).answers.length, 0);
  } finally {
    await h.close();
  }
});

test('validation: skipped carries no words, words need a given, the key and given are closed lists, 8,000 units at most', async () => {
  const h = await harness();
  try {
    const u = await person();
    const refused: Record<string, unknown>[] = [
      { given: 'skipped', text: 'but i said this' },
      { given: 'voice', text: '' },
      { given: 'typed', text: '   ' },
      { questionKey: 'unknown' },
      { questionKey: 'not.a.key' },
      { given: 'unknown' },
      { text: 'x'.repeat(8_001) },
      { text: 'nul\u0000inside' },
      { createdAt: '2026-10-21T13:02:11.410+01:00' },
      { userId: OTHER },
    ];
    for (const body of refused) {
      const res = await answer(h, u, body as Partial<typeof request>);
      assert.equal(res.status, 400, JSON.stringify(body).slice(0, 80));
      assert.equal(code(res.body), 'invalid_request');
    }
    assert.equal((await rows(u)).answers.length, 0);
    assert.equal((await answer(h, u, { text: 'x'.repeat(8_000) })).status, 201);
    const skipped = await answer(h, u, { questionKey: 'high.low', given: 'skipped', text: '' });
    assert.equal(skipped.status, 201);
    assert.equal(data(skipped.body).answer.text, '');
    assert.equal(await newestProfile(u), block('name.place', 'x'.repeat(8_000)), 'a skipped answer is stored but not in the profile');
  } finally {
    await h.close();
  }
});

test('createdAt: older than 30 days is refused; more than 5 minutes ahead is stored as now', async () => {
  const h = await harness();
  try {
    const u = await person();
    const old = await answer(h, u, { createdAt: new Date(T0 - 31 * 24 * 3_600_000).toISOString() });
    assert.equal(old.status, 400);
    const ahead = await answer(h, u, { createdAt: new Date(T0 + 60 * 60_000).toISOString() });
    assert.equal(ahead.status, 201);
    assert.equal(data(ahead.body).answer.createdAt, new Date(T0).toISOString());
    assert.ok(h.logLines.some((l) => l.includes('"clockSkew":1')));
  } finally {
    await h.close();
  }
});

test('the profile is the latest answer per key, in the questions\' order, each as question line then answer', async () => {
  const h = await harness();
  try {
    const u = await person();
    assert.equal((await answer(h, u, { questionKey: 'people', text: 'my sister.', createdAt: '2026-10-21T13:10:00.000Z' })).status, 201);
    assert.equal((await answer(h, u, { questionKey: 'name.place', text: 'sam.', createdAt: '2026-10-21T13:02:00.000Z' })).status, 201);
    assert.equal((await answer(h, u, { questionKey: 'name.place', text: 'sam, in london.', createdAt: '2026-10-21T13:03:00.000Z' })).status, 201);
    // Sent late by the outbox, but given earlier: not the latest.
    assert.equal((await answer(h, u, { questionKey: 'name.place', text: 'an older draft', createdAt: '2026-10-21T13:01:00.000Z' })).status, 201);
    assert.equal(await newestProfile(u), [block('name.place', 'sam, in london.'), block('people', 'my sister.')].join('\n\n'));
    // Changing an answer and back again still leaves the newest profile right.
    assert.equal((await answer(h, u, { questionKey: 'people', text: 'alex.', createdAt: '2026-10-21T13:11:00.000Z' })).status, 201);
    assert.equal((await answer(h, u, { questionKey: 'people', text: 'my sister.', createdAt: '2026-10-21T13:12:00.000Z' })).status, 201);
    assert.equal(await newestProfile(u), [block('name.place', 'sam, in london.'), block('people', 'my sister.')].join('\n\n'));
  } finally {
    await h.close();
  }
});

test('two people\'s profiles never mix: each is composed from their own rows only', async () => {
  const h = await harness();
  try {
    const a = await person();
    const b = await person();
    // Same question, same clientEntryId even: still two people's answers.
    const shared = newId();
    assert.equal((await answer(h, a, { clientEntryId: shared, questionKey: 'care.most', text: 'alpha words' })).status, 201);
    assert.equal((await answer(h, b, { clientEntryId: shared, questionKey: 'care.most', text: 'beta words' })).status, 201);
    assert.equal((await answer(h, b, { questionKey: 'name.place', text: 'beta name' })).status, 201);
    assert.equal(await newestProfile(a), block('care.most', 'alpha words'));
    assert.equal(await newestProfile(b), [block('name.place', 'beta name'), block('care.most', 'beta words')].join('\n\n'));
    for (const p of (await rows(a)).profiles) assert.ok(!p.content.includes('beta'));
    for (const p of (await rows(b)).profiles) assert.ok(!p.content.includes('alpha'));
  } finally {
    await h.close();
  }
});

test('a profile that failed to store is made on the retry, once', async () => {
  let fail = true;
  const flaky: OnboardingStore = {
    ...onboarding,
    saveProfile: (input) => {
      if (fail) {
        fail = false;
        return Promise.reject(new Error('database went away'));
      }
      return onboarding.saveProfile(input);
    },
  };
  const h = await harness(flaky);
  try {
    const u = await person();
    const clientEntryId = newId();
    const first = await answer(h, u, { clientEntryId, text: 'kept' });
    assert.equal(first.status, 500);
    assert.equal((await rows(u)).profiles.length, 0);
    const retry = await answer(h, u, { clientEntryId, text: 'kept' });
    assert.equal(retry.status, 200);
    const r = await rows(u);
    assert.equal(r.answers.length, 1);
    assert.equal(r.profiles.length, 1);
    assert.equal(r.profiles[0]!.content, block('name.place', 'kept'));
  } finally {
    await h.close();
  }
});

test('no log line holds the words or a question\'s line', async () => {
  const h = await harness();
  try {
    const u = await person();
    const words = 'zebra-crossing-secret';
    await answer(h, u, { questionKey: 'keep.meaning', text: words });
    const id = newId();
    await answer(h, u, { clientEntryId: id, questionKey: 'keep.meaning', text: words });
    await answer(h, u, { clientEntryId: id, questionKey: 'keep.meaning', text: `${words} changed` });
    await answer(h, u, { given: 'skipped', text: words });
    assert.ok(h.logLines.length >= 4);
    for (const line of h.logLines) {
      assert.ok(!line.includes('zebra'), 'no words');
      assert.ok(!line.includes(QUESTION_LINES['keep.meaning']), 'no question line');
      assert.ok(!line.includes('keep.meaning'), 'not even the key');
    }
  } finally {
    await h.close();
  }
});

test('complete: approved becomes member; again is the same 200; member and staff stay; waitlisted is 403', async () => {
  const h = await harness();
  try {
    const send = (u: string) => h.request('POST', '/v2/onboarding/complete', {}, { Authorization: `Bearer ${h.asUser(u)}` });
    const access = async (u: string) => (await db.query<{ access: string }>('SELECT access FROM users WHERE id = $1', [u])).rows[0]!.access;

    const approved = await person('approved');
    for (let i = 0; i < 2; i++) {
      const res = await send(approved);
      assert.equal(res.status, 200);
      assert.deepEqual(res.body, { success: true, data: { access: { state: 'member' } } });
    }
    assert.equal(await access(approved), 'member');

    const member = await person('member');
    assert.deepEqual((await send(member)).body, { success: true, data: { access: { state: 'member' } } });
    assert.equal(await access(member), 'member');

    const staff = await person('staff');
    assert.deepEqual((await send(staff)).body, { success: true, data: { access: { state: 'staff' } } });
    assert.equal(await access(staff), 'staff', 'only approved moves');

    const waitlisted = await person('waitlisted');
    const refused = await send(waitlisted);
    assert.equal(refused.status, 403);
    assert.equal(code(refused.body), 'invite_required');
    assert.equal(await access(waitlisted), 'waitlisted');
  } finally {
    await h.close();
  }
});
