// node --test pipeline/tools/reports.test.mjs   (no network, no real secrets: the viewer is a fake)
import assert from 'node:assert/strict';
import { mkdtemp, readFile, readdir, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { digest, main, reproductionHint } from './reports.mjs';

const MARKER = 'ZZ-MARKER-NOTE-7731';
const fx = (name) => fileURLToPath(new URL(`./fixtures/${name}`, import.meta.url));
const FULL = fx('diagnostics.request.json');
const MINIMAL = fx('diagnostics.request.minimal.json');

const tmp = () => mkdtemp(join(tmpdir(), 'reports-test-'));
async function run(argv, env = {}, fetchImpl) {
  const out = []; const err = [];
  const code = await main({ argv, env, fetchImpl, log: (s) => out.push(s), fail: (s) => err.push(s) });
  return { code, stdout: out.join('\n'), stderr: err.join('\n') };
}
async function everyFile(dir) {
  const names = await readdir(dir);
  return Promise.all(names.map(async (n) => [n, await readFile(join(dir, n), 'utf8')]));
}
const variant = async (dir, name, patch) => {
  const raw = JSON.parse(await readFile(FULL, 'utf8'));
  const file = join(dir, name);
  await writeFile(file, JSON.stringify(patch(raw)));
  return file;
};

test('fixtures: cluster key, counts, hint, and never the note', async () => {
  const out = await tmp();
  const r = await run(['--fixture', FULL, MINIMAL, '--out', out]);
  assert.equal(r.code, 0);
  const files = await everyFile(out);
  assert.deepEqual(files.map(([n]) => n).sort(), ['none--none--1.0-42-.md', 'server--journal--1.0-42-.md']);
  const server = Object.fromEntries(files)['server--journal--1.0-42-.md'];
  assert.match(server, /# Cluster server\/journal\/1\.0\(42\)/);
  assert.match(server, /- Count: 1/);
  assert.match(server, /First seen: 2026-10-22T09:30:00.000Z/);
  assert.match(server, /00000000-0000-4000-8000-0000000000d1 \(.*has note: yes\)/);
  assert.match(server, /journal -> GET \/v2\/briefs\/latest 200 -> brief\.play -> GET \/v2\/briefs\/latest 504 -> => server/);
  assert.match(server, /control_tapped screen=journal control=brief\.play/);
  assert.match(server, /request .*GET \/v2\/briefs\/latest status=504 code=upstream_timeout/);
  const none = Object.fromEntries(files)['none--none--1.0-42-.md'];
  assert.match(none, /queued 1/);
  assert.match(none, /no breadcrumbs/);
  // privacy: the marker is in neither file nor stdout nor stderr
  for (const [, text] of files) assert.ok(!text.includes(MARKER));
  assert.ok(!r.stdout.includes(MARKER) && !r.stderr.includes(MARKER));
});

test('re-running updates nothing twice: a reference is never duplicated', async () => {
  const out = await tmp();
  await run(['--fixture', FULL, '--out', out]);
  const first = await everyFile(out);
  const again = await run(['--fixture', FULL, '--out', out]);
  assert.match(again.stdout, /0 new/);
  assert.deepEqual(await everyFile(out), first);
});

test('identical keys merge and a second report raises the count', async () => {
  const out = await tmp(); const dir = await tmp();
  const second = await variant(dir, 'second.json', (r) => ({ ...r, reportId: '00000000-0000-4000-8000-0000000000e2', createdAt: '2026-10-23T08:00:00.000Z', note: null }));
  await run(['--fixture', FULL, '--out', out]);
  const r = await run(['--fixture', second, '--out', out]);
  assert.match(r.stdout, /1 new/);
  const text = await readFile(join(out, 'server--journal--1.0-42-.md'), 'utf8');
  assert.match(text, /- Count: 2/);
  assert.match(text, /Last seen: 2026-10-23T08:00:00.000Z/);
  assert.match(text, /has note: yes/);
  assert.match(text, /has note: no/);
});

test('a crash newer than the last failure keys as crash; an older one does not', async () => {
  const dir = await tmp();
  const newer = await variant(dir, 'a.json', (r) => ({ ...r, crashes: [{ t: '2026-10-22T09:25:00.000Z', kind: 'crash' }] }));
  const older = await variant(dir, 'b.json', (r) => ({ ...r, crashes: [{ t: '2026-10-22T09:00:00.000Z', kind: 'hang' }] }));
  assert.equal(digest(JSON.parse(await readFile(newer, 'utf8')), 'x').key, 'crash/journal/1.0(42)');
  assert.equal(digest(JSON.parse(await readFile(older, 'utf8')), 'x').key, 'server/journal/1.0(42)');
});

test('with no failure the key uses the screen the report came from', async () => {
  const dir = await tmp();
  const f = await variant(dir, 'c.json', (r) => ({ ...r, failures: [] }));
  assert.equal(digest(JSON.parse(await readFile(f, 'utf8')), 'x').key, 'none/journal/1.0(42)');
});

test('the hint reads like the example: screen, offline, request, control', () => {
  const d = digest({
    environment: { appVersion: '1.0', build: '1', network: 'none' },
    events: [
      { t: '2026-10-22T09:00:00.000Z', kind: 'screen_shown', screen: 'journal' },
      { t: '2026-10-22T09:00:03.000Z', kind: 'control_tapped', screen: 'journal', control: 'report.send' },
    ],
    network: [{ t: '2026-10-22T09:00:02.000Z', method: 'POST', route: '/v2/entries', status: 0 }],
    failures: [], crashes: [], note: null,
  }, 'r-7KQ2');
  assert.equal(reproductionHint(d), 'journal -> offline -> POST /v2/entries 0 -> report.send');
});

test('only 50 breadcrumbs are kept, the newest ones', () => {
  const events = Array.from({ length: 80 }, (_, i) => ({ t: `2026-10-22T09:${String(Math.floor(i / 60)).padStart(2, '0')}:${String(i % 60).padStart(2, '0')}.000Z`, kind: 'app_foreground' }));
  const d = digest({ events, network: [] }, 'r-7KQ2');
  assert.equal(d.breadcrumbs.length, 50);
  assert.equal(d.breadcrumbs[49].t, events[79].t);
});

test('free text in a field never reaches a file', async () => {
  const out = await tmp(); const dir = await tmp();
  const bad = await variant(dir, 'd.json', (r) => ({ ...r, events: [{ t: '2026-10-22T09:20:01.000Z', kind: 'screen_shown', screen: 'my diary says hello' }], failures: [{ t: '2026-10-22T09:22:10.000Z', code: 'secret words here', screen: 'journal' }] }));
  await run(['--fixture', bad, '--out', out]);
  for (const [, text] of await everyFile(out)) assert.ok(!/diary|secret words/.test(text));
});

test('live: only two GET calls, secret and address stay out of output, filter by --since', async () => {
  const out = await tmp();
  const SECRET = 'fake-secret-for-test-only';
  const BASE = 'https://fake-api.test';
  const full = JSON.parse(await readFile(FULL, 'utf8'));
  const calls = [];
  const fetchImpl = async (url, init) => {
    calls.push({ url, method: init.method, secret: init.headers['x-admin-secret'] });
    const body = (data) => ({ ok: true, status: 200, json: async () => data });
    if (url === `${BASE}/admin/diagnostics?limit=500`) {
      return body({ success: true, data: [
        { reference: 'r-7KQ2', createdAt: '2026-10-22T09:30:00.000Z' },
        { reference: 'r-OLD1', createdAt: '2026-09-01T09:30:00.000Z' },
        { reference: 'not-a-reference', createdAt: '2026-10-22T09:30:00.000Z' },
      ] });
    }
    if (url === `${BASE}/admin/diagnostics/r-7KQ2/download`) return body(full);
    throw new Error(`unexpected call ${url}`);
  };
  const r = await run(['--since', '2026-10-01T00:00:00Z', '--out', out], { RETRO_API_BASE: `${BASE}/`, ADMIN_SECRET: SECRET }, fetchImpl);
  assert.equal(r.code, 0, r.stderr);
  assert.deepEqual(calls.map((c) => [c.method, c.url]), [
    ['GET', `${BASE}/admin/diagnostics?limit=500`],
    ['GET', `${BASE}/admin/diagnostics/r-7KQ2/download`],
  ]);
  assert.ok(calls.every((c) => c.secret === SECRET));
  const text = await readFile(join(out, 'server--journal--1.0-42-.md'), 'utf8');
  assert.match(text, /r-7KQ2/);
  assert.ok(!text.includes('r-OLD1'));
  for (const s of [r.stdout, r.stderr, text]) assert.ok(!s.includes(SECRET) && !s.includes('fake-api.test') && !s.includes(MARKER));
});

test('live: failures never print the secret or the address', async () => {
  const out = await tmp();
  const env = { RETRO_API_BASE: 'https://fake-api.test', ADMIN_SECRET: 'fake-secret-for-test-only' };
  const down = await run(['--since', '2026-10-01T00:00:00Z', '--out', out], env, async () => { throw new Error('connect ECONNREFUSED fake-api.test fake-secret-for-test-only'); });
  assert.equal(down.code, 1);
  const denied = await run(['--since', '2026-10-01T00:00:00Z', '--out', out], env, async () => ({ ok: false, status: 401, json: async () => ({}) }));
  assert.equal(denied.code, 1);
  assert.match(denied.stderr, /answered 401/);
  for (const s of [down.stderr, denied.stderr]) assert.ok(!s.includes('fake-secret') && !s.includes('fake-api'));
  assert.deepEqual(await readdir(out), []);
});

test('live: refuses to run without the environment or without --since', async () => {
  const noEnv = await run(['--since', '2026-10-01T00:00:00Z'], {}, async () => { throw new Error('must not be called'); });
  assert.equal(noEnv.code, 1);
  assert.match(noEnv.stderr, /RETRO_API_BASE and ADMIN_SECRET/);
  const noSince = await run([], { RETRO_API_BASE: 'https://x.test', ADMIN_SECRET: 's' }, async () => { throw new Error('must not be called'); });
  assert.equal(noSince.code, 1);
});
