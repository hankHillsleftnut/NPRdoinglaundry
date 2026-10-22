/**
 * Contract 02's brief fixtures, backend side (testing.md layer 4): every
 * `brief*.json` and `briefs.*.json` the app decodes validates against the
 * doors' zod output schemas, so a shape that drifts fails on both sides. The
 * request fixture is checked against the switch door's input schema.
 */
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import test from 'node:test';
import { z } from 'zod';
import { BriefByIdOut, BriefPageOut, EnabledOut, LatestOut, decodeCursor } from '../src/briefs/map.js';

const FIXTURES = join(__dirname, '..', '..', 'docs', 'team', 'contracts', 'fixtures', '02');
const FIXTURES_03 = join(__dirname, '..', '..', 'docs', 'team', 'contracts', 'fixtures', '03');
const read = (dir: string, file: string) => JSON.parse(readFileSync(join(dir, file), 'utf8')) as { success?: boolean; data?: unknown };

const RESPONSES: Record<string, z.ZodTypeAny> = {
  'brief.latest.v1.json': LatestOut,
  'brief.latest.v2.json': LatestOut,
  'brief.latest.quiet.json': LatestOut,
  'brief.latest.none.json': LatestOut,
  'brief.latest.off.json': LatestOut,
  'brief.latest.making.json': LatestOut,
  'briefs.list.json': BriefPageOut,
  'briefs.list.last.json': BriefPageOut,
  'briefs.enabled.response.json': EnabledOut,
};

test('every brief fixture in the folder is checked here', () => {
  const inFolder = readdirSync(FIXTURES).filter((f) => /^briefs?\./.test(f) && !f.endsWith('.request.json')).sort();
  assert.deepEqual(inFolder, Object.keys(RESPONSES).sort());
});

for (const [file, schema] of Object.entries(RESPONSES)) {
  test(`${file} is exactly what its door answers`, () => {
    const fixture = read(FIXTURES, file);
    assert.equal(fixture.success, true);
    const parsed = schema.safeParse(fixture.data);
    assert.ok(parsed.success, parsed.success ? '' : JSON.stringify(parsed.error.issues));
  });
}

test('briefs.enabled.request.json is the switch door\'s input', () => {
  const parsed = z.object({ enabled: z.boolean() }).strict().safeParse(read(FIXTURES, 'briefs.enabled.request.json'));
  assert.ok(parsed.success);
});

test('the fixtures carry what the pass fixed: nextAt, an opaque cursor, a private brief-audio link', () => {
  const v2 = read(FIXTURES, 'brief.latest.v2.json').data as { brief: { audio: { url: string; expiresAt: string }; parts: Array<{ startSeconds?: number }> }; nextAt: string | null };
  assert.match(v2.brief.audio.url, /\/storage\/v1\/object\/sign\/brief-audio\/[0-9a-f-]+\/[0-9a-f-]+\.mp3\?token=/, 'the private bucket, by user and brief, mp3');
  assert.ok(v2.brief.parts.every((p) => typeof p.startSeconds === 'number'), 'a startSeconds on every part when audio is present');
  assert.equal(typeof v2.nextAt, 'string');
  const making = read(FIXTURES, 'brief.latest.making.json').data as { brief: unknown; enabled: boolean; nextAt: string | null };
  assert.deepEqual({ brief: making.brief, enabled: making.enabled }, { brief: null, enabled: true });
  assert.match(making.nextAt!, /T08:00:00\.000Z$/, 'the next 08:00 UTC run');
  for (const f of ['brief.latest.off.json', 'brief.latest.none.json']) assert.equal((read(FIXTURES, f).data as { nextAt: unknown }).nextAt, null, f);
  const list = read(FIXTURES, 'briefs.list.json').data as { nextCursor: string; briefs: Array<{ audio?: unknown }> };
  assert.equal(decodeCursor(list.nextCursor), '2026-10-20', 'opaque base64 of the oldest date on the page');
  assert.ok(list.briefs.every((b) => b.audio === undefined), 'no audio in the list');
  // Contract 03's brief by id uses the same shape and the same bucket.
  const byId = read(FIXTURES_03, 'brief.byid.json');
  const parsed = BriefByIdOut.safeParse(byId.data);
  assert.ok(parsed.success, parsed.success ? '' : JSON.stringify(parsed.error.issues));
  assert.match((byId.data as { brief: { audio: { url: string } } }).brief.audio.url, /\/sign\/brief-audio\//);
});
