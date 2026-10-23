/**
 * Contract 06 §8 fixtures, backend side: DELETE /v2/account's request, its
 * 202 and its 409 are exactly what docs/team/contracts/fixtures/06 shows (the
 * app decodes the same files). The door runs for real; the deletion behind it
 * is a stand-in answering the fixture's id.
 */
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import test from 'node:test';
import { AccountDeleteRequest } from '../src/account/doors.js';
import type { AccountDeletion } from '../src/account/deletion.js';
import { DoorError } from '../src/doors/errors.js';
import { startHarness } from './support/harness.js';

const FIXTURES = join(__dirname, '..', '..', 'docs', 'team', 'contracts', 'fixtures', '06');
const read = (file: string) => JSON.parse(readFileSync(join(FIXTURES, file), 'utf8')) as Record<string, unknown>;
const ALICE = '11111111-1111-4111-8111-111111111111';

function standIn(answer: () => Promise<{ id: string }>): AccountDeletion & { seen: unknown[] } {
  const seen: unknown[] = [];
  return {
    seen,
    request: (input) => { seen.push(input); return answer(); },
    start: () => undefined,
    runNow: async () => 'busy',
    sweep: async () => 0,
  };
}

test('account.delete.request.json is what the door accepts, with or without the Apple code', () => {
  const fixture = read('account.delete.request.json');
  assert.deepEqual(AccountDeleteRequest.parse(fixture), fixture);
  assert.deepEqual(AccountDeleteRequest.parse({ confirm: 'delete' }), { confirm: 'delete' });
});

test('account.delete.response.json is exactly the 202 the door answers', async () => {
  const response = read('account.delete.response.json') as { data: { deletion: { id: string } } };
  const deletion = standIn(async () => ({ id: response.data.deletion.id }));
  const h = await startHarness({ account: deletion });
  try {
    const res = await h.request('DELETE', '/v2/account', read('account.delete.request.json'), { Authorization: `Bearer ${h.asUser(ALICE)}` });
    assert.equal(res.status, 202);
    assert.deepEqual(res.body, response);
    assert.deepEqual(deletion.seen, [{ userId: ALICE, appleAuthorizationCode: 'c0de.fake.0000' }], 'the user from the token, the code from the body');
  } finally {
    await h.close();
  }
});

test('error.apple_confirmation_required.json is exactly the 409 the door answers', async () => {
  const h = await startHarness({ account: standIn(async () => { throw new DoorError('apple_confirmation_required'); }) });
  try {
    const res = await h.request('DELETE', '/v2/account', { confirm: 'delete' }, { Authorization: `Bearer ${h.asUser(ALICE)}` });
    assert.equal(res.status, 409);
    assert.deepEqual(res.body, read('error.apple_confirmation_required.json'));
  } finally {
    await h.close();
  }
});

test('without a deletion service the door fails closed, never a 404 or a 202', async () => {
  const h = await startHarness();
  try {
    const res = await h.request('DELETE', '/v2/account', { confirm: 'delete' }, { Authorization: `Bearer ${h.asUser(ALICE)}` });
    assert.equal(res.status, 500);
    assert.equal((res.body as { error: { code: string } }).error.code, 'internal');
  } finally {
    await h.close();
  }
});
