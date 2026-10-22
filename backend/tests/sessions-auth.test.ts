import assert from 'node:assert/strict';
import test from 'node:test';
import jwt from 'jsonwebtoken';
import { startHarness } from './support/harness.js';
import { issueAccessToken } from '../src/sessions/tokens.js';

const USER = '11111111-1111-4111-8111-111111111111';
const SECRET = process.env.JWT_SECRET ?? '';

test('a new access token signs in to /v2 and to the old routes', async () => {
  const h = await startHarness();
  try {
    h.users.set(USER, { id: USER, appleUserId: 'apple-1', tokenVersion: 0 });
    const { token } = issueAccessToken({ userId: USER, tokenVersion: 0 }, SECRET, h.clock.now);
    const ping = await h.request('GET', '/v2/ping', undefined, { Authorization: `Bearer ${token}` });
    assert.deepEqual(ping.body, { success: true, data: { userId: USER } });
    // An old route: past auth, /content's own validation answers 400 for an empty body.
    const content = await h.request('POST', '/content', {}, { Authorization: `Bearer ${token}` });
    assert.equal(content.status, 400);
    assert.equal((content.body as { error: string }).error, 'Invalid request body');
  } finally {
    await h.close();
  }
});

test('an access token stops working after 15 minutes', async () => {
  const h = await startHarness();
  try {
    h.users.set(USER, { id: USER, appleUserId: 'apple-1', tokenVersion: 0 });
    const { token } = issueAccessToken({ userId: USER, tokenVersion: 0 }, SECRET, h.clock.now);
    h.clock.now += 15 * 60 * 1000 + 1000;
    assert.equal((await h.request('GET', '/v2/ping', undefined, { Authorization: `Bearer ${token}` })).status, 401);
  } finally {
    await h.close();
  }
});

test('a bumped token version ends access tokens issued before it', async () => {
  const h = await startHarness();
  try {
    h.users.set(USER, { id: USER, appleUserId: 'apple-1', tokenVersion: 1 });
    const { token } = issueAccessToken({ userId: USER, tokenVersion: 0 }, SECRET, h.clock.now);
    assert.equal((await h.request('GET', '/v2/ping', undefined, { Authorization: `Bearer ${token}` })).status, 401);
  } finally {
    await h.close();
  }
});

test('old 30-day tokens still pass old routes', async () => {
  const h = await startHarness();
  try {
    h.users.set(USER, { id: USER, appleUserId: 'apple-1' });
    const old = jwt.sign({ userId: USER, appleUserId: 'apple-1', iat: Math.floor(h.clock.now / 1000) }, SECRET, { expiresIn: '30d' });
    // /content with no body: past auth, the route's own validation answers 400.
    const res = await h.request('POST', '/content', {}, { Authorization: `Bearer ${old}` });
    assert.equal(res.status, 400);
    assert.equal((await h.request('GET', '/v2/ping', undefined, { Authorization: `Bearer ${old}` })).status, 200, 'and /v2 too, until X07');
  } finally {
    await h.close();
  }
});

// Integrator review: before migration 005 the lookup has no version, and a new token must not pass.
test('a user with no token version (005 not applied) is refused a new access token', async () => {
  const h = await startHarness();
  try {
    h.users.set(USER, { id: USER, appleUserId: 'apple-1' });
    const { token } = issueAccessToken({ userId: USER, tokenVersion: 0 }, SECRET, h.clock.now);
    assert.equal((await h.request('GET', '/v2/ping', undefined, { Authorization: `Bearer ${token}` })).status, 401);
    assert.equal((await h.request('POST', '/content', {}, { Authorization: `Bearer ${token}` })).status, 401);
  } finally {
    await h.close();
  }
});
