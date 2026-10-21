import assert from 'node:assert/strict';
import test from 'node:test';
import { DevTestUserRequestSchema, devTestIdentity } from '../src/services/dev-test-user.js';

test('without a key, the dev route makes a new throwaway account each time', () => {
  let n = 0;
  const next = () => `00000000-0000-4000-8000-00000000000${n++}`;
  const a = devTestIdentity(undefined, next);
  const b = devTestIdentity(undefined, next);
  assert.notEqual(a.appleUserId, b.appleUserId);
  assert.match(a.appleUserId, /^dev-test-user:/);
});

// BE0.S: seeding twice must find the same accounts, not make more.
test('with a key, the dev route reaches the same seeded account every time', () => {
  assert.deepEqual(devTestIdentity('month'), devTestIdentity('month'));
  assert.notEqual(devTestIdentity('month').appleUserId, devTestIdentity('fresh').appleUserId);
});

// A real Apple subject never starts with dev-test-user:, so no real account is reachable.
test('every dev identity is a dev-test-user subject', () => {
  for (const key of [undefined, 'fresh', 'day-one', 'month']) {
    assert.match(devTestIdentity(key).appleUserId, /^dev-test-user:/);
  }
});

test('a key must be a short lowercase slug, and nothing else is accepted', () => {
  assert.equal(DevTestUserRequestSchema.safeParse({}).success, true);
  assert.equal(DevTestUserRequestSchema.safeParse({ key: 'day-one' }).success, true);
  for (const bad of [{ key: 'Month' }, { key: '' }, { key: 'a'.repeat(33) }, { key: '../x' }, { key: 'month', userId: 'x' }]) {
    assert.equal(DevTestUserRequestSchema.safeParse(bad).success, false, JSON.stringify(bad));
  }
});
