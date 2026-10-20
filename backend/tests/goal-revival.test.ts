import assert from 'node:assert/strict';
import test from 'node:test';
import { blocksRevival } from '../src/services/goal-lifecycle.js';

// App audit G1: the app's goal sync turned "on" every goal the server had off,
// undoing the brain's merges and expiries. Only an explicit revive brings one back.
test('an automatic sync cannot revive a goal the brain merged or expired', () => {
  assert.equal(blocksRevival('merged', true, undefined), true);
  assert.equal(blocksRevival('expired', true, false), true);
});

test('the person can still revive it on purpose, and ordinary goals switch freely', () => {
  assert.equal(blocksRevival('expired', true, true), false);
  assert.equal(blocksRevival('quit', true, undefined), false, 'a goal they turned off themselves can come back');
  assert.equal(blocksRevival('active', true, undefined), false);
  assert.equal(blocksRevival('merged', false, undefined), false, 'turning off is never blocked');
});
