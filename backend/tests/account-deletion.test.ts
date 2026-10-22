import { test } from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPair, exportPKCS8, decodeJwt, decodeProtectedHeader } from 'jose';

process.env.AGENT_SERVICE_URL ??= 'http://localhost';
process.env.ANTHROPIC_API_KEY ??= 'test';
process.env.INTERNAL_API_SECRET ??= 'test';
process.env.JWT_SECRET ??= 'test';
process.env.OPENAI_API_KEY ??= 'test';
process.env.SUPABASE_ANON_KEY ??= 'test';
process.env.SUPABASE_SERVICE_KEY ??= 'test';
process.env.SUPABASE_URL ??= 'http://localhost';

/** Delete my account: revoke first, files next, the account row last; revocation never blocks deletion. */

function recorder(overrides: Partial<Record<string, () => Promise<unknown>>> = {}) {
  const calls: string[] = [];
  const deps = {
    revokeGoogle: async () => { calls.push('google'); return overrides.google ? (await overrides.google()) as boolean : true; },
    revokeApple: async () => { calls.push('apple'); return overrides.apple ? (await overrides.apple()) as boolean : true; },
    removeStoredFiles: async () => { calls.push('files'); return overrides.files ? (await overrides.files()) as number : 3; },
    deleteUserRow: async () => { calls.push('row'); if (overrides.row) await overrides.row(); },
  };
  return { calls, deps };
}

async function configureAppleSigningKey() {
  const { privateKey } = await generateKeyPair('ES256', { extractable: true });
  const { config } = await import('../src/utils/config.js');
  Object.assign(config.apple, { teamId: 'TEAM123', keyId: 'KEY456', privateKey: await exportPKCS8(privateKey) });
  return config;
}

test('everything is revoked and removed, and the account row goes last', async () => {
  const { deleteAccount } = await import('../src/services/account-deletion.js');
  const { calls, deps } = recorder();
  const r = await deleteAccount('u1', { appleAuthorizationCode: 'code' }, deps);
  assert.deepEqual(calls, ['google', 'apple', 'files', 'row']);
  assert.deepEqual({ g: r.googleRevoked, a: r.appleRevoked, f: r.filesRemoved }, { g: true, a: true, f: 3 });
});

test("a revocation failing does not keep data the person asked us to delete", async () => {
  const { deleteAccount } = await import('../src/services/account-deletion.js');
  const { calls, deps } = recorder({
    google: async () => { throw new Error('agent down'); },
    apple: async () => { throw new Error('apple down'); },
  });
  const r = await deleteAccount('u1', { appleAuthorizationCode: 'code' }, deps);
  assert.ok(calls.includes('row'), 'the account was still deleted');
  assert.equal(r.googleRevoked, false);
  assert.equal(r.appleRevoked, false);
  assert.equal(r.notes.length, 2);
});

test('without an Apple code, Apple is not attempted and says so', async () => {
  const { deleteAccount } = await import('../src/services/account-deletion.js');
  const { calls, deps } = recorder();
  const r = await deleteAccount('u1', {}, deps);
  assert.equal(calls.includes('apple'), false);
  assert.equal(r.appleRevoked, 'not_requested');
});

test('if the account row cannot be deleted, the request fails rather than claiming success', async () => {
  const { deleteAccount } = await import('../src/services/account-deletion.js');
  const { deps } = recorder({ row: async () => { throw new Error('db down'); } });
  await assert.rejects(deleteAccount('u1', {}, deps), /db down/);
});

test('storage failure keeps the account row so cleanup can be retried', async () => {
  const { deleteAccount } = await import('../src/services/account-deletion.js');
  let storageAvailable = false;
  const { calls, deps } = recorder({ files: async () => {
    if (!storageAvailable) throw new Error('storage down');
    return 3;
  } });
  await assert.rejects(deleteAccount('u1', {}, deps), /storage down/);
  assert.deepEqual(calls, ['google', 'files']);
  storageAvailable = true;
  const result = await deleteAccount('u1', {}, deps);
  assert.equal(result.deleted, true);
  assert.deepEqual(calls, ['google', 'files', 'google', 'files', 'row']);
});

test("Apple's client secret is an ES256 token for this app, signed with its key, valid five minutes", async () => {
  const config = await configureAppleSigningKey();
  const { appleClientSecret } = await import('../src/services/account-deletion.js');
  const jwt = await appleClientSecret(new Date('2026-10-19T22:00:00Z'));
  const header = decodeProtectedHeader(jwt);
  const claims = decodeJwt(jwt);
  assert.equal(header.alg, 'ES256');
  assert.equal(header.kid, 'KEY456');
  assert.equal(claims.iss, 'TEAM123');
  assert.equal(claims.sub, config.apple.clientId);
  assert.equal(claims.aud, 'https://appleid.apple.com');
  assert.equal((claims.exp ?? 0) - (claims.iat ?? 0), 300);
});

for (const stalledStep of ['exchange', 'body', 'revoke'] as const) {
  test(`Apple ${stalledStep} deadline aborts the request and deletion still completes`, async (t) => {
    await configureAppleSigningKey();
    const { revokeAppleAuthorization, deleteAccount } = await import('../src/services/account-deletion.js');
    const signals: AbortSignal[] = [];
    const timers: ReturnType<typeof setTimeout>[] = [];
    t.after(() => timers.forEach(clearTimeout));
    t.mock.method(AbortSignal, 'timeout', (ms: number) => {
      assert.equal(ms, 10_000);
      const controller = new AbortController();
      timers.push(setTimeout(() => controller.abort(new DOMException('Deadline exceeded', 'TimeoutError')), 5));
      return controller.signal;
    });
    const stalled = (signal: AbortSignal) => new Promise<never>((_resolve, reject) => {
      signal.addEventListener('abort', () => reject(signal.reason), { once: true });
    });
    const fetchImpl: typeof fetch = async (url, init) => {
      const signal = init?.signal;
      assert.ok(signal instanceof AbortSignal);
      signals.push(signal);
      if (String(url).endsWith('/token')) {
        if (stalledStep === 'exchange') return stalled(signal);
        if (stalledStep === 'body') {
          return { json: () => stalled(signal) } as unknown as Response;
        }
        return new Response(JSON.stringify({ refresh_token: 'synthetic-refresh' }));
      }
      assert.match(String(url), /\/revoke$/);
      return stalled(signal);
    };
    const { calls, deps } = recorder({ apple: () => revokeAppleAuthorization('synthetic-code', fetchImpl) });
    const result = await deleteAccount('u1', { appleAuthorizationCode: 'synthetic-code' }, deps);
    assert.equal(result.deleted, true);
    assert.equal(result.appleRevoked, false);
    assert.match(result.notes[0]!, /Deadline exceeded/);
    assert.deepEqual(calls, ['google', 'apple', 'files', 'row']);
    assert.equal(signals.length, stalledStep === 'revoke' ? 2 : 1);
    assert.equal(signals.at(-1)!.aborted, true);
    if (signals.length === 2) assert.notEqual(signals[0], signals[1]);
  });
}

test('Apple code exchange and revocation preserve their form fields and HTTP errors', async () => {
  await configureAppleSigningKey();
  const { revokeAppleAuthorization } = await import('../src/services/account-deletion.js');
  for (const failure of [undefined, 'token', 'revoke']) {
    const paths: string[] = [];
    const fetchImpl: typeof fetch = async (url, init) => {
      const path = new URL(String(url)).pathname.split('/').at(-1)!;
      paths.push(path);
      assert.equal(init?.method, 'POST');
      assert.ok(init?.body instanceof URLSearchParams);
      if (path === 'token') {
        assert.equal(init.body.get('code'), 'synthetic-code');
        assert.equal(init.body.get('grant_type'), 'authorization_code');
      } else {
        assert.equal(init.body.get('token'), 'synthetic-refresh');
        assert.equal(init.body.get('token_type_hint'), 'refresh_token');
      }
      return new Response(JSON.stringify({ refresh_token: 'synthetic-refresh' }), { status: failure === path ? 400 : 200 });
    };
    const result = revokeAppleAuthorization('synthetic-code', fetchImpl);
    if (failure) await assert.rejects(result, failure === 'token' ? /code exchange failed \(400\)/ : /revoke failed \(400\)/);
    else assert.equal(await result, true);
    assert.deepEqual(paths, failure === 'token' ? ['token'] : ['token', 'revoke']);
  }
});
