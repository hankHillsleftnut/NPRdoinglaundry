/**
 * BE3.x.ep: contract 03's episode fixtures against the door's output schema
 * (src/podcasts/episode-map.ts EpisodeOut), so the door and the app's decoder
 * read one shape; the legacy fixture is also rebuilt from a row by the door's
 * own mapping. Contract 01 §6 (first-run) reads the same door: its fixtures
 * name the transcript `transcript`, where contract 03 (which "defines it
 * fully") says `lines`; the fields first-run reads are checked here and the
 * name is a QUESTION for the integrator, not a second shape.
 */
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import test from 'node:test';
import { EpisodeByIdOut, EpisodeOut, episodeResponse } from '../src/podcasts/episode-map.js';
import type { EpisodeDetailRow } from '../src/podcasts/store.js';
import { startHarness } from './support/harness.js';

const ROOT = join(__dirname, '..', '..', 'docs', 'team', 'contracts', 'fixtures');
const read = (folder: string, name: string) => JSON.parse(readFileSync(join(ROOT, folder, name), 'utf8')) as Record<string, unknown>;
const EPISODES = ['episode.legacy.json', 'episode.noaudio.json', 'episode.v2.json'];

test('every contract 03 episode fixture is the door\'s output shape', () => {
  for (const name of EPISODES) {
    const f = read('03', name);
    assert.equal(f.success, true, name);
    const parsed = EpisodeByIdOut.safeParse(f.data);
    assert.ok(parsed.success, `${name}: ${parsed.success ? '' : JSON.stringify(parsed.error.issues)}`);
    assert.deepEqual(parsed.data, f.data, `${name}: nothing dropped by the schema`);
  }
  assert.deepEqual(readdirSync(join(ROOT, '03')).filter((f) => f.startsWith('episode.')).sort(), [...EPISODES].sort());
});

test('the legacy fixture is what the door makes from a legacy row', () => {
  const want = (read('03', 'episode.legacy.json').data as { episode: Record<string, unknown> }).episode;
  const row: EpisodeDetailRow = {
    id: want.id as string, title: want.title as string, generationType: 'weekly', episodeNumber: 1, durationSeconds: 131,
    createdAt: want.createdAt as string, createdKey: want.createdAt as string, coversFrom: '2026-08-23', coversTo: '2026-09-20', hasAudio: true,
    script: 'This is the first week, so everything here is narrow.\n\nHere\'s the first thing I noticed.', description: 'unused while there are lines',
  };
  const audio = want.audio as { url: string; expiresAt: string };
  const { episode } = episodeResponse(row, { url: audio.url, expiresAt: audio.expiresAt });
  // `first` needs the brain's generation type (BE2.5a: every row says 'weekly' today).
  assert.deepEqual({ ...episode, kind: 'first' }, want);
});

test('the schema refuses what the contract does not allow', () => {
  const base = (read('03', 'episode.legacy.json').data as { episode: Record<string, unknown> }).episode;
  assert.equal(EpisodeOut.safeParse({ ...base, script: 'words' }).success, false, 'no extra fields (strict)');
  assert.equal(EpisodeOut.safeParse({ ...base, outline: {} }).success, false);
  assert.equal(EpisodeOut.safeParse({ ...base, lines: [{ index: 0, text: 'x', chapterIndex: -1, register: 'spoken' }] }).success, false);
  assert.equal(EpisodeOut.safeParse({ ...base, audio: { url: 'https://x.test/a', expiresAt: 'soon', durationSeconds: 1, mimeType: 'audio/mpeg' } }).success, false);
});

test('contract 01 first-run fixtures: the fields first-run reads have the door\'s types', () => {
  for (const name of ['episode.first.json', 'episode.first.minimal.json']) {
    const e = (read('01', name).data as { episode: Record<string, unknown> }).episode;
    const pick = EpisodeOut.pick({ id: true, kind: true, title: true, durationSeconds: true, createdAt: true });
    assert.ok(pick.safeParse({ id: e.id, kind: e.kind, title: e.title, durationSeconds: e.durationSeconds, createdAt: e.createdAt }).success, name);
    const audio = e.audio as { url: unknown; expiresAt: unknown };
    assert.ok(EpisodeOut.shape.audio.unwrap().pick({ url: true, expiresAt: true }).safeParse(audio).success, name);
    assert.ok(Array.isArray(e.chapters), name);
    // The one difference: contract 01 says `transcript`, contract 03 `lines` (QUESTION @integrator).
    assert.ok('transcript' in e && !('lines' in e), name);
  }
});

test('the door\'s not_found and invalid_request answers are the fixtures', async () => {
  const h = await startHarness({ podcasts: { library: () => Promise.resolve([]), episode: () => Promise.resolve(null) } });
  try {
    const auth = { Authorization: `Bearer ${h.asUser('11111111-1111-4111-8111-111111111111')}` };
    assert.deepEqual((await h.request('GET', '/v2/episodes/00000000-0000-4000-8000-000000000401', undefined, auth)).body, read('03', 'error.not_found.json'));
    assert.deepEqual((await h.request('GET', '/v2/episodes/nope', undefined, auth)).body, read('03', 'error.invalid_request.json'));
  } finally {
    await h.close();
  }
});
