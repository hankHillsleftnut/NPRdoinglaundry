import assert from 'node:assert/strict';
import test from 'node:test';
import { createAgentDoorClient } from '../src/doors/agent.js';
import { AgentCallError } from '../src/doors/errors.js';

type Script = (call: number, url: string, init: RequestInit) => Promise<Response> | Response;

function scripted(script: Script) {
  const calls: { url: string; init: RequestInit }[] = [];
  const fake = (async (input: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(input), init: init ?? {} });
    return script(calls.length, String(input), init ?? {});
  }) as typeof fetch;
  return { calls, client: createAgentDoorClient({ baseUrl: 'http://agent.test/', internalSecret: 'test-secret', fetch: fake }) };
}

const json = (status: number, body: unknown) => new Response(JSON.stringify(body), { status });
/** A fetch that never answers until aborted, like a hung agent. */
const hang = (_c: number, _u: string, init: RequestInit) => new Promise<Response>((_resolve, reject) => {
  init.signal?.addEventListener('abort', () => reject(Object.assign(new Error('aborted'), { name: 'AbortError' })));
});

test('calls carry the internal secret and JSON, to the trimmed base URL', async () => {
  const { calls, client } = scripted(() => json(200, { ok: true }));
  assert.deepEqual(await client.post('/briefs/generate', { a: 1 }, { timeoutMs: 1000, retry: 'none' }), { ok: true });
  assert.equal(calls[0]!.url, 'http://agent.test/briefs/generate');
  assert.equal((calls[0]!.init.headers as Record<string, string>)['X-Internal-Secret'], 'test-secret');
  assert.equal(calls[0]!.init.body, '{"a":1}');
});

test('a read retries once on 502, 503, 504 and timeouts, then gives up', async () => {
  for (const status of [502, 503, 504]) {
    const { calls, client } = scripted((n) => (n === 1 ? json(status, {}) : json(200, { ok: true })));
    assert.deepEqual(await client.get('/x', { timeoutMs: 1000, retry: 'read' }), { ok: true });
    assert.equal(calls.length, 2, `${status} retried once`);
  }
  const { calls, client } = scripted(() => json(503, {}));
  await assert.rejects(client.get('/x', { timeoutMs: 1000, retry: 'read' }), AgentCallError);
  assert.equal(calls.length, 2, 'never more than one retry');

  const slow = scripted((n, u, i) => (n === 1 ? hang(n, u, i) : json(200, { ok: true })));
  assert.deepEqual(await slow.client.get('/x', { timeoutMs: 20, retry: 'read' }), { ok: true });
});

test('a write without retry is never sent twice, whatever fails', async () => {
  for (const failure of [() => json(503, {}), hang]) {
    const { calls, client } = scripted(failure as Script);
    await assert.rejects(client.post('/ingest/run', {}, { timeoutMs: 20, retry: 'none' }), AgentCallError);
    assert.equal(calls.length, 1);
  }
});

test('a read does not retry a 500, 404 or 400: those will not change on a retry', async () => {
  for (const status of [400, 404, 500]) {
    const { calls, client } = scripted(() => json(status, {}));
    await assert.rejects(client.get('/x', { timeoutMs: 1000, retry: 'read' }));
    assert.equal(calls.length, 1, String(status));
  }
});

test('an agent timeout is reported as a timeout, a refused connection as network', async () => {
  const timeout = scripted(hang);
  await assert.rejects(timeout.client.get('/x', { timeoutMs: 20, retry: 'none' }),
    (e: unknown) => e instanceof AgentCallError && e.failure.kind === 'timeout');
  const refused = scripted(() => { throw new TypeError('fetch failed'); });
  await assert.rejects(refused.client.get('/x', { timeoutMs: 1000, retry: 'none' }),
    (e: unknown) => e instanceof AgentCallError && e.failure.kind === 'network');
});

test('a spend 429 keeps only the dollars; the agent\'s message is dropped', async () => {
  const { client } = scripted(() => json(429, { error: 'Daily limit reached: $15.20 of $15', spentUsd: 15.2, capUsd: 15 }));
  const err = await client.post('/podcasts/generate', {}, { timeoutMs: 1000, retry: 'none' }).catch((e: unknown) => e);
  assert.ok(err instanceof AgentCallError);
  assert.deepEqual(err.failure, { kind: 'http', status: 429, spentUsd: 15.2 });
  assert.equal(JSON.stringify(err.failure).includes('Daily limit'), false);
});

test('a 200 that is not JSON is a failure, not a crash', async () => {
  const { client } = scripted(() => new Response('<html>proxy error</html>', { status: 200 }));
  await assert.rejects(client.get('/x', { timeoutMs: 1000, retry: 'none' }), AgentCallError);
});
