import assert from 'node:assert/strict';
import type { AddressInfo } from 'node:net';
import test from 'node:test';
import express from 'express';
import { adminSecretMatches, makeAdminAuth } from '../src/middleware/admin-auth.js';

// The route modules read config at import, so env is set before importing them
// (dynamic import below); these placeholders are never real keys.
for (const key of ['SUPABASE_URL', 'SUPABASE_SERVICE_KEY', 'SUPABASE_ANON_KEY', 'ANTHROPIC_API_KEY', 'OPENAI_API_KEY',
  'JWT_SECRET', 'AGENT_SERVICE_URL', 'INTERNAL_API_SECRET']) {
  process.env[key] ??= key.endsWith('_URL') ? 'http://127.0.0.1:9' : 'test-only-not-a-key';
}

async function serve(app: express.Express): Promise<{ url: string; close: () => Promise<void> }> {
  const server = app.listen(0, '127.0.0.1');
  await new Promise<void>((resolve) => server.once('listening', () => resolve()));
  const { port } = server.address() as AddressInfo;
  return { url: `http://127.0.0.1:${port}`, close: () => new Promise((resolve) => server.close(() => resolve())) };
}

const SECRET = 'admin-secret-for-tests';

function guarded(): express.Express {
  const app = express();
  app.use('/admin', makeAdminAuth(SECRET), (_req, res) => { res.json({ success: true }); });
  return app;
}

// BE0.0 (backend-reference §0 finding 9): the secret was accepted in the query
// string (it lands in access logs) and compared with !==.
test('the admin secret is read from the header only', async () => {
  const { url, close } = await serve(guarded());
  try {
    assert.equal((await fetch(`${url}/admin/stats`, { headers: { 'x-admin-secret': SECRET } })).status, 200);
    assert.equal((await fetch(`${url}/admin/stats?secret=${SECRET}`)).status, 403, 'the query string is ignored');
    assert.equal((await fetch(`${url}/admin/stats`, { headers: { 'x-admin-secret': 'wrong' } })).status, 403);
    assert.equal((await fetch(`${url}/admin/stats`)).status, 403);
  } finally {
    await close();
  }
});

test('admin secret comparison is constant-time', () => {
  const calls: [number, number][] = [];
  const spy = (a: Buffer, b: Buffer) => { calls.push([a.length, b.length]); return a.equals(b); };
  assert.equal(adminSecretMatches('short', 'a-much-longer-secret', spy), false);
  assert.equal(adminSecretMatches(SECRET, SECRET, spy), true);
  assert.deepEqual(calls, [[32, 32], [32, 32]], 'always two equal-length buffers, whatever the input lengths');
  assert.equal(adminSecretMatches(SECRET, SECRET), true, 'the default compare is timingSafeEqual');
});

test('admin routes are absent without a secret', async () => {
  const { mountAdmin } = await import('../src/routes/admin-mount.js');
  const app = express();
  const warn = console.warn;
  console.warn = () => undefined;
  try {
    assert.equal(mountAdmin(app, { secret: null, publicDir: '/nonexistent' }), false);
  } finally {
    console.warn = warn;
  }
  const { url, close } = await serve(app);
  try {
    assert.equal((await fetch(`${url}/admin/users`, { headers: { 'x-admin-secret': 'retrospect-admin-local' } })).status, 404);
    assert.equal((await fetch(`${url}/dashboard`)).status, 404);
  } finally {
    await close();
  }
});

test('with a secret, admin routes are mounted behind it', async () => {
  const { mountAdmin } = await import('../src/routes/admin-mount.js');
  const app = express();
  assert.equal(mountAdmin(app, { secret: SECRET, publicDir: '/nonexistent' }), true);
  const { url, close } = await serve(app);
  try {
    assert.equal((await fetch(`${url}/admin/users`)).status, 403);
    assert.equal((await fetch(`${url}/admin/users?secret=${SECRET}`)).status, 403);
  } finally {
    await close();
  }
});
