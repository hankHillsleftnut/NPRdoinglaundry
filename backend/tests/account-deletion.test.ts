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

test("Apple's client secret is an ES256 token for this app, signed with its key, valid five minutes", async () => {
  const { privateKey } = await generateKeyPair('ES256', { extractable: true });
  process.env.APPLE_TEAM_ID = 'TEAM123';
  process.env.APPLE_KEY_ID = 'KEY456';
  process.env.APPLE_PRIVATE_KEY = await exportPKCS8(privateKey);
  const { config } = await import('../src/utils/config.js');
  Object.assign(config.apple, { teamId: 'TEAM123', keyId: 'KEY456', privateKey: process.env.APPLE_PRIVATE_KEY });
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
