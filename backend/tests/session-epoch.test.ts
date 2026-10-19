import { test } from 'node:test';
import assert from 'node:assert/strict';

process.env.AGENT_SERVICE_URL ??= 'http://localhost';
process.env.ANTHROPIC_API_KEY ??= 'test';
process.env.INTERNAL_API_SECRET ??= 'test';
process.env.JWT_SECRET ??= 'test';
process.env.OPENAI_API_KEY ??= 'test';
process.env.SUPABASE_ANON_KEY ??= 'test';
process.env.SUPABASE_SERVICE_KEY ??= 'test';
process.env.SUPABASE_URL ??= 'http://localhost';

/** "Sign out everywhere" bumps the account's epoch; older tokens stop working. */

test('a token issued under the current epoch is valid', async () => {
  const { sessionStillValid } = await import('../src/middleware/auth.js');
  assert.equal(sessionStillValid({ se: 2 }, { session_epoch: 2 }), true);
});

test('after sign out everywhere, every older token is refused', async () => {
  const { sessionStillValid } = await import('../src/middleware/auth.js');
  assert.equal(sessionStillValid({ se: 1 }, { session_epoch: 2 }), false);
});

test('tokens from before this existed count as epoch 0, so nobody is signed out by the upgrade', async () => {
  const { sessionStillValid } = await import('../src/middleware/auth.js');
  assert.equal(sessionStillValid({}, { session_epoch: 0 }), true);
  assert.equal(sessionStillValid({}, { session_epoch: null }), true);
  assert.equal(sessionStillValid({}, { session_epoch: 1 }), false);
});
