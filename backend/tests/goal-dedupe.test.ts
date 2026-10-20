import assert from 'node:assert/strict';
import test from 'node:test';
import { findSameGoal } from '../src/services/goal-dedupe.js';

const v = (k: number, j = 0) => Array.from({ length: 6 }, (_, d) => (d === k ? 1 : 0) + j * 0.01);

test('a near-copy of an existing goal is recognised; a different goal is not', () => {
  const existing = [{ id: 'raise', status: 'active', embedding: JSON.stringify(v(0)) }, { id: 'run', status: 'active', embedding: v(3) }];
  assert.equal(findSameGoal(existing, v(0, 1))?.goal.id, 'raise');
  assert.equal(findSameGoal(existing, v(5)), null);
});

test('an active copy is preferred to an expired one, so nothing is revived needlessly', () => {
  const existing = [{ id: 'old', status: 'expired', embedding: v(0) }, { id: 'live', status: 'active', embedding: v(0, 1) }];
  assert.equal(findSameGoal(existing, v(0))?.goal.id, 'live');
});

test('an expired goal stated again is found, to be revived', () => {
  assert.equal(findSameGoal([{ id: 'old', status: 'expired', embedding: v(2) }], v(2))?.goal.id, 'old');
});

test('goals without an embedding are ignored', () => {
  assert.equal(findSameGoal([{ id: 'x', embedding: null }], v(1)), null);
});
