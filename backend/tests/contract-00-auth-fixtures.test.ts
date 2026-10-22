/** Contract 00 §3 fixtures, backend side (testing.md layer 4). */
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import test from 'node:test';
import { AppleBody, AuthResponse, RefreshBody } from '../src/sessions/routes.js';

const FIXTURES = join(__dirname, '..', '..', 'docs', 'team', 'contracts', 'fixtures', '00');
const read = (file: string) => JSON.parse(readFileSync(join(FIXTURES, file), 'utf8')) as unknown;

test('the sign-in request fixtures are accepted as sent', () => {
  for (const file of ['auth-apple.request.json', 'auth-apple.request.minimal.json']) {
    assert.equal(AppleBody.safeParse(read(file)).success, true, file);
  }
});

test('the sign-in and refresh response fixtures match the answer the backend builds', () => {
  for (const file of ['auth.response.json', 'auth.response.waitlisted.json']) {
    const body = read(file) as { success: boolean; data: unknown };
    assert.equal(body.success, true, file);
    assert.equal(AuthResponse.safeParse(body.data).success, true, file);
  }
});

test('the refresh request fixture is accepted as sent', () => {
  assert.equal(RefreshBody.safeParse(read('refresh.request.json')).success, true);
});
