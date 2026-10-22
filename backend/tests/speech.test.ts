import assert from 'node:assert/strict';
import type { AddressInfo } from 'node:net';
import test from 'node:test';
import express from 'express';
import { MemoryLimiter, DOOR_LIMITS } from '../src/doors/limits.js';
import { chunkScript, mapWithConcurrency, SPEECH_DEFAULTS, SpeechProviderError, synthesizeSpeech, type SynthOptions } from '../src/services/speech-synth.js';

// The route module reads config at import, so env is set before importing it
// (dynamic import below); these placeholders are never real keys.
for (const key of ['SUPABASE_URL', 'SUPABASE_SERVICE_KEY', 'SUPABASE_ANON_KEY', 'ANTHROPIC_API_KEY', 'OPENAI_API_KEY',
  'JWT_SECRET', 'AGENT_SERVICE_URL', 'INTERNAL_API_SECRET']) {
  process.env[key] ??= key.endsWith('_URL') ? 'http://127.0.0.1:9' : 'test-only-not-a-key';
}

const T0 = 1_800_000_000_000;
const PROVIDER_SECRET_TEXT = 'quota exceeded for account acct_test_123; text was: went for a long walk';

/** A fake ElevenLabs: each chunk's audio is its own text, so order is checkable. */
function fakeProvider(opts: { fail?: (text: string) => number | null; hang?: (text: string) => boolean; delayMs?: (text: string) => number } = {}) {
  let inFlight = 0;
  let maxInFlight = 0;
  const started: string[] = [];
  const fake = (async (_url: string | URL | Request, init?: RequestInit) => {
    const text = (JSON.parse(String(init?.body)) as { text: string }).text;
    started.push(text);
    inFlight++;
    maxInFlight = Math.max(maxInFlight, inFlight);
    try {
      if (opts.hang?.(text)) {
        await new Promise((_resolve, reject) => init?.signal?.addEventListener('abort', () => reject(new Error('aborted'))));
      }
      await new Promise((r) => setTimeout(r, opts.delayMs?.(text) ?? 1));
      const status = opts.fail?.(text) ?? null;
      if (status) return new Response(PROVIDER_SECRET_TEXT, { status });
      return new Response(text, { status: 200 });
    } finally {
      inFlight--;
    }
  }) as typeof fetch;
  return { fake, started, maxInFlight: () => maxInFlight };
}

const opts = (fetchImpl: typeof fetch, over: Partial<SynthOptions> = {}): SynthOptions => ({
  apiKey: 'test-only-not-a-key', voiceId: 'voice', model: 'model', maxCharsPerRequest: 20,
  timeoutMs: 1000, concurrency: 3, fetch: fetchImpl, ...over,
});

const script = Array.from({ length: 8 }, (_, i) => `Sentence ${i}.`).join(' ');

test('chunks are concatenated in order with concurrency 3', async () => {
  const chunks = chunkScript(script, 20);
  assert.ok(chunks.length > 3);
  // Earlier chunks finish last, to prove order comes from position, not timing.
  const provider = fakeProvider({ delayMs: (t) => 40 - chunks.indexOf(t) * 5 });
  const audio = await synthesizeSpeech(script, opts(provider.fake));
  assert.equal(audio.toString(), chunks.join(''));
  assert.equal(provider.maxInFlight(), 3);
});

test('a hung chunk times out instead of holding the request', async () => {
  const provider = fakeProvider({ hang: () => true });
  // The injected timer fires at once: no real clock in the test.
  await assert.rejects(synthesizeSpeech('Hello.', opts(provider.fake, { setTimer: (fire) => { setImmediate(fire); return () => undefined; } })),
    (e: unknown) => e instanceof SpeechProviderError && e.kind === 'timeout');
});

test('a provider failure keeps its detail out of the error message, and stops new chunks', async () => {
  const chunks = chunkScript(script, 20);
  const provider = fakeProvider({ fail: (t) => (t === chunks[0] ? 429 : null), delayMs: (t) => (t === chunks[0] ? 1 : 30) });
  const err = await synthesizeSpeech(script, opts(provider.fake, { concurrency: 1 })).catch((e: unknown) => e);
  assert.ok(err instanceof SpeechProviderError);
  assert.equal(err.status, 429);
  assert.equal(err.message.includes('acct_test'), false);
  assert.equal(provider.started.length, 1, 'no paid call starts after a failure');
});

test('mapWithConcurrency never runs more than the limit and keeps order', async () => {
  let live = 0;
  let peak = 0;
  const out = await mapWithConcurrency([5, 1, 4, 2, 3], 2, async (n) => {
    live++; peak = Math.max(peak, live);
    await new Promise((r) => setTimeout(r, n));
    live--;
    return n * 10;
  });
  assert.deepEqual(out, [50, 10, 40, 20, 30]);
  assert.equal(peak, 2);
});

async function speechApp(provider: typeof fetch, limiter = new MemoryLimiter(), clock = { now: T0 }, apiKey: string | null = 'test-only-not-a-key', userHeader = true, setTimer?: SynthOptions['setTimer']) {
  const { createSpeechRouter } = await import('../src/routes/speech.js');
  const reported: unknown[] = [];
  const app = express();
  app.use(express.json());
  app.use((req, _res, next) => {
    const id = userHeader ? (req.header('x-test-user') ?? 'user-1') : 'user-1';
    req.user = { id, appleUserId: `apple-${id}` };
    next();
  });
  app.use('/speech', createSpeechRouter({
    limiter, now: () => clock.now, report: (e) => reported.push(e),
    synth: { apiKey, voiceId: 'voice', model: 'model', maxCharsPerRequest: 20, timeoutMs: 30, concurrency: 3, fetch: provider, ...(setTimer ? { setTimer } : {}) },
  }));
  const server = app.listen(0, '127.0.0.1');
  await new Promise<void>((resolve) => server.once('listening', () => resolve()));
  const { port } = server.address() as AddressInfo;
  const say = async (text = 'Hello there.', user = 'user-1') => {
    const res = await fetch(`http://127.0.0.1:${port}/speech/synthesize`, {
      method: 'POST', headers: { 'Content-Type': 'application/json', 'x-test-user': user }, body: JSON.stringify({ text }),
    });
    const body = res.headers.get('content-type')?.includes('json') ? await res.json() : await res.text();
    return { status: res.status, retryAfter: res.headers.get('retry-after'), body };
  };
  return { say, reported, close: () => new Promise<void>((resolve) => server.close(() => resolve())) };
}

const quiet = <T>(fn: () => Promise<T>) => async () => {
  const error = console.error;
  console.error = () => undefined;
  try { return await fn(); } finally { console.error = error; }
};

// BE0.3 (backend-reference §12): the provider's text reached the client.
test('a provider error never reaches the client', quiet(async () => {
  const app = await speechApp(fakeProvider({ fail: () => 401 }).fake);
  try {
    const res = await app.say();
    assert.equal(res.status, 500);
    assert.deepEqual(res.body, { success: false, error: 'Speech synthesis failed' });
    assert.equal(app.reported.length, 1, 'the detail goes to Sentry');
  } finally {
    await app.close();
  }
}));

test('speech is limited per user: the 11th request in a minute is a 429', quiet(async () => {
  const app = await speechApp(fakeProvider().fake);
  try {
    const max = DOOR_LIMITS.buckets.expensive[0]!.max;
    for (let i = 0; i < max; i++) assert.equal((await app.say()).status, 200);
    const refused = await app.say();
    assert.equal(refused.status, 429);
    assert.equal(refused.retryAfter, '60');
    assert.deepEqual(refused.body, { success: false, error: 'Too many requests, please try again later' });
  } finally {
    await app.close();
  }
}));

test('a hung provider call ends the request with the generic error', quiet(async () => {
  const fireAtOnce: SynthOptions['setTimer'] = (fire) => { setImmediate(fire); return () => undefined; };
  const app = await speechApp(fakeProvider({ hang: () => true }).fake, new MemoryLimiter(), { now: T0 }, 'test-only-not-a-key', true, fireAtOnce);
  try {
    const res = await app.say();
    assert.equal(res.status, 500);
    assert.deepEqual(res.body, { success: false, error: 'Speech synthesis failed' });
  } finally {
    await app.close();
  }
}));

test('audio comes back in order through the route', quiet(async () => {
  const app = await speechApp(fakeProvider().fake);
  try {
    const res = await app.say(script);
    assert.equal(res.status, 200);
    assert.equal(res.body, chunkScript(script, 20).join(''));
  } finally {
    await app.close();
  }
}));

test('the request checks answer before any paid call: no key 503, empty or oversized text 400', quiet(async () => {
  const provider = fakeProvider();
  const noKey = await speechApp(provider.fake, new MemoryLimiter(), { now: T0 }, null);
  try {
    assert.equal((await noKey.say()).status, 503);
  } finally {
    await noKey.close();
  }
  const app = await speechApp(provider.fake);
  try {
    assert.equal((await app.say('   ')).status, 400);
    assert.equal((await app.say('x'.repeat(20_001))).status, 400);
    assert.equal(provider.started.length, 0, 'the provider was never called');
  } finally {
    await app.close();
  }
}));

test('one user over the speech limit never limits another', quiet(async () => {
  const app = await speechApp(fakeProvider().fake);
  try {
    const max = DOOR_LIMITS.buckets.expensive[0]!.max;
    for (let i = 0; i < max; i++) await app.say('Hello.', 'user-a');
    assert.equal((await app.say('Hello.', 'user-a')).status, 429);
    assert.equal((await app.say('Hello.', 'user-b')).status, 200, 'user b is untouched');
  } finally {
    await app.close();
  }
}));

test('each chunk gets the 60 s default timeout', async () => {
  const delays: number[] = [];
  const provider = fakeProvider();
  await synthesizeSpeech(script, opts(provider.fake, { ...SPEECH_DEFAULTS, setTimer: (_fire, ms) => { delays.push(ms); return () => undefined; } }));
  assert.equal(SPEECH_DEFAULTS.timeoutMs, 60_000);
  assert.equal(delays.length, chunkScript(script, 20).length);
  assert.ok(delays.every((ms) => ms === 60_000));
});

// Integrator review of #80: chunks already in flight are paid calls too.
test('after the first failure, chunks still in flight are aborted', async () => {
  const chunks = chunkScript(script, 20);
  let aborted = 0;
  const fake = (async (_u: string | URL | Request, init?: RequestInit) => {
    const text = (JSON.parse(String(init?.body)) as { text: string }).text;
    if (text === chunks[0]) {
      await new Promise((r) => setImmediate(r));
      return new Response(PROVIDER_SECRET_TEXT, { status: 500 });
    }
    return new Promise<Response>((_resolve, reject) => init?.signal?.addEventListener('abort', () => { aborted++; reject(new Error('aborted')); }));
  }) as typeof fetch;
  const err = await synthesizeSpeech(script, opts(fake)).catch((e: unknown) => e);
  assert.ok(err instanceof SpeechProviderError && err.kind === 'http' && err.status === 500);
  await new Promise((r) => setImmediate(r));
  assert.equal(aborted, 2, 'the two other chunks in flight were cancelled');
});

test('the speech log carries the failure kind and status, never the provider\'s words', async () => {
  const lines: string[] = [];
  const error = console.error;
  console.error = (...args: unknown[]) => { lines.push(args.map(String).join(' ')); };
  try {
    const app = await speechApp(fakeProvider({ fail: () => 429 }).fake);
    try {
      await app.say();
    } finally {
      await app.close();
    }
  } finally {
    console.error = error;
  }
  assert.deepEqual(lines, ['[speech] synthesis failed (http, status 429)']);
});
