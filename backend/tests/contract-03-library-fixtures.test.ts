/**
 * BE3.x.lib: contract 03's library fixtures against the door's output schema
 * (src/podcasts/map.ts LibraryOut), so the door and the app's decoder read
 * one shape. `making` and `quiet` are checked as shapes only: this door
 * answers `upcoming: none` until BE3.3a.min. The error fixtures are the
 * failure envelope; the door's own invalid_request and unauthenticated
 * answers are the fixtures byte for byte.
 */
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import test from 'node:test';
import { LibraryOut } from '../src/podcasts/map.js';
import { DOOR_ERROR_CODES } from '../src/doors/errors.js';
import { startHarness } from './support/harness.js';

const FIXTURES = join(__dirname, '..', '..', 'docs', 'team', 'contracts', 'fixtures', '03');
const read = (name: string) => JSON.parse(readFileSync(join(FIXTURES, name), 'utf8')) as Record<string, unknown>;
const LIBRARY = ['podcasts.library.json', 'podcasts.library.empty.json', 'podcasts.library.making.json', 'podcasts.library.quiet.json', 'podcasts.library.page2.json'];

test('every library fixture is the door\'s output shape', () => {
  for (const name of LIBRARY) {
    const f = read(name);
    assert.equal(f.success, true, name);
    const parsed = LibraryOut.safeParse(f.data);
    assert.ok(parsed.success, `${name}: ${parsed.success ? '' : JSON.stringify(parsed.error.issues)}`);
    assert.deepEqual(parsed.data, f.data, `${name}: nothing dropped by the schema`);
  }
  // Every library fixture in the folder is checked here.
  assert.deepEqual(readdirSync(FIXTURES).filter((f) => f.startsWith('podcasts.library')).sort(), [...LIBRARY].sort());
});

test('the schema refuses what the contract does not allow', () => {
  const base = read('podcasts.library.json').data as Record<string, unknown>;
  assert.equal(LibraryOut.safeParse({ ...base, items: [{ kind: 'episode', episode: { id: 'x' } }] }).success, false);
  assert.equal(LibraryOut.safeParse({ ...base, script: 'words' }).success, false, 'no extra fields (strict)');
  assert.equal(LibraryOut.safeParse({ ...base, upcoming: { state: 'later' } }).success, false);
});

test('every contract 03 error fixture is a failure envelope with a known code', () => {
  const known: ReadonlySet<string> = new Set(DOOR_ERROR_CODES);
  const names = readdirSync(FIXTURES).filter((f) => /^error\..+\.json$/.test(f));
  assert.ok(names.length > 0);
  for (const name of names) {
    const f = read(name) as { success: boolean; error: { code: string; message: string; retryAfterSeconds?: number } };
    assert.equal(f.success, false, name);
    assert.ok(known.has(f.error.code), name);
    assert.equal(name, `error.${f.error.code}.json`);
    assert.ok(f.error.message.length > 0);
    assert.equal(f.error.retryAfterSeconds !== undefined, ['rate_limited', 'spend_limited'].includes(f.error.code), name);
  }
});

test('the door\'s invalid_request and unauthenticated answers are the fixtures', async () => {
  // Neither answer reaches a store: the cursor is refused before any read.
  const h = await startHarness();
  try {
    const auth = { Authorization: `Bearer ${h.asUser('11111111-1111-4111-8111-111111111111')}` };
    assert.deepEqual((await h.request('GET', '/v2/podcasts?cursor=bad!', undefined, auth)).body, read('error.invalid_request.json'));
    assert.deepEqual((await h.request('GET', '/v2/podcasts')).body, read('error.unauthenticated.json'));
  } finally {
    await h.close();
  }
});
