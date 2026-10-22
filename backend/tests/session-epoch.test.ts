import { test } from 'node:test';
import assert from 'node:assert/strict';
import jwt from 'jsonwebtoken';

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

test('issuing a token fails on an epoch read error, even if data was returned', async (t) => {
  const { issueToken } = await import('../src/middleware/auth.js');
  const { supabaseAdmin } = await import('../src/utils/supabase.js');
  const sign = t.mock.method(jwt, 'sign', () => { throw new Error('must not sign'); });
  for (const data of [null, { session_epoch: 4 }]) {
    const query = {
      select() { return this; },
      eq() { return this; },
      async single() { return { data, error: { message: 'db unavailable' } }; },
    };
    const from = t.mock.method(supabaseAdmin, 'from', () => query);
    await assert.rejects(issueToken({ id: 'u1' }), /Could not read session epoch: db unavailable/);
    from.mock.restore();
  }
  assert.equal(sign.mock.callCount(), 0);
});

test('issued tokens retain the current epoch and legacy epoch-zero default', async (t) => {
  const { issueToken, sessionStillValid } = await import('../src/middleware/auth.js');
  const { supabaseAdmin } = await import('../src/utils/supabase.js');
  const { config } = await import('../src/utils/config.js');
  for (const session_epoch of [4, null]) {
    const query = {
      select() { return this; },
      eq() { return this; },
      async single() { return { data: { session_epoch }, error: null }; },
    };
    const from = t.mock.method(supabaseAdmin, 'from', () => query);
    const payload = jwt.verify(await issueToken({ id: 'u1' }), config.jwt.secret) as jwt.JwtPayload & { se?: number };
    assert.equal(payload.userId, 'u1');
    assert.equal(payload.se, session_epoch ?? 0);
    assert.equal(sessionStillValid(payload, { session_epoch }), true);
    from.mock.restore();
  }
});
