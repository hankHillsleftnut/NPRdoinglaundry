/**
 * Contract 00 fixtures, backend side (testing.md layer 4): the app decodes the
 * same files, so the backend's errors must be exactly what they say.
 */
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import test from 'node:test';
import { DOOR_ERROR_CODES, DoorError, errorBody, type DoorErrorCode } from '../src/doors/errors.js';

const FIXTURES = join(__dirname, '..', '..', 'docs', 'team', 'contracts', 'fixtures', '00');
const read = (file: string) => JSON.parse(readFileSync(join(FIXTURES, file), 'utf8')) as {
  success: false; error: { code: DoorErrorCode; message: string; retryAfterSeconds?: number };
};
const errorFixtures = readdirSync(FIXTURES).filter((f) => /^error\..+\.json$/.test(f));

test('every error code has a fixture, and every fixture is a code', () => {
  const fromFixtures = errorFixtures.map((f) => f.slice('error.'.length, -'.json'.length)).sort();
  assert.deepEqual([...DOOR_ERROR_CODES].sort(), fromFixtures);
});

for (const file of errorFixtures) {
  test(`${file}: the backend sends exactly this envelope`, () => {
    const fixture = read(file);
    const sent = errorBody(new DoorError(fixture.error.code, { retryAfterSeconds: fixture.error.retryAfterSeconds ?? 60 }));
    assert.deepEqual(sent, fixture);
  });
}
