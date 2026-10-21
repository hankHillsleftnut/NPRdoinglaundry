import assert from 'node:assert/strict';
import test from 'node:test';
import { CallLog, CLAUDE_LIMITS, guardClaudeRequest } from '../src/services/claude-guard.js';

const ok = { userMessage: 'hi' };

test('signed-out callers are refused', () => {
  const r = guardClaudeRequest(undefined, ok, new CallLog());
  assert.equal(r.ok, false);
  assert.equal(!r.ok && r.status, 401);
});

test('each user is capped per hour, and others are unaffected', () => {
  const log = new CallLog();
  const now = 1_000_000_000_000;
  for (let i = 0; i < CLAUDE_LIMITS.perHour; i++) assert.equal(guardClaudeRequest('a', ok, log, now + i).ok, true);
  const blocked = guardClaudeRequest('a', ok, log, now + 100);
  assert.equal(!blocked.ok && blocked.status, 429);
  assert.equal(guardClaudeRequest('b', ok, log, now + 100).ok, true, 'another user still works');
  assert.equal(guardClaudeRequest('a', ok, log, now + 61 * 60 * 1000).ok, true, 'the hour rolls over');
});

test('the daily cap holds even when spread across hours', () => {
  const log = new CallLog();
  const start = 2_000_000_000_000;
  let allowed = 0;
  for (let h = 0; h < 24; h++) for (let i = 0; i < CLAUDE_LIMITS.perHour; i++) {
    if (guardClaudeRequest('a', ok, log, start + h * 3_600_000 + i).ok) allowed++;
  }
  assert.equal(allowed, CLAUDE_LIMITS.perDay);
});

test('only plain user/assistant text turns get through', () => {
  const bad = guardClaudeRequest('a', { messages: [{ role: 'user', content: [{ type: 'image' }] }] }, new CallLog());
  assert.equal(!bad.ok && bad.status, 400);
  const sys = guardClaudeRequest('a', { messages: [{ role: 'system', content: 'x' }] }, new CallLog());
  assert.equal(!sys.ok && sys.status, 400);
});

test('oversized input is refused and output is capped', () => {
  const big = guardClaudeRequest('a', { userMessage: 'x'.repeat(CLAUDE_LIMITS.maxInputChars + 1) }, new CallLog());
  assert.equal(!big.ok && big.status, 413);
  const capped = guardClaudeRequest('a', { userMessage: 'hi', maxTokens: 999_999 }, new CallLog());
  assert.equal(capped.ok && capped.maxTokens, CLAUDE_LIMITS.maxOutputTokens);
});
