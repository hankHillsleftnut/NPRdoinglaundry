/**
 * BE2.2b.min: contract 01's answer and complete fixtures against the doors'
 * schemas (src/onboarding/profile.ts AnswerCreateBody, src/onboarding/doors.ts
 * Answer/AnswerResponse/CompleteResponse), so the door and the app's encoder
 * and decoder read one shape; and the doors' own error answers are the 01
 * error fixtures byte for byte.
 */
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import test from 'node:test';
import { AnswerCreateBody, QUESTION_KEYS, QUESTION_LINES } from '../src/onboarding/profile.js';
import { Answer, AnswerResponse, CompleteResponse } from '../src/onboarding/doors.js';
import type { OnboardingStore } from '../src/onboarding/store.js';
import { startHarness } from './support/harness.js';

const FIXTURES = join(__dirname, '..', '..', 'docs', 'team', 'contracts', 'fixtures', '01');
const read = (name: string) => JSON.parse(readFileSync(join(FIXTURES, name), 'utf8')) as Record<string, unknown>;
const USER = '11111111-1111-4111-8111-111111111111';
const T0 = Date.parse('2026-10-21T23:00:00.000Z');

test('both answer request fixtures are valid bodies, unchanged by the schema', () => {
  for (const name of ['answer.create.request.json', 'answer.create.request.skipped.json']) {
    const f = read(name);
    const parsed = AnswerCreateBody.safeParse(f);
    assert.ok(parsed.success, `${name}: ${parsed.success ? '' : JSON.stringify(parsed.error.issues)}`);
    assert.deepEqual(parsed.data, f, `${name}: nothing dropped or changed`);
  }
});

test('the answer and complete response fixtures are the doors\' output shapes', () => {
  for (const [name, schema] of [['answer.create.response.json', AnswerResponse], ['onboarding.complete.response.json', CompleteResponse]] as const) {
    const f = read(name);
    assert.equal(f.success, true, name);
    const parsed = schema.safeParse(f.data);
    assert.ok(parsed.success, name);
    assert.deepEqual(parsed.data, f.data, `${name}: nothing dropped`);
  }
  // The list (GET, not built in 0.1) carries the same Answer.
  for (const a of (read('answers.list.json').data as { answers: unknown[] }).answers) assert.ok(Answer.safeParse(a).success);
});

test('every question key has a line for the profile; the key list is contract 01 §1 without unknown', () => {
  assert.deepEqual([...QUESTION_KEYS].sort(), Object.keys(QUESTION_LINES).sort());
  assert.equal(QUESTION_KEYS.length, 12);
  assert.ok(!(QUESTION_KEYS as readonly string[]).includes('unknown'));
});

test('the doors\' invalid_request, unauthenticated, invite_required and idempotency_mismatch answers are the fixtures', async () => {
  const store: OnboardingStore = {
    saveAnswer: async () => ({ outcome: 'mismatch' }),
    latestAnswers: async () => [],
    saveProfile: async () => ({ id: 'never', created: false }),
    complete: async () => 'member',
  };
  const h = await startHarness({ now: T0, onboarding: store });
  try {
    const body = read('answer.create.request.json') as { clientEntryId: string };
    const auth = { Authorization: `Bearer ${h.asUser(USER)}`, 'Idempotency-Key': body.clientEntryId };
    assert.deepEqual((await h.request('POST', '/v2/onboarding/answers', { ...body, questionKey: 'unknown' }, auth)).body, read('error.invalid_request.json'));
    assert.deepEqual((await h.request('POST', '/v2/onboarding/answers', body)).body, read('error.unauthenticated.json'));
    assert.deepEqual((await h.request('POST', '/v2/onboarding/answers', body, auth)).body, read('error.idempotency_mismatch.json'));
    assert.deepEqual((await h.request('POST', '/v2/onboarding/complete', {}, auth)).body, read('onboarding.complete.response.json'));
    h.users.set(USER, { ...h.users.get(USER)!, access: 'waitlisted' });
    assert.deepEqual((await h.request('POST', '/v2/onboarding/complete', {}, auth)).body, read('error.invite_required.json'));
    assert.deepEqual((await h.request('POST', '/v2/onboarding/answers', body, auth)).body, read('error.invite_required.json'));
  } finally {
    await h.close();
  }
});
