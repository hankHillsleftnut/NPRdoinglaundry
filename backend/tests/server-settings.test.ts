import assert from 'node:assert/strict';
import type { AddressInfo } from 'node:net';
import test from 'node:test';
import express from 'express';
import { SERVER_TIMEOUTS, applyServerTimeouts, globalLimiter, skipsGlobalLimit, trustRenderProxy } from '../src/server-settings.js';

async function serve(app: express.Express): Promise<{ url: string; close: () => Promise<void> }> {
  const server = app.listen(0, '127.0.0.1');
  await new Promise<void>((resolve) => server.once('listening', () => resolve()));
  const { port } = server.address() as AddressInfo;
  return { url: `http://127.0.0.1:${port}`, close: () => new Promise((resolve) => server.close(() => resolve())) };
}

// BE0.0 (backend-reference §0 finding 1): behind Render's proxy every req.ip was
// the proxy's, so the IP limiter put every user in one bucket.
test('trust proxy makes req.ip the forwarded client', async () => {
  const app = express();
  trustRenderProxy(app);
  app.get('/ip', (req, res) => { res.json({ ip: req.ip }); });
  const { url, close } = await serve(app);
  try {
    const res = await fetch(`${url}/ip`, { headers: { 'X-Forwarded-For': '203.0.113.7' } });
    assert.deepEqual(await res.json(), { ip: '203.0.113.7' });
    const spoofed = await fetch(`${url}/ip`, { headers: { 'X-Forwarded-For': '198.51.100.1, 203.0.113.7' } });
    assert.deepEqual(await spoofed.json(), { ip: '203.0.113.7' }, 'only the hop the proxy added is trusted');
  } finally {
    await close();
  }
});

// BE0.0 (finding 2): the global limiter counted /health and would count every door.
test('the global limiter ignores /health and /v2', async () => {
  const app = express();
  trustRenderProxy(app);
  app.use(globalLimiter({ windowMs: 60_000, max: 1 }));
  for (const p of ['/health', '/v2/ping', '/other']) app.get(p, (_req, res) => { res.json({ ok: true }); });
  const { url, close } = await serve(app);
  try {
    const statuses = async (p: string) => [
      (await fetch(`${url}${p}`)).status,
      (await fetch(`${url}${p}`)).status,
      (await fetch(`${url}${p}`)).status,
    ];
    assert.deepEqual(await statuses('/health'), [200, 200, 200]);
    assert.deepEqual(await statuses('/v2/ping'), [200, 200, 200]);
    assert.deepEqual(await statuses('/other'), [200, 429, 429], 'everything else is still limited');
  } finally {
    await close();
  }
});

test('only /health and the /v2 tree skip the global limiter', () => {
  assert.equal(skipsGlobalLimit('/health'), true);
  assert.equal(skipsGlobalLimit('/v2'), true);
  assert.equal(skipsGlobalLimit('/v2/entries'), true);
  assert.equal(skipsGlobalLimit('/v2entries'), false);
  assert.equal(skipsGlobalLimit('/healthz'), false);
  assert.equal(skipsGlobalLimit('/content'), false);
});

// BE0.0 (finding 10): headersTimeout below keepAliveTimeout causes 502s behind proxies.
test('the server waits longer for headers than it keeps idle connections', () => {
  const server = express().listen(0);
  try {
    applyServerTimeouts(server);
    assert.ok(server.headersTimeout > server.keepAliveTimeout);
    assert.equal(server.headersTimeout, SERVER_TIMEOUTS.headersTimeout);
    assert.equal(server.timeout, SERVER_TIMEOUTS.timeout);
  } finally {
    server.close();
  }
});
