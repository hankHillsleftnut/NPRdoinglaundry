import assert from 'node:assert/strict';
import type { AddressInfo } from 'node:net';
import test from 'node:test';
import jwt from 'jsonwebtoken';
import { startHarness } from './support/harness.js';
import { routeList } from './support/route-list.js';

// BE0.2: the refactor moved code, not routes. This is index.ts's stack before
// the refactor (no ADMIN_SECRET), read from the built server; the PR shows the
// same comparison with a secret set.
test('the route list is unchanged by the refactor', async () => {
  const { createApp } = await import('../src/app.js');
  const app = createApp({ agent: {} as never, limiter: {} as never, now: () => 0, users: async () => null });
  assert.deepEqual(routeList(app), [
    'use * query',
    'use * expressInit',
    'use * helmetMiddleware',
    'use * corsMiddleware',
    'use * jsonParser',
    'use * <anonymous>',
    'GET /health',
    'use /auth router',
    'use /integrations router',
    'use /content authMiddleware',
    'use /content router',
    'use /goals authMiddleware',
    'use /goals router',
    'use /pipeline authMiddleware',
    'use /pipeline router',
    'use /podcasts authMiddleware',
    'use /podcasts router',
    'use /profile authMiddleware',
    'use /profile router',
    'use /claude authMiddleware',
    'use /claude router',
    'use /speech authMiddleware',
    'use /speech router',
    'use /integrations authMiddleware',
    'use /integrations router',
    'use /graph authMiddleware',
    'use /graph router',
    'use /v2 authMiddleware',
    'use /v2 router',
    'use /v2 v2ErrorHandler',
    'use * <anonymous>',
    'use * <anonymous>',
  ]);
});

test('the old routes keep their 401 bodies; /v2 answers in the envelope', async () => {
  const h = await startHarness();
  try {
    const old = await h.request('GET', '/content');
    assert.equal(old.status, 401);
    assert.deepEqual(old.body, { success: false, error: 'Missing or invalid authorization header' });
    const expired = await h.request('GET', '/content', undefined, { Authorization: 'Bearer nope' });
    assert.deepEqual(expired.body, { success: false, error: 'Invalid or expired token' });
    const v2 = await h.request('GET', '/v2/ping');
    assert.equal(v2.status, 401);
    assert.deepEqual(v2.body, { success: false, error: { code: 'unauthenticated', message: 'Please sign in again.' } });
  } finally {
    await h.close();
  }
});

test('a token for a user who no longer exists is a 401', async () => {
  const h = await startHarness();
  try {
    const token = h.asUser('33333333-3333-4333-8333-333333333333');
    h.users.clear();
    const res = await h.request('GET', '/v2/ping', undefined, { Authorization: `Bearer ${token}` });
    assert.equal(res.status, 401);
    const old = await h.request('GET', '/content', undefined, { Authorization: `Bearer ${token}` });
    assert.deepEqual(old.body, { success: false, error: 'User not found' });
  } finally {
    await h.close();
  }
});

test('a token with no user id in it is a 401, never a lookup', async () => {
  const h = await startHarness();
  try {
    const token = jwt.sign({ appleUserId: 'apple-x' }, process.env.JWT_SECRET ?? '');
    const res = await h.request('GET', '/v2/ping', undefined, { Authorization: `Bearer ${token}` });
    assert.equal(res.status, 401);
  } finally {
    await h.close();
  }
});

// An outage must not sign everyone out: the current app treats any 401 as "signed out".
test('a failing user lookup is a 500, not a 401', async () => {
  const { makeAuthMiddleware } = await import('../src/middleware/auth.js');
  const express = (await import('express')).default;
  const app = express();
  const failing = async (): Promise<null> => { throw new Error('connection reset'); };
  app.get('/old', makeAuthMiddleware(failing), (_req, res) => { res.json({ ok: true }); });
  app.get('/v2/x', makeAuthMiddleware(failing, { envelope: true }), (_req, res) => { res.json({ ok: true }); });
  const server = app.listen(0, '127.0.0.1');
  await new Promise<void>((resolve) => server.once('listening', () => resolve()));
  const port = (server.address() as AddressInfo).port;
  const token = jwt.sign({ userId: '44444444-4444-4444-8444-444444444444', appleUserId: 'a1' }, process.env.JWT_SECRET ?? '');
  const error = console.error;
  console.error = () => undefined;
  try {
    const old = await fetch(`http://127.0.0.1:${port}/old`, { headers: { Authorization: `Bearer ${token}` } });
    assert.equal(old.status, 500);
    assert.deepEqual(await old.json(), { success: false, error: 'Authentication error' });
    const v2 = await fetch(`http://127.0.0.1:${port}/v2/x`, { headers: { Authorization: `Bearer ${token}` } });
    assert.equal(v2.status, 500);
    assert.equal(((await v2.json()) as { error: { code: string } }).error.code, 'internal');
  } finally {
    console.error = error;
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});

test('a signed token whose user id is not a UUID is a 401, never a lookup', async () => {
  const h = await startHarness();
  let lookups = 0;
  const original = h.users.get.bind(h.users);
  h.users.get = (id: string) => { lookups++; return original(id); };
  try {
    for (const userId of ['u1', "1' OR '1'='1", '']) {
      const token = jwt.sign({ userId, appleUserId: 'a1', iat: Math.floor(h.clock.now / 1000) }, process.env.JWT_SECRET ?? '', { expiresIn: '1d' });
      const res = await h.request('GET', '/v2/ping', undefined, { Authorization: `Bearer ${token}` });
      assert.equal(res.status, 401, JSON.stringify(userId));
    }
    assert.equal(lookups, 0);
  } finally {
    await h.close();
  }
});
