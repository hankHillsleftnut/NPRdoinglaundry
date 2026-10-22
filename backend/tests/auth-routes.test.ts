import assert from 'node:assert/strict';
import type { AddressInfo } from 'node:net';
import test from 'node:test';
import express from 'express';
import type { AuthUser } from '../src/types/index.js';

// The route module reads config at import, so env is set before importing it
// (dynamic import below); these placeholders are never real keys.
for (const key of ['SUPABASE_URL', 'SUPABASE_SERVICE_KEY', 'SUPABASE_ANON_KEY', 'ANTHROPIC_API_KEY', 'OPENAI_API_KEY',
  'JWT_SECRET', 'AGENT_SERVICE_URL', 'INTERNAL_API_SECRET']) {
  process.env[key] ??= key.endsWith('_URL') ? 'http://127.0.0.1:9' : 'test-only-not-a-key';
}

/** What jose throws for an expired token (its code is what the route reads). */
const jwtExpired = () => Object.assign(new Error('"exp" claim timestamp check failed'), { code: 'ERR_JWT_EXPIRED' });

async function startAuth(verify: (token: string) => Promise<{ appleUserId: string; email?: string }>) {
  const { createAuthRouter } = await import('../src/routes/auth.js');
  const created: string[] = [];
  const app = express();
  app.use(express.json());
  app.use('/auth', createAuthRouter({
    verifyAppleIdentityToken: verify,
    getOrCreateUser: async (appleUserId: string): Promise<AuthUser> => { created.push(appleUserId); return { id: 'user-1', appleUserId }; },
    generateToken: () => 'test-token',
    isProduction: true,
  }));
  const server = app.listen(0, '127.0.0.1');
  await new Promise<void>((resolve) => server.once('listening', () => resolve()));
  const { port } = server.address() as AddressInfo;
  const post = async (path: string, body: unknown) => {
    const res = await fetch(`http://127.0.0.1:${port}${path}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
    });
    return { status: res.status, body: await res.json() };
  };
  return { post, created, close: () => new Promise<void>((resolve) => server.close(() => resolve())) };
}

const SIGN_IN = { appleUserId: 'apple-1', identityToken: 'test-identity-token' };
const quietErrors = async <T>(fn: () => Promise<T>): Promise<T> => {
  const error = console.error;
  console.error = () => undefined;
  try { return await fn(); } finally { console.error = error; }
};

// BE0.0 (backend-reference §0 finding 6), the card's test: inject a verifier that throws JWTExpired.
test('an expired Apple identity token is a 401 on /auth/signin and /auth/refresh, not a 500', async () => {
  const auth = await startAuth(async () => { throw jwtExpired(); });
  try {
    for (const path of ['/auth/signin', '/auth/refresh']) {
      const res = await auth.post(path, SIGN_IN);
      assert.equal(res.status, 401, path);
      assert.deepEqual(res.body, { success: false, error: 'Invalid Apple identity token' }, path);
    }
    assert.equal(auth.created.length, 0, 'no user is looked up or made');
  } finally {
    await auth.close();
  }
});

test('failing to reach Apple is still a 500 with the generic message', async () => {
  const auth = await startAuth(async () => { throw new Error('fetch failed'); });
  try {
    const res = await quietErrors(() => auth.post('/auth/signin', SIGN_IN));
    assert.equal(res.status, 500);
    assert.deepEqual(res.body, { success: false, error: 'Failed to sign in' });
  } finally {
    await auth.close();
  }
});

test('a valid token still signs in, and the response shape is unchanged', async () => {
  const auth = await startAuth(async () => ({ appleUserId: 'apple-1' }));
  try {
    const res = await auth.post('/auth/signin', SIGN_IN);
    assert.equal(res.status, 200);
    assert.deepEqual(res.body, { success: true, data: { token: 'test-token', user: { id: 'user-1' } } });
  } finally {
    await auth.close();
  }
});
