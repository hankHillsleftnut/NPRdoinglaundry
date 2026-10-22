/**
 * Every contract's error fixtures, not only contract 00's: the backend sends
 * one message per code (contract 00's wording), so a fixture in any folder
 * that shows a contract 00 code must show that exact message. Codes a later
 * contract adds itself (e.g. 06's apple_confirmation_required) are its own.
 */
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import test from 'node:test';
import { DOOR_ERROR_CODES, DoorError, errorBody, type DoorErrorCode } from '../src/doors/errors.js';

const ROOT = join(__dirname, '..', '..', 'docs', 'team', 'contracts', 'fixtures');
const KNOWN: ReadonlySet<string> = new Set(DOOR_ERROR_CODES);

for (const folder of readdirSync(ROOT).filter((d) => /^\d{2}$/.test(d)).sort()) {
  for (const file of readdirSync(join(ROOT, folder)).filter((f) => /^error\..+\.json$/.test(f))) {
    const fixture = JSON.parse(readFileSync(join(ROOT, folder, file), 'utf8')) as {
      error: { code: string; message: string; retryAfterSeconds?: number };
    };
    if (!KNOWN.has(fixture.error.code)) continue;
    test(`${folder}/${file}: the message is the one the backend sends for ${fixture.error.code}`, () => {
      const sent = errorBody(new DoorError(fixture.error.code as DoorErrorCode, { retryAfterSeconds: fixture.error.retryAfterSeconds ?? 60 }));
      assert.equal(fixture.error.message, sent.error.message);
    });
  }
}
