import assert from 'node:assert/strict';
import test from 'node:test';
import { DOOR_LIMITS } from '../src/doors/limits.js';
import { startHarness } from './support/harness.js';

const USER = '11111111-1111-4111-8111-111111111111';
const OTHER = '22222222-2222-4222-8222-222222222222';

/** A fake ElevenLabs that answers every chunk with a few bytes of "audio". */
const fakeTts = (async () => new Response('audio', { status: 200 })) as typeof fetch;
const speechSynth = {
  apiKey: 'test-only-not-a-key', voiceId: 'voice', model: 'model', maxCharsPerRequest: 4800,
  timeoutMs: 60_000, concurrency: 3, fetch: fakeTts, setTimer: () => () => undefined,
};

// Integrator decision: one per-user limiter, built by the app factory, shared by
// speech and the /v2 doors, so the expensive allowance can't be spent twice.
test('speech counts against the same expensive allowance the doors use', async () => {
  const h = await startHarness({ speechSynth });
  try {
    const auth = { Authorization: `Bearer ${h.asUser(USER)}` };
    const max = DOOR_LIMITS.buckets.expensive[0]!.max;
    for (let i = 0; i < max; i++) assert.equal((await h.request('POST', '/speech/synthesize', { text: 'Hello.' }, auth)).status, 200);
    // The shared limiter, as a door would see it, is now full for this user.
    assert.equal(h.limiter.take(USER, 'expensive', h.clock.now).ok, false);
    assert.equal((await h.request('POST', '/speech/synthesize', { text: 'Hello.' }, auth)).status, 429);
  } finally {
    await h.close();
  }
});

test('a door filling the expensive allowance limits speech too, for that user only', async () => {
  const h = await startHarness({ speechSynth });
  try {
    for (let i = 0; i < DOOR_LIMITS.buckets.expensive[0]!.max; i++) h.limiter.take(USER, 'expensive', h.clock.now);
    const mine = await h.request('POST', '/speech/synthesize', { text: 'Hello.' }, { Authorization: `Bearer ${h.asUser(USER)}` });
    assert.equal(mine.status, 429);
    const theirs = await h.request('POST', '/speech/synthesize', { text: 'Hello.' }, { Authorization: `Bearer ${h.asUser(OTHER)}` });
    assert.equal(theirs.status, 200);
  } finally {
    await h.close();
  }
});
