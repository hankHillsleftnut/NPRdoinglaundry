/**
 * BE0.11: the agent's spend refusal (BEA.4's `429 { error: 'spend_limited' }`)
 * is never retried by the old client, and it reaches the app as contract 00's
 * `spend_limited` with `retryAfterSeconds`. Every other 429 keeps its retry.
 * No network, no real clock: fetch and the retry sleep are injected.
 */
import assert from 'node:assert/strict';
import type { AddressInfo } from 'node:net';
import test from 'node:test';
import express from 'express';
import { AGENT_MAX_ATTEMPTS, AgentSpendLimitedError, createAgentCaller, isAgentSpendLimited } from '../src/services/agent-client.js';
import { fromAgentError, SPEND_RETRY_FALLBACK_SECONDS } from '../src/doors/errors.js';
import { createPodcastsRouter } from '../src/routes/podcasts.js';

type Reply = { status: number; body: unknown; headers?: Record<string, string> };
/** A scripted agent: one reply per call, in order; the last one repeats. */
function fakeAgent(replies: Reply[]) {
  const calls: string[] = [];
  const slept: number[] = [];
  const fetchFake = (async (url: string | URL | Request) => {
    const r = replies[Math.min(calls.length, replies.length - 1)]!;
    calls.push(String(url));
    return new Response(typeof r.body === 'string' ? r.body : JSON.stringify(r.body), { status: r.status, headers: { 'Content-Type': 'application/json', ...r.headers } });
  }) as unknown as typeof fetch;
  return { calls, slept, callAgent: createAgentCaller({ fetch: fetchFake, sleep: async (ms) => { slept.push(ms); } }) };
}
const SPEND = { error: 'spend_limited', spentUsd: 15.2, capUsd: 15, scope: 'person', message: 'Daily limit reached' };

test('a spend_limited 429 is never retried, and carries the wait and the numbers', async () => {
  const agent = fakeAgent([{ status: 429, body: SPEND, headers: { 'Retry-After': '3600' } }]);
  await assert.rejects(agent.callAgent('/podcasts/generate', { userId: 'u' }), (err: unknown) => {
    assert.ok(isAgentSpendLimited(err));
    assert.ok(err instanceof AgentSpendLimitedError);
    assert.equal(err.retryAfterSeconds, 3600);
    assert.equal(err.spentUsd, 15.2);
    assert.equal(err.capUsd, 15);
    assert.equal(err.scope, 'person');
    assert.equal(err.message.includes('Daily limit'), false, "the agent's words are not carried");
    return true;
  });
  assert.equal(agent.calls.length, 1, 'one call: the cap holds until the window rolls');
  assert.deepEqual(agent.slept, [], 'no retry sleep');
});

test('without a Retry-After header the wait is the honest upper bound of the window; a project refusal says so', async () => {
  const agent = fakeAgent([{ status: 429, body: { ...SPEND, scope: 'project', spentUsd: 'n/a' } }]);
  await assert.rejects(agent.callAgent('/onboarding/goals', { userId: 'u' }), (err: unknown) => {
    assert.ok(isAgentSpendLimited(err));
    assert.equal(err.retryAfterSeconds, SPEND_RETRY_FALLBACK_SECONDS);
    assert.equal(err.scope, 'project');
    assert.equal(err.spentUsd, null, 'a non-number is not a number');
    return true;
  });
  assert.equal(agent.calls.length, 1);
});

test('every other 429 keeps its retry: an edge 429 then a 200 succeeds on the second call', async () => {
  const agent = fakeAgent([{ status: 429, body: 'Too Many Requests', headers: { 'Retry-After': '2' } }, { status: 200, body: { ok: true } }]);
  assert.deepEqual(await agent.callAgent('/ingest/run', { userId: 'u' }), { ok: true });
  assert.equal(agent.calls.length, 2);
  assert.deepEqual(agent.slept, [2000], 'waited the header');
  // Still limited on the last attempt: a plain failure (never a spend refusal), after every attempt was used.
  const exhausted = fakeAgent([{ status: 429, body: { error: 'rate limited' } }]);
  await assert.rejects(exhausted.callAgent('/ingest/run', { userId: 'u' }), (err: unknown) => err instanceof Error && !isAgentSpendLimited(err) && /Agent request failed/.test(err.message));
  assert.equal(exhausted.calls.length, AGENT_MAX_ATTEMPTS);
  assert.equal(exhausted.slept.length, AGENT_MAX_ATTEMPTS - 1);
});

test('the door mapping turns the refusal into contract 00 spend_limited with its wait', () => {
  const mapped = fromAgentError(new AgentSpendLimitedError('/x', 1234, 15.2, 15, 'person'));
  assert.equal(mapped.isBug, false);
  assert.equal(mapped.error.code, 'spend_limited');
  assert.equal(mapped.error.status, 429);
  assert.equal(mapped.error.retryAfterSeconds, 1234);
});

test('the old /podcasts/generate route answers the envelope, 429, with Retry-After, and reports nothing', async () => {
  const reported: unknown[] = [];
  const fail = async (): Promise<never> => { throw new Error('unused'); };
  const app = express();
  app.use(express.json());
  app.use((req, _res, next) => { req.user = { id: 'user-1', appleUserId: 'apple-1' }; next(); });
  app.use('/podcasts', createPodcastsRouter({
    listPodcastEpisodes: fail, getPodcastEpisode: fail, getLatestEpisode: fail,
    generateAgentPodcast: async () => { throw new AgentSpendLimitedError('/podcasts/generate', 600, 15.2, 15, 'person'); },
    report: (e) => reported.push(e),
  }));
  const server = app.listen(0, '127.0.0.1');
  await new Promise<void>((resolve) => server.once('listening', () => resolve()));
  const warn = console.warn;
  console.warn = () => undefined;
  try {
    const res = await fetch(`http://127.0.0.1:${(server.address() as AddressInfo).port}/podcasts/generate`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' });
    assert.equal(res.status, 429);
    assert.equal(res.headers.get('retry-after'), '600');
    assert.deepEqual(await res.json(), { success: false, error: { code: 'spend_limited', message: "I've done all I can today. This comes back tomorrow.", retryAfterSeconds: 600 } });
    assert.deepEqual(reported, [], 'a spend refusal is not a bug');
  } finally {
    console.warn = warn;
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});
