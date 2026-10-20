import assert from 'node:assert/strict';
import test from 'node:test';
import { correctionMode } from '../src/services/assertion-feedback.js';

// Finding 51: "contradict" used to write an active copy of the fact it contradicted,
// which kept showing in search. Both verdicts now go through the agent's correction path.
test('contradict means it was wrong; retire means it changed; confirm corrects nothing', () => {
  assert.equal(correctionMode('contradict'), 'wrong');
  assert.equal(correctionMode('retire'), 'changed');
  assert.equal(correctionMode('confirm'), null);
});
