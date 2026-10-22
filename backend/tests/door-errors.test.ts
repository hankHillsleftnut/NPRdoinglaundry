import assert from 'node:assert/strict';
import test from 'node:test';
import { AgentCallError, DOOR_ERROR_CODES, DOOR_ERRORS, DoorError, errorBody, fromAgentError } from '../src/doors/errors.js';

test('the error codes are exactly contract 00\'s closed list plus the invite codes', () => {
  assert.deepEqual([...DOOR_ERROR_CODES].sort(), [
    'idempotency_mismatch', 'internal', 'invalid_credentials', 'invalid_request', 'invite_expired', 'invite_invalid',
    'invite_required', 'invite_used', 'not_found', 'rate_limited', 'session_revoked', 'spend_limited', 'suspended',
    'unauthenticated', 'update_required', 'upstream_timeout', 'upstream_unavailable',
  ]);
  assert.equal(DOOR_ERRORS.update_required.status, 426);
  assert.equal(DOOR_ERRORS.upstream_unavailable.status, 502);
  assert.equal(DOOR_ERRORS.upstream_timeout.status, 504);
});

test('only rate_limited and spend_limited carry retryAfterSeconds', () => {
  assert.deepEqual(errorBody(new DoorError('rate_limited', { retryAfterSeconds: 30 })).error.retryAfterSeconds, 30);
  assert.equal('retryAfterSeconds' in errorBody(new DoorError('not_found', { retryAfterSeconds: 30 })).error, false);
});

test('an agent 429 with spentUsd becomes spend_limited', () => {
  const { error } = fromAgentError(new AgentCallError({ kind: 'http', status: 429, spentUsd: 15.2 }));
  assert.equal(error.code, 'spend_limited');
  assert.ok((error.retryAfterSeconds ?? 0) > 0);
  assert.equal(fromAgentError(new AgentCallError({ kind: 'http', status: 429 })).error.code, 'rate_limited');
});

test('an agent timeout becomes upstream_timeout', () => {
  assert.equal(fromAgentError(new AgentCallError({ kind: 'timeout' })).error.code, 'upstream_timeout');
});

test('agent failures map to the contract, and an agent 400 is logged as our bug', () => {
  const map = (status: number) => fromAgentError(new AgentCallError({ kind: 'http', status }));
  assert.deepEqual([map(400).error.code, map(400).isBug], ['invalid_request', true]);
  assert.equal(map(404).error.code, 'not_found');
  assert.equal(map(500).error.code, 'upstream_unavailable');
  assert.equal(map(503).error.code, 'upstream_unavailable');
  assert.equal(fromAgentError(new AgentCallError({ kind: 'network' })).error.code, 'upstream_unavailable');
  assert.deepEqual([fromAgentError(new Error('boom')).error.code, fromAgentError(new Error('boom')).isBug], ['internal', true]);
});

test('an agent 500 never leaks its message', () => {
  const leaked = 'duplicate key value violates unique constraint "raw_content_pkey"';
  const err = Object.assign(new AgentCallError({ kind: 'http', status: 500 }), { agentMessage: leaked });
  const body = JSON.stringify(errorBody(fromAgentError(err).error));
  assert.equal(body.includes('duplicate key'), false);
  assert.equal(body.includes('raw_content'), false);
});
