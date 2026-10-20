import assert from 'node:assert/strict';
import test from 'node:test';
import { lifecycleFor } from '../src/services/goal-lifecycle.js';

const now = new Date('2026-10-20T00:00:00Z');

test('turning a goal off is quitting it, recorded at once', () => {
  assert.deepEqual(lifecycleFor(false, now), { is_active: false, status: 'quit', status_reason: 'turned off by you', status_at: now.toISOString() });
});

test('turning it back on makes it active again and undoes a merge', () => {
  const p = lifecycleFor(true, now);
  assert.equal(p.status, 'active');
  assert.equal(p.is_active, true);
  assert.equal(p.merged_into, null);
});
