/**
 * Contract 02's guess fixtures, backend side (testing.md layer 4): every
 * `guess*.json` the app decodes validates against the guess doors' zod
 * output schemas; the request fixture against the answer door's body.
 */
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import test from 'node:test';
import { z } from 'zod';
import { AnswerOut, GuessOut, GuessesOut } from '../src/guesses/map.js';

const FIXTURES = join(__dirname, '..', '..', 'docs', 'team', 'contracts', 'fixtures', '02');
const read = (file: string) => JSON.parse(readFileSync(join(FIXTURES, file), 'utf8')) as { success?: boolean; data?: unknown };

const RESPONSES: Record<string, z.ZodTypeAny> = {
  'guesses.json': GuessesOut,
  'guesses.minimal.json': GuessesOut,
  'guesses.silent.json': GuessesOut,
  'guess.answer.json': AnswerOut,
  'guess.answer.declined.json': AnswerOut,
  'guess.answer.expired.json': AnswerOut,
  'guess.why.json': GuessOut,
};

test('every guess fixture in the folder is checked here', () => {
  const inFolder = readdirSync(FIXTURES).filter((f) => /^guess(es)?\./.test(f) && !f.endsWith('.request.json')).sort();
  assert.deepEqual(inFolder, Object.keys(RESPONSES).sort());
});

for (const [file, schema] of Object.entries(RESPONSES)) {
  test(`${file} is exactly what its door answers`, () => {
    const fixture = read(file);
    assert.equal(fixture.success, true);
    const parsed = schema.safeParse(fixture.data);
    assert.ok(parsed.success, parsed.success ? '' : JSON.stringify(parsed.error.issues));
  });
}

test('guess.answer.request.json is the answer door\'s body', () => {
  assert.ok(z.object({ verdict: z.enum(['yes', 'no']) }).strict().safeParse(read('guess.answer.request.json')).success);
});

test('the silent fixture is the dial off: no guesses', () => {
  assert.deepEqual(read('guesses.silent.json').data, { guesses: [], speaking: false });
  assert.deepEqual(read('guess.answer.expired.json').data, { status: 'expired' });
});
