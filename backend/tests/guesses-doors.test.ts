/**
 * BE1.4: the guess doors, with the door suite on each and the pass's own
 * tests (BE1.3-BE1.4.md §1.5, §1.6, §4.1). Ownership and the stored status
 * come from a real Postgres (PGlite with the agent's hypotheses table); the
 * brain is the harness's scripted agent.
 */
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import test, { before } from 'node:test';
import { freshDatabase, type PGlite } from './support/database.js';
import { createAgentBriefTables } from './support/agent-tables.js';
import { pgliteQuery } from './support/pglite-query.js';
import { doorSuite } from './support/door-suite.js';
import { startHarness, type Harness } from './support/harness.js';
import { supabaseGuessStore, type GuessStore } from '../src/guesses/store.js';
import { mapGuess, sourceKind } from '../src/guesses/map.js';

const FIXTURES = join(__dirname, '..', '..', 'docs', 'team', 'contracts', 'fixtures', '02');
const fixture = (name: string) => JSON.parse(readFileSync(join(FIXTURES, name), 'utf8')) as { data: unknown };
const USER = '11111111-1111-4111-8111-111111111111';
const OTHER = '22222222-2222-4222-8222-222222222222';
const USER_GUESS = '00000000-0000-4000-8000-000000000401';
const OTHER_GUESS = '00000000-0000-4000-8000-000000000499';

/** The agent's guess, as its pending and why routes answer (ids only mapped by the door; stored reported as offered). */
const agentGuess = (id: string, over: Record<string, unknown> = {}) => ({
  id, question: 'could the short nights be about the friday deadline?',
  framework: { name: 'stress and sleep', source: 'sleep research', wonders: 'whether pressure at work shows up in your nights' },
  rationale: 'the short nights started the week the ship date was set.', status: 'offered',
  restsOn: [
    { kind: 'pattern', id: '00000000-0000-4000-8000-000000000301', text: 'under seven hours, four nights running' },
    { kind: 'entry', id: '00000000-0000-4000-8000-000000000103', text: 'ship the first version friday' },
  ],
  createdAt: '2026-10-20T12:00:00.000Z',
  ...over,
});

let db: PGlite;
let guesses: GuessStore;
let h: Harness;
before(async () => {
  db = await freshDatabase();
  await createAgentBriefTables(db);
  guesses = supabaseGuessStore(pgliteQuery(db));
  for (const id of [USER, OTHER]) await db.query(`INSERT INTO users (id, apple_user_id) VALUES ($1, $2)`, [id, `apple-${id}`]);
  await insertGuess(USER, { id: USER_GUESS });
  await insertGuess(OTHER, { id: OTHER_GUESS });
  // The pass's own tests share one app over this database (started here, after the store exists).
  h = await startHarness({ guesses });
});
async function insertGuess(userId: string, over: { id?: string; status?: string } = {}): Promise<string> {
  const { rows } = await db.query<{ id: string }>(
    `INSERT INTO hypotheses (id, user_id, framework, question, status) VALUES (COALESCE($1::uuid, uuid_generate_v4()), $2, 'flow', 'q?', $3) RETURNING id`,
    [over.id ?? null, userId, over.status ?? 'stored'],
  );
  return rows[0]!.id;
}
const stores = () => ({ guesses });
/** The scripted brain for the suite's person. */
const pendingOk = () => ({ status: 200, body: { speaking: true, guesses: [agentGuess(USER_GUESS)] } });
const whyOk = () => ({ status: 200, body: agentGuess(USER_GUESS) });
const answerOk = () => ({ status: 200, body: { status: 'confirmed' } });

doorSuite({
  method: 'GET', path: '/v2/guesses', bucket: 'read',
  invalid: { query: 'all=true' },
  agent: { route: `GET /hypotheses/${USER}/pending`, ok: pendingOk },
  expect: () => fixture('guesses.json').data,
  stores,
});

doorSuite({
  method: 'GET', path: `/v2/guesses/${USER_GUESS}/why`, bucket: 'read',
  invalid: { query: 'full=1' },
  otherUsersThing: () => `/v2/guesses/${OTHER_GUESS}/why`,
  pathFor: (userId) => `/v2/guesses/${userId === OTHER ? OTHER_GUESS : USER_GUESS}/why`,
  agent: { route: `GET /hypotheses/${USER}/${USER_GUESS}/why`, ok: whyOk },
  expect: () => fixture('guess.why.json').data,
  stores,
});

doorSuite({
  method: 'POST', path: `/v2/guesses/${USER_GUESS}`, bucket: 'write',
  validBody: JSON.parse(readFileSync(join(FIXTURES, 'guess.answer.request.json'), 'utf8')),
  invalid: { body: { verdict: 'maybe' } },
  otherUsersThing: () => `/v2/guesses/${OTHER_GUESS}`,
  pathFor: (userId) => `/v2/guesses/${userId === OTHER ? OTHER_GUESS : USER_GUESS}`,
  agent: { route: `POST /hypotheses/${USER}/${USER_GUESS}`, ok: answerOk },
  expect: () => fixture('guess.answer.json').data,
  stores,
});

// ── The pass's tests ─────────────────────────────────────────────────────────

const code = (body: unknown) => (body as { error?: { code?: string } }).error?.code;
const data = <T>(body: unknown) => (body as { data: T }).data;
let uid = 0;
async function person(): Promise<{ id: string; auth: Record<string, string> }> {
  const id = `44444444-4444-4444-8444-${String(++uid).padStart(12, '0')}`;
  await db.query(`INSERT INTO users (id, apple_user_id) VALUES ($1, $2)`, [id, `apple-${id}`]);
  return { id, auth: { Authorization: `Bearer ${h.asUser(id)}` } };
}
test.after(() => h.close());

test('pending is empty while the dial is off, and the door shows nothing it cannot name', async () => {
  const p = await person();
  h.setAgent({ [`GET /hypotheses/${p.id}/pending`]: () => ({ status: 200, body: { speaking: false, guesses: [agentGuess('x')] } }) });
  assert.deepEqual(data((await h.request('GET', '/v2/guesses', undefined, p.auth)).body), { guesses: [], speaking: false });
  h.setAgent({ [`GET /hypotheses/${p.id}/pending`]: () => ({ status: 200, body: { speaking: true, guesses: [agentGuess(USER_GUESS), agentGuess(OTHER_GUESS, { status: 'stored' })] } }) });
  const listed = data<{ guesses: Array<{ id: string }>; speaking: boolean }>((await h.request('GET', '/v2/guesses', undefined, p.auth)).body);
  assert.deepEqual(listed.guesses.map((g) => g.id), [USER_GUESS], 'a status the contract has no name for is dropped');
  assert.equal(listed.speaking, true);
});

test('restsOn carries readable text for every kind, with the agent\'s kinds mapped', () => {
  assert.equal(sourceKind('why'), 'pattern');
  assert.equal(sourceKind('fact'), 'fact');
  assert.equal(sourceKind('answer'), 'answer');
  assert.equal(sourceKind('item'), 'entry');
  assert.equal(sourceKind('vibe'), 'vibe', 'unknown kinds pass through: the phone shows unknown, the text still reads');
  const g = mapGuess(agentGuess('g', { rationale: null, framework: { name: 'routines', source: null }, restsOn: [{ kind: 'why', id: 'w1', text: 'avoids the standup' }, { kind: 'fact', id: 'f1' }] }));
  assert.deepEqual(g, { id: 'g', question: 'could the short nights be about the friday deadline?', framework: { name: 'routines' }, status: 'offered', restsOn: [{ kind: 'pattern', id: 'w1', text: 'avoids the standup' }, { kind: 'fact', id: 'f1', text: '' }] });
  assert.equal(mapGuess(agentGuess('g', { status: 'stored' })), null);
});

test('the same answer twice is 200 with the stored status and the agent is not called', async () => {
  const p = await person();
  const id = await insertGuess(p.id);
  let agentAnswers = 0;
  h.setAgent({ [`POST /hypotheses/${p.id}/${id}`]: async () => { agentAnswers++; await db.query(`UPDATE hypotheses SET status = 'declined' WHERE id = $1`, [id]); return { status: 200, body: { status: 'declined' } }; } });
  const first = await h.request('POST', `/v2/guesses/${id}`, { verdict: 'no' }, { ...p.auth, 'Idempotency-Key': 'outbox-1' });
  assert.equal(first.status, 200);
  assert.deepEqual(data(first.body), { status: 'declined' });
  assert.equal(agentAnswers, 1);
  // Again, same words, and then the other device with the other verdict: the stored status, no second call.
  assert.deepEqual(data((await h.request('POST', `/v2/guesses/${id}`, { verdict: 'no' }, { ...p.auth, 'Idempotency-Key': 'outbox-1' })).body), { status: 'declined' });
  assert.deepEqual(data((await h.request('POST', `/v2/guesses/${id}`, { verdict: 'yes' }, { ...p.auth, 'Idempotency-Key': 'outbox-2' })).body), { status: 'declined' });
  assert.equal(agentAnswers, 1, 'the agent was asked once');
});

test('an expired guess answers expired', async () => {
  const p = await person();
  const id = await insertGuess(p.id, { status: 'expired' });
  h.setAgent({ [`POST /hypotheses/${p.id}/${id}`]: () => { throw new Error('must not be called'); } });
  const res = await h.request('POST', `/v2/guesses/${id}`, { verdict: 'yes' }, p.auth);
  assert.equal(res.status, 200);
  assert.deepEqual(data(res.body), { status: 'expired' });
  assert.equal(h.agentCalls.filter((c) => c.path.endsWith(`/${id}`)).length, 0);
  // Retired by the brain between the door's read and its call: the brain's 404 is not_found, the guess reverts on the phone.
  const racing = await insertGuess(p.id);
  h.setAgent({ [`POST /hypotheses/${p.id}/${racing}`]: () => ({ status: 404, body: { error: 'answerHypothesis: no open hypothesis with that id for this person' } }) });
  const lost = await h.request('POST', `/v2/guesses/${racing}`, { verdict: 'yes' }, p.auth);
  assert.equal(lost.status, 404);
  assert.equal(code(lost.body), 'not_found');
  assert.equal(JSON.stringify(lost.body).includes('answerHypothesis'), false);
});

test("another person's guess is not_found on answer and why, before the brain is asked", async () => {
  const alice = await person(), bob = await person();
  const bobs = await insertGuess(bob.id);
  h.setAgent({
    [`GET /hypotheses/${alice.id}/${bobs}/why`]: () => ({ status: 200, body: agentGuess(bobs) }),
    [`POST /hypotheses/${alice.id}/${bobs}`]: () => ({ status: 200, body: { status: 'confirmed' } }),
  });
  const before = h.agentCalls.length;
  const why = await h.request('GET', `/v2/guesses/${bobs}/why`, undefined, alice.auth);
  assert.equal(why.status, 404);
  assert.equal(code(why.body), 'not_found');
  const answer = await h.request('POST', `/v2/guesses/${bobs}`, { verdict: 'yes' }, alice.auth);
  assert.equal(answer.status, 404);
  assert.equal(h.agentCalls.length, before, 'the brain was never asked about a guess that is not theirs');
  assert.equal((await db.query<{ s: string }>(`SELECT status s FROM hypotheses WHERE id = $1`, [bobs])).rows[0]!.s, 'stored');
  // A guess that doesn't exist at all: the same answer.
  assert.equal((await h.request('GET', `/v2/guesses/00000000-0000-4000-8000-000000000000/why`, undefined, alice.auth)).status, 404);
});

test("pending lists only the requester's guesses: the door asks the brain for the signed-in person, never a client id", async () => {
  const p = await person();
  let asked = '';
  h.setAgent({ [`GET /hypotheses/${p.id}/pending`]: (_b, url) => { asked = url.pathname; return { status: 200, body: { speaking: true, guesses: [] } }; } });
  const res = await h.request('GET', `/v2/guesses?userId=${OTHER}`, undefined, p.auth);
  assert.equal(res.status, 400, 'a client-sent user id is refused');
  assert.equal((await h.request('GET', '/v2/guesses', undefined, p.auth)).status, 200);
  assert.equal(asked, `/hypotheses/${p.id}/pending`);
});
