/**
 * The nine door tests (backend-engineer.md §4 step 10), written once. Each
 * door's test file calls doorSuite with how to reach it; every test runs over
 * HTTP against the real app (tests/support/harness.ts).
 *
 *   1. unauthenticated → 401          6. agent 5xx → 502
 *   2. waitlisted → 403               7. agent timeout → 504
 *   3. another user's id → 404        8. agent 404 → 404
 *   4. bad body → 400 with a code     9. happy path matches the contract fixture
 *   5. over the limit → 429
 *
 * A test that can't apply to a door (a door with no id in its path has no
 * "another user's thing"; a door that doesn't call the agent has no agent
 * failures) is reported as skipped with the reason, never silently dropped.
 */
import assert from 'node:assert/strict';
import test from 'node:test';
import { DOOR_LIMITS, type LimitBucket } from '../../src/doors/limits.js';
import type { AppDeps } from '../../src/app.js';
import { startHarness, type AgentReply, type Harness } from './harness.js';

export interface DoorSuiteSpec {
  /** For test names: `GET /v2/ping`. */
  method: 'GET' | 'POST' | 'PUT' | 'DELETE';
  path: string;
  bucket: LimitBucket;
  /** A valid body (POST/PUT) or undefined. */
  validBody?: unknown;
  /** A request that fails validation: for GET, a query string to append. */
  invalid: { body?: unknown; query?: string };
  /** Sets up a thing owned by another user and returns the path that names it. */
  otherUsersThing?: (h: Harness, otherUserId: string) => Promise<string> | string;
  /** The agent route the door calls, and a reply that makes it succeed. */
  agent?: { route: string; ok: () => AgentReply };
  /** When the path names a thing owned by one user: the path to the same kind of thing owned by `userId`. */
  pathFor?: (userId: string) => string;
  /** What the happy path's `data` must equal (the contract fixture). */
  expect: (userId: string) => unknown;
  setup?: (h: Harness, userId: string) => Promise<void> | void;
  /** A fresh diagnostics store for each test, for the diagnostics door. */
  diagnostics?: () => NonNullable<AppDeps['diagnostics']>;
  /** For doors not yet in createV2Router (the suite's own self-test). */
  v2Router?: AppDeps['v2Router'];
  /** Headers every request carries (e.g. an Idempotency-Key the door requires). */
  headers?: Record<string, string>;
  /** The harness clock at the start of every test (milliseconds), when the fixture carries a date. */
  now?: number;
  /** Doors a waitlisted person may use (access, waitlist, redeem). */
  openToWaitlisted?: boolean;
  /** Stores the door needs (e.g. access and invites on a test database). */
  stores?: () => Pick<NonNullable<Parameters<typeof startHarness>[0]>, 'access' | 'invites'>;
}

const USER = '11111111-1111-4111-8111-111111111111';
const OTHER = '22222222-2222-4222-8222-222222222222';

async function withHarness(spec: DoorSuiteSpec, fn: (h: Harness, auth: Record<string, string>) => Promise<void>) {
  const h = await startHarness({
    ...(spec.agent ? { agentRoutes: { [spec.agent.route]: spec.agent.ok } } : {}),
    ...(spec.v2Router ? { v2Router: spec.v2Router } : {}),
    ...(spec.diagnostics ? { diagnostics: spec.diagnostics() } : {}),
    ...(spec.stores ? spec.stores() : {}),
    ...(spec.now !== undefined ? { now: spec.now } : {}),
  });
  try {
    const auth = { Authorization: `Bearer ${h.asUser(USER)}` };
    await spec.setup?.(h, USER);
    await fn(h, auth);
  } finally {
    await h.close();
  }
}

/** The door's own path for the second user: the same path unless it names the first user's thing. */
const otherUsersOwnPath = (spec: DoorSuiteSpec) => spec.pathFor?.(OTHER) ?? spec.path;

const code = (body: unknown) => (body as { error?: { code?: string } }).error?.code;

export function doorSuite(spec: DoorSuiteSpec): void {
  const name = `${spec.method} ${spec.path}`;
  const send = (h: Harness, headers: Record<string, string>, path = spec.path, body = spec.validBody) =>
    h.request(spec.method, path, body, { ...spec.headers, ...headers });

  test(`${name}: unauthenticated is a 401 envelope`, () => withHarness(spec, async (h) => {
    const res = await send(h, {});
    assert.equal(res.status, 401);
    assert.equal(code(res.body), 'unauthenticated');
    const bad = await send(h, { Authorization: 'Bearer not-a-token' });
    assert.equal(bad.status, 401);
    assert.equal(code(bad.body), 'unauthenticated');
    assert.equal(h.agentCalls.length, 0, 'the agent is never reached');
  }));

  test(`${name}: an expired token is a 401`, () => withHarness(spec, async (h, auth) => {
    h.clock.now += 31 * 24 * 60 * 60 * 1000;
    const res = await send(h, auth);
    assert.equal(res.status, 401);
    assert.equal(code(res.body), 'unauthenticated');
    assert.equal(h.agentCalls.length, 0);
  }));

  if (spec.openToWaitlisted) {
    test(`${name}: a waitlisted user may use this door`, () => withHarness(spec, async (h, auth) => {
      h.users.set(USER, { ...h.users.get(USER)!, access: 'waitlisted' });
      const res = await send(h, auth);
      assert.notEqual(code(res.body), 'invite_required');
      assert.ok(res.status < 400, `status ${res.status}`);
    }));
  } else {
    test(`${name}: a waitlisted user is a 403`, () => withHarness(spec, async (h, auth) => {
      h.users.set(USER, { ...h.users.get(USER)!, access: 'waitlisted' });
      const res = await send(h, auth);
      assert.equal(res.status, 403);
      assert.equal(code(res.body), 'invite_required');
      assert.equal(h.agentCalls.length, 0);
    }));
  }

  test(`${name}: a suspended user is a 403`, () => withHarness(spec, async (h, auth) => {
    h.users.set(USER, { ...h.users.get(USER)!, access: 'suspended' });
    const res = await send(h, auth);
    assert.equal(res.status, 403);
    assert.equal(code(res.body), 'suspended');
    assert.equal(h.agentCalls.length, 0);
  }));

  if (spec.otherUsersThing) {
    const otherUsersThing = spec.otherUsersThing;
    test(`${name}: another user's id is a 404, not a 403`, () => withHarness(spec, async (h, auth) => {
      h.asUser(OTHER);
      const path = await otherUsersThing(h, OTHER);
      const res = await send(h, auth, path);
      assert.equal(res.status, 404);
      assert.equal(code(res.body), 'not_found');
      assert.equal(h.agentCalls.length, 0, 'refused before the agent: ownership is checked by the door, not left to the agent');
    }));
  } else {
    test(`${name}: another user's id is a 404`, { skip: 'this door names no thing by id' }, () => undefined);
  }

  test(`${name}: a bad request is a 400 with a code`, () => withHarness(spec, async (h, auth) => {
    const path = spec.invalid.query ? `${spec.path}?${spec.invalid.query}` : spec.path;
    const res = await send(h, auth, path, spec.invalid.body ?? spec.validBody);
    assert.equal(res.status, 400);
    assert.equal(code(res.body), 'invalid_request');
    assert.equal(h.agentCalls.length, 0, 'the agent is never reached');
  }));

  test(`${name}: over the limit is a 429 with retryAfterSeconds`, () => withHarness(spec, async (h, auth) => {
    const max = Math.min(...DOOR_LIMITS.buckets[spec.bucket].map((w) => w.max));
    for (let i = 0; i < max; i++) assert.equal((await send(h, auth)).status < 400, true, `request ${i + 1} is allowed`);
    const res = await send(h, auth);
    assert.equal(res.status, 429);
    assert.equal(code(res.body), 'rate_limited');
    assert.ok(((res.body as { error: { retryAfterSeconds?: number } }).error.retryAfterSeconds ?? 0) > 0);
    const other = await send(h, { Authorization: `Bearer ${h.asUser(OTHER)}` }, otherUsersOwnPath(spec));
    assert.notEqual(other.status, 429, 'another user is not limited by this one');
    assert.notEqual(other.status, 401, 'and was really signed in');
  }));

  if (spec.agent) {
    const route = spec.agent.route;
    for (const [label, reply, status, expected] of [
      ['an agent 5xx is a 502', { status: 500, body: { error: 'relation "x" does not exist' } }, 502, 'upstream_unavailable'],
      ['an agent timeout is a 504', 'hang', 504, 'upstream_timeout'],
      ['an agent 404 is a 404', { status: 404, body: { error: 'not found' } }, 404, 'not_found'],
    ] as const) {
      test(`${name}: ${label}`, () => withHarness(spec, async (h, auth) => {
        h.setAgent({ [route]: () => reply });
        const res = await send(h, auth);
        assert.equal(res.status, status);
        assert.equal(code(res.body), expected);
        assert.equal(JSON.stringify(res.body).includes('relation'), false, 'the agent\'s words never reach the app');
      }));
    }
  } else {
    for (const label of ['an agent 5xx is a 502', 'an agent timeout is a 504', 'an agent 404 is a 404']) {
      test(`${name}: ${label}`, { skip: 'this door does not call the agent' }, () => undefined);
    }
  }

  test(`${name}: the happy path matches the contract`, () => withHarness(spec, async (h, auth) => {
    const res = await send(h, auth);
    assert.equal(res.status, 200);
    assert.deepEqual(res.body, { success: true, data: spec.expect(USER) });
  }));
}
