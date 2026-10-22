import assert from 'node:assert/strict';
import type { AddressInfo } from 'node:net';
import test from 'node:test';
import express, { type RequestHandler } from 'express';
import { z } from 'zod';
import type { AgentDoorClient } from '../src/doors/agent.js';
import { createDoorKit, type DoorSpec } from '../src/doors/door.js';
import { AgentCallError, v2ErrorHandler } from '../src/doors/errors.js';
import { DOOR_LIMITS, MemoryLimiter } from '../src/doors/limits.js';
import { createV2Router } from '../src/doors/router.js';
import { createLog } from '../src/utils/log.js';

const ALICE = '11111111-1111-4111-8111-111111111111';
const BOB = '22222222-2222-4222-8222-222222222222';
const T0 = 1_800_000_000_000;
const ENTRY_TEXT = 'went for a long walk and thought about the move';

const noAgent: AgentDoorClient = {
  get: async () => { throw new Error('no agent in this test'); },
  post: async () => { throw new Error('no agent in this test'); },
  put: async () => { throw new Error('no agent in this test'); },
};

/** A tiny app: a fake auth middleware (x-test-user), the kit, the v2 error handler. */
async function harness(mount: (door: ReturnType<typeof createDoorKit>, router: express.Router) => void, opts: {
  agent?: AgentDoorClient; limiter?: MemoryLimiter; clock?: { now: number }; reportThrows?: boolean;
} = {}) {
  const clock = opts.clock ?? { now: T0 };
  const limiter = opts.limiter ?? new MemoryLimiter();
  const lines: string[] = [];
  const bugs: string[] = [];
  const door = createDoorKit({
    agent: opts.agent ?? noAgent, limiter, log: createLog((l) => lines.push(l)), now: () => clock.now,
    reportBug: (_err, name) => {
      bugs.push(name);
      if (opts.reportThrows) throw new Error('Sentry is down');
    },
  });
  const router = express.Router();
  mount(door, router);
  const fakeAuth: RequestHandler = (req, _res, next) => {
    const id = req.header('x-test-user');
    if (id) req.user = { id, appleUserId: `apple-${id}` };
    next();
  };
  const app = express();
  app.use(express.json());
  app.use('/v2', fakeAuth, router);
  app.use('/v2', v2ErrorHandler);
  app.use((_err: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
    res.status(500).json({ success: false, error: 'app-wide handler reached' });
  });
  const server = app.listen(0, '127.0.0.1');
  await new Promise<void>((resolve) => server.once('listening', () => resolve()));
  const { port } = server.address() as AddressInfo;
  const request = async (method: string, path: string, init: { user?: string; body?: string; headers?: Record<string, string> } = {}) => {
    const res = await fetch(`http://127.0.0.1:${port}/v2${path}`, {
      method,
      headers: { 'Content-Type': 'application/json', ...(init.user ? { 'x-test-user': init.user } : {}), ...init.headers },
      ...(init.body !== undefined ? { body: init.body } : {}),
    });
    return { status: res.status, headers: res.headers, body: (await res.json()) as Record<string, unknown> };
  };
  return { request, lines, bugs, limiter, clock, close: () => new Promise<void>((resolve) => server.close(() => resolve())) };
}

const errorCode = (body: Record<string, unknown>) => (body.error as { code: string }).code;

const notes = new Map<string, string>([['n1', ALICE]]);
const noteDoor: DoorSpec<{ id: string }, { id: string }, { id: string }> = {
  name: 'notes.get',
  bucket: 'read',
  request: z.object({ id: z.string() }).strict(),
  owns: async (ctx, req) => notes.get(req.id) === ctx.userId,
  call: async (_ctx, req) => ({ id: req.id }),
  map: (r) => r,
};

test('/v2/ping answers the user from the token through the kit', async () => {
  const h = await harness((door, router) => router.use(createV2Router(door, { diagnostics: {} as never, invites: {} as never, briefs: {} as never, guesses: {} as never })));
  try {
    const res = await h.request('GET', '/ping', { user: ALICE });
    assert.equal(res.status, 200);
    assert.deepEqual(res.body, { success: true, data: { userId: ALICE } });
  } finally {
    await h.close();
  }
});

test('without a signed-in user a door is a 401 envelope', async () => {
  const h = await harness((door, router) => router.use(createV2Router(door, { diagnostics: {} as never, invites: {} as never, briefs: {} as never, guesses: {} as never })));
  try {
    const res = await h.request('GET', '/ping');
    assert.equal(res.status, 401);
    assert.equal(errorCode(res.body), 'unauthenticated');
  } finally {
    await h.close();
  }
});

test('owns() false answers not_found, not forbidden', async () => {
  const h = await harness((door, router) => router.get('/notes/:id', door(noteDoor)));
  try {
    assert.equal((await h.request('GET', '/notes/n1', { user: ALICE })).status, 200);
    const other = await h.request('GET', '/notes/n1', { user: BOB });
    assert.equal(other.status, 404);
    assert.equal(errorCode(other.body), 'not_found');
  } finally {
    await h.close();
  }
});

test('a userId sent by the client is refused, never used', async () => {
  const h = await harness((door, router) => router.get('/ping', door({
    name: 'ping', bucket: 'read', request: z.object({}).strict(), call: async (ctx) => ({ userId: ctx.userId }), map: (r) => r,
  })));
  try {
    const res = await h.request('GET', `/ping?userId=${BOB}`, { user: ALICE });
    assert.equal(res.status, 400);
    assert.equal(errorCode(res.body), 'invalid_request');
  } finally {
    await h.close();
  }
});

test('a bad body is invalid_request with nothing echoed back', async () => {
  const h = await harness((door, router) => router.post('/entries', door({
    name: 'entries.create', bucket: 'write', request: z.object({ text: z.string().max(10) }).strict(),
    call: async () => ({}), map: () => ({}),
  })));
  try {
    const res = await h.request('POST', '/entries', { user: ALICE, body: JSON.stringify({ text: ENTRY_TEXT }) });
    assert.equal(res.status, 400);
    assert.equal(JSON.stringify(res.body).includes('walk'), false);
    const broken = await h.request('POST', '/entries', { user: ALICE, body: '{"text": ' });
    assert.equal(broken.status, 400, 'a body that is not JSON gets the envelope too');
    assert.equal(errorCode(broken.body), 'invalid_request');
  } finally {
    await h.close();
  }
});

test('over the limit is rate_limited with retryAfterSeconds and Retry-After', async () => {
  const h = await harness((door, router) => router.use(createV2Router(door, { diagnostics: {} as never, invites: {} as never, briefs: {} as never, guesses: {} as never })));
  try {
    for (let i = 0; i < DOOR_LIMITS.buckets.read[0]!.max; i++) await h.request('GET', '/ping', { user: ALICE });
    const res = await h.request('GET', '/ping', { user: ALICE });
    assert.equal(res.status, 429);
    assert.deepEqual(res.body.error, { code: 'rate_limited', message: 'Too many tries. Try again in a minute.', retryAfterSeconds: 60 });
    assert.equal(res.headers.get('retry-after'), '60');
    assert.equal((await h.request('GET', '/ping', { user: BOB })).status, 200, 'another user is unaffected');
  } finally {
    await h.close();
  }
});

test('an expensive door over the daily spend is spend_limited; a read never is', async () => {
  const limiter = new MemoryLimiter();
  limiter.recordSpend(ALICE, DOOR_LIMITS.dailySpendCapUsd, T0 - 1000);
  const h = await harness((door, router) => {
    router.post('/costly', door({ name: 'costly', bucket: 'expensive', request: z.object({}).strict(), call: async () => ({}), map: () => ({}) }));
    router.use(createV2Router(door, { diagnostics: {} as never, invites: {} as never, briefs: {} as never, guesses: {} as never }));
  }, { limiter });
  try {
    const res = await h.request('POST', '/costly', { user: ALICE, body: '{}' });
    assert.equal(res.status, 429);
    assert.equal(errorCode(res.body), 'spend_limited');
    assert.ok(((res.body.error as { retryAfterSeconds?: number }).retryAfterSeconds ?? 0) > 0);
    assert.equal((await h.request('GET', '/ping', { user: ALICE })).status, 200);
  } finally {
    await h.close();
  }
});

test('a door that throws asynchronously still answers with the envelope', async () => {
  const h = await harness((door, router) => router.get('/boom', door({
    name: 'boom', bucket: 'read', request: z.object({}).strict(),
    call: async () => { await new Promise((r) => setImmediate(r)); throw new Error(`secret detail: ${ENTRY_TEXT}`); },
    map: () => ({}),
  })));
  try {
    const res = await h.request('GET', '/boom', { user: ALICE });
    assert.equal(res.status, 500);
    assert.equal(errorCode(res.body), 'internal');
    assert.equal(JSON.stringify(res.body).includes('secret'), false, 'the app-wide handler is never reached and nothing leaks');
    assert.deepEqual(h.bugs, ['boom'], 'the bug is reported to the server side');
  } finally {
    await h.close();
  }
});

test('agent failures reach the app as the contract\'s codes', async () => {
  for (const [failure, status, code] of [
    [{ kind: 'http', status: 500 }, 502, 'upstream_unavailable'],
    [{ kind: 'timeout' }, 504, 'upstream_timeout'],
    [{ kind: 'http', status: 404 }, 404, 'not_found'],
    [{ kind: 'http', status: 400 }, 400, 'invalid_request'],
  ] as const) {
    const agent: AgentDoorClient = { ...noAgent, get: async () => { throw new AgentCallError(failure); } };
    const h = await harness((door, router) => router.get('/x', door({
      name: 'x', bucket: 'read', request: z.object({}).strict(), call: (ctx) => ctx.agent.get('/x', { timeoutMs: 10, retry: 'read' }), map: () => ({}),
    })), { agent });
    try {
      const res = await h.request('GET', '/x', { user: ALICE });
      assert.equal(res.status, status);
      assert.equal(errorCode(res.body), code);
      assert.equal(h.bugs.length, failure.kind === 'http' && failure.status === 400 ? 1 : 0, 'only an agent 400 is our bug');
    } finally {
      await h.close();
    }
  }
});

test('one content-free log line per request, with agent time and spend recorded', async () => {
  const clock = { now: T0 };
  const agent: AgentDoorClient = { ...noAgent, post: async <T>() => { clock.now += 40; return { costUsd: 0.25, text: ENTRY_TEXT } as T; } };
  const h = await harness((door, router) => router.post('/entries', door({
    name: 'entries.create', bucket: 'write', request: z.object({ text: z.string() }).strict(),
    call: (ctx, req) => ctx.agent.post<{ costUsd: number; text: string }>('/ingest', req, { timeoutMs: 10, retry: 'none' }),
    cost: (r) => r.costUsd, map: () => ({ saved: true }),
  })), { clock, agent });
  try {
    await h.request('POST', '/entries', { user: ALICE, body: JSON.stringify({ text: ENTRY_TEXT }), headers: { 'X-App-Version': '1.0 (42)' } });
    assert.equal(h.lines.length, 1);
    assert.equal(h.lines[0]!.includes('walk'), false);
    assert.deepEqual(JSON.parse(h.lines[0]!), {
      door: 'entries.create', userId: ALICE, status: 200, ms: 40, agentMs: 40, costUsd: 0.25, appVersion: '1.0 (42)',
    });
    assert.equal(h.limiter.spentToday(ALICE, clock.now), 0.25, 'the spend counts toward the cap');
  } finally {
    await h.close();
  }
});

test('the time zone header is used only when it names a real zone', async () => {
  const seen: (string | null)[] = [];
  const h = await harness((door, router) => router.get('/tz', door({
    name: 'tz', bucket: 'read', request: z.object({}).strict(), call: async (ctx) => { seen.push(ctx.timeZone); return {}; }, map: () => ({}),
  })));
  try {
    await h.request('GET', '/tz', { user: ALICE, headers: { 'X-Time-Zone': 'America/Los_Angeles' } });
    await h.request('GET', '/tz', { user: ALICE, headers: { 'X-Time-Zone': 'Not/AZone' } });
    await h.request('GET', '/tz', { user: ALICE });
    assert.deepEqual(seen, ['America/Los_Angeles', null, null]);
  } finally {
    await h.close();
  }
});

// Integrator review of #79: a failing bug report must not break the answer.
test('a door still answers its envelope when reporting the bug fails', async () => {
  const h = await harness((door, router) => router.get('/boom', door({
    name: 'boom', bucket: 'read', request: z.object({}).strict(),
    call: async () => { throw new Error('boom'); }, map: () => ({}),
  })), { reportThrows: true });
  try {
    const res = await h.request('GET', '/boom', { user: ALICE });
    assert.equal(res.status, 500);
    assert.equal(errorCode(res.body), 'internal');
    assert.equal(h.lines.length, 1, 'and the log line is still written');
  } finally {
    await h.close();
  }
});

// Integrator review of #79: every client-side body failure is the request's fault.
test('a body in an unsupported charset is invalid_request, not a 500', async () => {
  const h = await harness((door, router) => router.use(createV2Router(door, { diagnostics: {} as never, invites: {} as never, briefs: {} as never, guesses: {} as never })));
  try {
    const res = await h.request('POST', '/ping', { user: ALICE, body: '{}', headers: { 'Content-Type': 'application/json; charset=latin1' } });
    assert.equal(res.status, 400);
    assert.equal(errorCode(res.body), 'invalid_request');
  } finally {
    await h.close();
  }
});

test('an unknown /v2 path is the envelope\'s 404', async () => {
  const h = await harness((door, router) => router.use(createV2Router(door, { diagnostics: {} as never, invites: {} as never, briefs: {} as never, guesses: {} as never })));
  try {
    const res = await h.request('GET', '/nothing-here', { user: ALICE });
    assert.equal(res.status, 404);
    assert.equal(errorCode(res.body), 'not_found');
  } finally {
    await h.close();
  }
});
