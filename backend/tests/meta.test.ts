/**
 * BE0.10 over HTTP on the real app (harness): GET /v2/meta is public and
 * never behind the floor; every signed-in door turns an old build away with
 * update_required; a request with no usable version passes until the floor is
 * required. The floor is parsed once, at start.
 */
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import test from 'node:test';
import { startHarness } from './support/harness.js';
import { checkAppVersion, environmentOf, minBuildOf, parseAppVersion, type AppVersions } from '../src/doors/versions.js';
import { createDoorKit } from '../src/doors/door.js';
import { DOOR_LIMITS } from '../src/doors/limits.js';

const FIXTURES = join(__dirname, '..', '..', 'docs', 'team', 'contracts', 'fixtures', '00');
const fixture = (name: string) => JSON.parse(readFileSync(join(FIXTURES, name), 'utf8')) as unknown;
const USER = '11111111-1111-4111-8111-111111111111';
const STAGING: AppVersions = { minVersion: '1.0 (40)', latestVersion: '1.1 (55)', requireVersion: false, environment: 'staging' };
const code = (body: unknown) => (body as { error?: { code?: string } }).error?.code;

test('meta is public and equals the contract fixture, whatever version asks', async () => {
  const h = await startHarness({ versions: STAGING, now: Date.parse('2026-10-21T08:00:04.200Z') });
  try {
    const res = await h.request('GET', '/v2/meta');
    assert.equal(res.status, 200);
    assert.deepEqual(res.body, fixture('meta.json'));
    assert.equal(res.headers.get('cache-control'), 'no-store');
    const old = await h.request('GET', '/v2/meta', undefined, { 'X-App-Version': '1.0 (1)' });
    assert.equal(old.status, 200, 'an old build must be able to ask how old it is');
    assert.equal(h.agentCalls.length, 0);
    assert.ok(h.logLines.some((l) => l.includes('"door":"meta"')), 'logged as a door, with no user');
  } finally {
    await h.close();
  }
});

test('an old build gets update_required on every signed-in door; the floor and newer pass (*)', async () => {
  const h = await startHarness({ versions: STAGING });
  try {
    const auth = { Authorization: `Bearer ${h.asUser(USER)}` };
    const old = await h.request('GET', '/v2/ping', undefined, { ...auth, 'X-App-Version': '1.0 (39)' });
    assert.equal(old.status, 426);
    assert.deepEqual(old.body, fixture('error.update_required.json'), 'the contract envelope exactly');
    assert.equal(h.agentCalls.length, 0);
    for (const v of ['1.0 (40)', '1.0 (41)', '0.9 (40)', '1.1 (55)', '2.0 (100.2)', '1.0 (40.1)']) {
      assert.equal((await h.request('GET', '/v2/ping', undefined, { ...auth, 'X-App-Version': v })).status, 200, v);
    }
    assert.equal((await h.request('GET', '/v2/ping', undefined, { ...auth, 'X-App-Version': '1.0 (39.9)' })).status, 426, 'a dotted build compares by its first number');
    const unsigned = await h.request('GET', '/v2/ping', undefined, { 'X-App-Version': '1.0 (39)' });
    assert.equal(code(unsigned.body), 'unauthenticated', 'who you are comes first; an old build learns nothing without a token');
  } finally {
    await h.close();
  }
});

test('a missing or malformed version passes until the floor is required, then is update_required', async () => {
  const lenient = await startHarness({ versions: STAGING });
  try {
    const auth = { Authorization: `Bearer ${lenient.asUser(USER)}` };
    assert.equal((await lenient.request('GET', '/v2/ping', undefined, auth)).status, 200, 'no header');
    assert.equal((await lenient.request('GET', '/v2/ping', undefined, { ...auth, 'X-App-Version': 'not a version' })).status, 200, 'a header that is not a version is treated as none');
  } finally {
    await lenient.close();
  }
  const strict = await startHarness({ versions: { ...STAGING, requireVersion: true } });
  try {
    const auth = { Authorization: `Bearer ${strict.asUser(USER)}` };
    assert.equal(code((await strict.request('GET', '/v2/ping', undefined, auth)).body), 'update_required', 'no header');
    assert.equal(code((await strict.request('GET', '/v2/ping', undefined, { ...auth, 'X-App-Version': 'dentist at 3' })).body), 'update_required');
    assert.equal((await strict.request('GET', '/v2/ping', undefined, { ...auth, 'X-App-Version': '1.0 (40)' })).status, 200);
    assert.equal((await strict.request('GET', '/v2/meta')).status, 200, 'meta still answers without a header');
  } finally {
    await strict.close();
  }
});

test('meta is limited per address with the contract envelope', async () => {
  const h = await startHarness({ versions: STAGING });
  try {
    const max = DOOR_LIMITS.buckets.read[0]!.max;
    for (let i = 0; i < max; i++) assert.equal((await h.request('GET', '/v2/meta')).status, 200);
    const over = await h.request('GET', '/v2/meta');
    assert.equal(over.status, 429);
    assert.equal(code(over.body), 'rate_limited');
    assert.ok(((over.body as { error: { retryAfterSeconds?: number } }).error.retryAfterSeconds ?? 0) > 0);
  } finally {
    await h.close();
  }
});

test('versions parse as the contract writes them, and a server with an unreadable floor does not start', () => {
  assert.deepEqual(parseAppVersion('1.0 (42)'), { version: '1.0', build: 42 });
  assert.deepEqual(parseAppVersion('1.2.3 (42.1.5)'), { version: '1.2.3', build: 42 });
  for (const bad of ['1.0', '1.0 (x)', '(42)', '1.0 (42', ' 1.0 (42)', '1.0  (42)', '1.0 (42) ', '', 'v1.0 (42)']) assert.equal(parseAppVersion(bad), null, JSON.stringify(bad));
  assert.equal(checkAppVersion(undefined, 40, false), 'ok');
  assert.equal(checkAppVersion(undefined, 40, true), 'update_required');
  assert.equal(checkAppVersion('1.0 (39)', 40, false), 'update_required');
  assert.equal(checkAppVersion('1.0 (40)', 40, true), 'ok');
  assert.equal(minBuildOf({ minVersion: '1.0 (40)' }), 40);
  assert.throws(() => createDoorKit({ agent: {} as never, limiter: {} as never, log: { door: () => undefined }, now: () => 0, reportBug: () => undefined, versions: { minVersion: 'soon', requireVersion: false } }), /MIN_APP_VERSION/);
  assert.equal(environmentOf('staging', 'production'), 'staging');
  assert.equal(environmentOf('production', 'development'), 'production');
  assert.equal(environmentOf(undefined, 'production'), 'production');
  assert.equal(environmentOf(undefined, 'development'), 'local');
  assert.equal(environmentOf('development', 'production'), 'local', 'only the two named environments are not local');
});
