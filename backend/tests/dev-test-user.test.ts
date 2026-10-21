import assert from 'node:assert/strict';
import type { AddressInfo } from 'node:net';
import test from 'node:test';
import express from 'express';
import type { AuthUser } from '../src/types/index.js';
import { DevTestUserRequestSchema, devTestIdentity, devTestUserHandler } from '../src/services/dev-test-user.js';

function handles() {
  let n = 0;
  return () => `00000000-0000-4000-8000-${String(n++).padStart(12, '0')}`;
}

/** A users table keyed on Apple subject; optionally fails the first create, as a lost insert race does. */
function fakeUsers(opts: { failFirst?: boolean } = {}) {
  const bySubject = new Map<string, AuthUser>();
  let calls = 0;
  return {
    bySubject,
    async getOrCreateUser(appleUserId: string, email?: string): Promise<AuthUser> {
      calls++;
      if (opts.failFirst && calls === 1) {
        bySubject.set(appleUserId, { id: 'winner', appleUserId, email });
        throw new Error('Failed to create user');
      }
      if (!bySubject.has(appleUserId)) bySubject.set(appleUserId, { id: `user-${bySubject.size + 1}`, appleUserId, email });
      return bySubject.get(appleUserId)!;
    },
  };
}

async function post(app: express.Express, body?: unknown) {
  const server = app.listen(0, '127.0.0.1');
  await new Promise<void>((resolve) => server.once('listening', () => resolve()));
  const { port } = server.address() as AddressInfo;
  try {
    const res = await fetch(`http://127.0.0.1:${port}/auth/dev/test-user`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });
    return { status: res.status, body: (await res.json()) as { success: boolean; data?: { user: { id: string } } } };
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
}

function appWith(users: ReturnType<typeof fakeUsers>, isProduction = false) {
  const app = express();
  app.use(express.json());
  app.post('/auth/dev/test-user', devTestUserHandler({
    isProduction, getOrCreateUser: users.getOrCreateUser, generateToken: () => 'test-token', newHandle: handles(),
  }));
  return app;
}

const quiet = <T>(fn: () => Promise<T>) => async () => {
  const log = console.log;
  const error = console.error;
  console.log = () => undefined;
  console.error = () => undefined;
  try { return await fn(); } finally { console.log = log; console.error = error; }
};

test('without a key, the dev route makes a new throwaway account each time', () => {
  const next = handles();
  const a = devTestIdentity(undefined, next);
  const b = devTestIdentity(undefined, next);
  assert.notEqual(a.appleUserId, b.appleUserId);
  assert.match(a.appleUserId, /^dev-test-user:/);
});

// A real Apple subject never starts with dev-test-user:, so no real account is reachable.
test('every dev identity is a dev-test-user subject', () => {
  for (const key of [undefined, 'fresh', 'day-one', 'month']) {
    assert.match(devTestIdentity(key, handles()).appleUserId, /^dev-test-user:/);
  }
});

test('a key must be a short lowercase slug, and nothing else is accepted', () => {
  assert.equal(DevTestUserRequestSchema.safeParse({}).success, true);
  assert.equal(DevTestUserRequestSchema.safeParse({ key: 'day-one' }).success, true);
  for (const bad of [{ key: 'Month' }, { key: '' }, { key: 'a'.repeat(33) }, { key: '../x' }, { key: 'month', userId: 'x' }]) {
    assert.equal(DevTestUserRequestSchema.safeParse(bad).success, false, JSON.stringify(bad));
  }
});

// BE0.S: seeding twice must find the same accounts, not make more.
test('over HTTP, the same key gives the same user', quiet(async () => {
  const users = fakeUsers();
  const app = appWith(users);
  const a = await post(app, { key: 'month' });
  const b = await post(app, { key: 'month' });
  assert.equal(a.status, 200);
  assert.equal(a.body.data?.user.id, b.body.data?.user.id);
  assert.equal(users.bySubject.size, 1);
  const fresh = await post(app);
  assert.notEqual(fresh.body.data?.user.id, a.body.data?.user.id, 'no body: a new throwaway account');
}));

test('over HTTP, a bad key is a 400 and nothing is created', quiet(async () => {
  const users = fakeUsers();
  const res = await post(appWith(users), { key: 'Bad Key' });
  assert.equal(res.status, 400);
  assert.equal(users.bySubject.size, 0);
}));

test('in production the dev route is a 404', quiet(async () => {
  const users = fakeUsers();
  const res = await post(appWith(users, true), { key: 'month' });
  assert.equal(res.status, 404);
  assert.equal(users.bySubject.size, 0);
}));

test('losing a first-insert race looks the user up again instead of answering 500', quiet(async () => {
  const res = await post(appWith(fakeUsers({ failFirst: true })), { key: 'month' });
  assert.equal(res.status, 200);
  assert.equal(res.body.data?.user.id, 'winner');
}));
