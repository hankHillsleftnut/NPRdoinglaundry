/**
 * Contract 02 fixtures, backend side (testing.md layer 4): every entry
 * fixture validates against the doors' zod schemas, and every request fixture
 * against the request schema. The app decodes the same files.
 */
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import test from 'node:test';
import { z } from 'zod';
import { Entry, EntryCreateBody, EntryResponse, TodayResponse } from '../src/entries/doors.js';

const FIXTURES = join(__dirname, '..', '..', 'docs', 'team', 'contracts', 'fixtures', '02');
const read = (file: string) => JSON.parse(readFileSync(join(FIXTURES, file), 'utf8')) as unknown;
const envelope = (file: string) => {
  const body = read(file) as { success: boolean; data: unknown };
  assert.equal(body.success, true, `${file} is a success envelope`);
  return body.data;
};

/** Schemas BE1.5 and BE1.5b will answer with; their fixtures already exist, so they are held to the Entry shape now. */
const ListResponse = z.object({ entries: z.array(Entry), nextCursor: z.string().nullable() }).strict();
const DeleteResponse = z.object({ deleted: z.literal(true) }).strict();
const EditBody = z.object({ text: z.string().min(1) }).strict();

const responses: Record<string, z.ZodTypeAny> = {
  'entry.create.response.json': EntryResponse,
  'entry.create.response.minimal.json': EntryResponse,
  'entries.today.json': TodayResponse,
  'entries.today.empty.json': TodayResponse,
  'entries.list.json': ListResponse,
  'entries.list.last.json': ListResponse,
  'entries.search.json': ListResponse,
  'entries.search.empty.json': ListResponse,
  'entry.json': EntryResponse,
  'entry.edit.response.json': EntryResponse,
  'entry.delete.json': DeleteResponse,
};
const requests: Record<string, z.ZodTypeAny> = {
  'entry.create.request.json': EntryCreateBody,
  'entry.create.request.voice.json': EntryCreateBody,
  'entry.edit.request.json': EditBody,
};

test('every entry fixture in fixtures/02 is mapped here', () => {
  const files = readdirSync(FIXTURES).filter((f) => /^entr/.test(f)).sort();
  assert.deepEqual(files, [...Object.keys(responses), ...Object.keys(requests)].sort());
});

for (const [file, schema] of Object.entries(responses)) {
  test(`${file} validates against the door's output schema`, () => {
    assert.doesNotThrow(() => schema.parse(envelope(file)));
  });
}

for (const [file, schema] of Object.entries(requests)) {
  test(`${file} validates against the door's request schema`, () => {
    assert.doesNotThrow(() => schema.parse(read(file)));
  });
}

test('today is oldest first and the list newest first (contract 02 §8)', () => {
  const today = TodayResponse.parse(envelope('entries.today.json'));
  const times = today.entries.map((e) => Date.parse(e.createdAt));
  assert.deepEqual(times, [...times].sort((a, b) => a - b));
  assert.ok(today.entries.every((e) => e.day === today.date));
  const list = ListResponse.parse(envelope('entries.list.json'));
  const listed = list.entries.map((e) => Date.parse(e.createdAt));
  assert.deepEqual(listed, [...listed].sort((a, b) => b - a));
});
