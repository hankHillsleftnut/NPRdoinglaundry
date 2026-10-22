/**
 * DG.1: POST /v2/diagnostics over HTTP on the real app (harness), with the
 * table and bucket in memory, and the door suite.
 */
import assert from 'node:assert/strict';
import { gzipSync } from 'node:zlib';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import test from 'node:test';
import { DiagnosticsReport } from '../src/diagnostics/schema.js';
import { createDiagnosticsStore, newReference, REPORT_TTL_DAYS } from '../src/diagnostics/store.js';
import { doorSuite } from './support/door-suite.js';
import { startHarness } from './support/harness.js';
import { memoryDiagnostics } from './support/memory-diagnostics.js';

const FIXTURES = join(__dirname, '..', '..', 'docs', 'team', 'contracts', 'fixtures', '00');
const fixture = (name: string) => JSON.parse(readFileSync(join(FIXTURES, name), 'utf8')) as Record<string, unknown>;
const ALICE = '11111111-1111-4111-8111-111111111111';
const BOB = '22222222-2222-4222-8222-222222222222';
const WORDS = 'went for a walk with sam and talked about the move';

/** Deterministic references: r-0000, r-0001, … */
function counterPick() {
  let n = 0;
  return () => (n++ % 4 === 3 ? Math.floor(n / 4) % 32 : 0);
}

async function harness() {
  const mem = memoryDiagnostics();
  const store = createDiagnosticsStore(mem.backend, counterPick());
  const h = await startHarness({ diagnostics: store });
  const send = (user: string, body: unknown, headers: Record<string, string> = {}) =>
    h.request('POST', '/v2/diagnostics', body, { Authorization: `Bearer ${h.asUser(user)}`, ...headers });
  return { h, mem, store, send };
}

const report = (over: Record<string, unknown> = {}) => ({ ...fixture('diagnostics.request.json'), ...over });
const code = (body: unknown) => (body as { error?: { code?: string } }).error?.code;

test('the request fixtures are valid reports, and the response fixture is the answer', async () => {
  assert.equal(DiagnosticsReport.safeParse(fixture('diagnostics.request.json')).success, true);
  assert.equal(DiagnosticsReport.safeParse(fixture('diagnostics.request.minimal.json')).success, true);
  const { h, send } = await harness();
  try {
    const res = await send(ALICE, fixture('diagnostics.request.json'));
    assert.equal(res.status, 200);
    assert.match((res.body as { data: { reference: string } }).data.reference, /^r-[0-9A-HJKMNP-TV-Z]{4}$/);
    assert.deepEqual(Object.keys((res.body as { data: object }).data), Object.keys((fixture('diagnostics.response.json').data as object)));
  } finally {
    await h.close();
  }
});

test('a report is stored under the sender, with counts, kept 30 days', async () => {
  const { h, mem, send } = await harness();
  try {
    await send(ALICE, report());
    const [row] = [...mem.rows.values()];
    assert.equal(row!.user_id, ALICE);
    assert.equal(row!.storage_path, `${ALICE}/${report().reportId}.json`);
    assert.deepEqual(row!.counts, { events: 5, requests: 2, failures: 1, crashes: 0, hasNote: true });
    assert.equal(Date.parse(row!.expires_at) - Date.parse(row!.created_at), REPORT_TTL_DAYS * 86_400_000);
    assert.deepEqual(JSON.parse(mem.files.get(row!.storage_path)!), report());
  } finally {
    await h.close();
  }
});

test('a retry stores one report and returns the same reference', async () => {
  const { h, mem, send } = await harness();
  try {
    const key = { 'Idempotency-Key': String(report().reportId) };
    const [a, b] = await Promise.all([send(ALICE, report(), key), send(ALICE, report(), key)]);
    const c = await send(ALICE, report(), key);
    const refs = [a, b, c].map((r) => (r.body as { data: { reference: string } }).data.reference);
    assert.equal(new Set(refs).size, 1);
    assert.equal(mem.rows.size, 1);
  } finally {
    await h.close();
  }
});

test("the same report id with another body, or from another person, is refused", async () => {
  const { h, mem, send } = await harness();
  try {
    await send(ALICE, report());
    const changed = await send(ALICE, report({ note: 'something else' }));
    assert.equal(changed.status, 409);
    assert.equal(code(changed.body), 'idempotency_mismatch');
    const bob = await send(BOB, report());
    assert.equal(bob.status, 409, "Bob can't reuse Alice's report id");
    assert.equal(mem.rows.size, 1);
    assert.equal([...mem.rows.values()][0]!.user_id, ALICE);
  } finally {
    await h.close();
  }
});

test('two people sending reports each get their own, under their own id', async () => {
  const { h, mem, send } = await harness();
  try {
    await send(ALICE, report());
    await send(BOB, report({ reportId: '00000000-0000-4000-8000-0000000000e1' }));
    assert.deepEqual([...mem.rows.values()].map((r) => r.user_id).sort(), [ALICE, BOB].sort());
    for (const r of mem.rows.values()) assert.ok(r.storage_path.startsWith(`${r.user_id}/`));
  } finally {
    await h.close();
  }
});

/** Every place a string can sit in a report, outside the note. */
const STRING_PATHS: Array<(r: Record<string, any>) => void> = [
  (r) => { r.events[1].screen = WORDS; },
  (r) => { r.events[2].control = WORDS; },
  (r) => { r.events[0].sheet = WORDS; },
  (r) => { r.events[3].itemId = WORDS; },
  (r) => { r.network[0].route = `/v2/entries/${WORDS}`; },
  (r) => { r.network[0].route = '/v2/entries/00000000-0000-4000-8000-000000000123'; },
  (r) => { r.network[1].code = WORDS; },
  (r) => { r.failures[0].code = WORDS; },
  (r) => { r.failures[0].screen = WORDS; },
  (r) => { r.performance.hitchRates[0].screen = WORDS; },
  (r) => { r.environment.appVersion = WORDS; },
  (r) => { r.environment.build = WORDS; },
  (r) => { r.environment.osVersion = WORDS; },
  (r) => { r.environment.deviceModel = WORDS; },
  (r) => { r.environment.locale = WORDS; },
  (r) => { r.environment.timeZone = WORDS; },
  (r) => { r.outbox.lastFailureCodes = [WORDS]; },
  (r) => { r.events[0].text = WORDS; },
  (r) => { r.environment.email = 'sam@example.com'; },
  (r) => { r.searchQuery = WORDS; },
];

test('no free text gets in anywhere except the labelled note', async () => {
  for (const [i, put] of STRING_PATHS.entries()) {
    const r = structuredClone(report()) as Record<string, any>;
    put(r);
    assert.equal(DiagnosticsReport.safeParse(r).success, false, `place ${i}`);
  }
  assert.equal(DiagnosticsReport.safeParse(report({ note: WORDS })).success, true, 'the note is the one place for words');
  assert.equal(DiagnosticsReport.safeParse(report({ note: 'x'.repeat(1001) })).success, false, 'and it has a cap');
});

test('the report has exactly the agreed fields', () => {
  assert.deepEqual(Object.keys(DiagnosticsReport.shape).sort(), Object.keys(fixture('diagnostics.request.json')).sort());
  assert.deepEqual(Object.keys(DiagnosticsReport.shape).sort(),
    ['account', 'crashes', 'createdAt', 'environment', 'events', 'failures', 'network', 'note', 'outbox', 'performance', 'reportId']);
});

test('the door refuses words in a report, a key that is not the report id, and anything over 2 MB', async () => {
  const { h, mem, send } = await harness();
  try {
    const bad = structuredClone(report()) as Record<string, any>;
    bad.events[1].screen = WORDS;
    const words = await send(ALICE, bad);
    assert.equal(words.status, 400);
    assert.equal(JSON.stringify(words.body).includes('walk'), false, 'nothing is echoed back');
    assert.equal((await send(ALICE, report(), { 'Idempotency-Key': '00000000-0000-4000-8000-000000000999' })).status, 400);
    const huge = report({ events: Array.from({ length: 2000 }, () => ({ t: '2026-10-22T09:20:00.000Z', kind: 'app_foreground' })), note: 'x'.repeat(1000) });
    const padded = JSON.stringify(huge) + ' '.repeat(2 * 1024 * 1024);
    assert.equal((await send(ALICE, padded)).status, 400);
    assert.equal(mem.rows.size, 0);
  } finally {
    await h.close();
  }
});

test('a gzip-compressed report is accepted', async () => {
  const { h, mem } = await harness();
  try {
    const res = await fetch(`${h.url}/v2/diagnostics`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Encoding': 'gzip', Authorization: `Bearer ${h.asUser(ALICE)}` },
      body: gzipSync(JSON.stringify(report())),
    });
    assert.equal(res.status, 200);
    assert.equal(mem.rows.size, 1);
  } finally {
    await h.close();
  }
});

test('the door log records the request, never the report', async () => {
  const { h, send } = await harness();
  try {
    await send(ALICE, report());
    const all = h.logLines.join('\n');
    assert.equal(all.includes('brief stopped'), false);
    assert.equal(all.includes('journal'), false);
    assert.ok(h.logLines.some((l) => l.includes('"door":"diagnostics.create"')));
  } finally {
    await h.close();
  }
});

test('expired reports are deleted, bundle and row, and newer ones stay', async () => {
  const mem = memoryDiagnostics();
  const store = createDiagnosticsStore(mem.backend, counterPick());
  const T0 = Date.parse('2026-10-01T00:00:00.000Z');
  const parsed = DiagnosticsReport.parse(report());
  await store.save(ALICE, parsed, T0);
  await store.save(ALICE, { ...parsed, reportId: '00000000-0000-4000-8000-0000000000f1' }, T0 + 20 * 86_400_000);
  assert.equal(await store.purgeExpired(T0 + 31 * 86_400_000), 1);
  assert.equal(mem.rows.size, 1);
  assert.equal(mem.files.size, 1);
  assert.equal(await store.purgeExpired(T0 + 31 * 86_400_000), 0);
});

test("deleting a person's diagnostics removes their bundles and rows, and nobody else's", async () => {
  const mem = memoryDiagnostics();
  const store = createDiagnosticsStore(mem.backend, counterPick());
  const parsed = DiagnosticsReport.parse(report());
  await store.save(ALICE, parsed, 0);
  await store.save(BOB, { ...parsed, reportId: '00000000-0000-4000-8000-0000000000f2' }, 0);
  assert.equal(await store.deleteFor(ALICE), 1);
  assert.deepEqual([...mem.rows.values()].map((r) => r.user_id), [BOB]);
  assert.equal(mem.files.size, 1);
});

test('a reference already in use is drawn again', async () => {
  const mem = memoryDiagnostics();
  const picks = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1];
  const store = createDiagnosticsStore(mem.backend, () => picks.shift() ?? 2);
  const parsed = DiagnosticsReport.parse(report());
  assert.deepEqual(await store.save(ALICE, parsed, 0), { outcome: 'stored', reference: 'r-0000' });
  assert.deepEqual(await store.save(ALICE, { ...parsed, reportId: '00000000-0000-4000-8000-0000000000f3' }, 0), { outcome: 'stored', reference: 'r-1111' });
  assert.match(newReference(), /^r-[0-9A-HJKMNP-TV-Z]{4}$/);
});

doorSuite({
  method: 'POST',
  path: '/v2/diagnostics',
  bucket: 'write',
  validBody: report(),
  invalid: { body: { ...report(), extra: true } },
  expect: () => ({ reference: 'r-0000' }),
  diagnostics: () => createDiagnosticsStore(memoryDiagnostics().backend, () => 0),
});

test('the purge runs at start and every six hours, and a failed run is reported, not fatal', async () => {
  const { startDiagnosticsPurge, PURGE_EVERY_MS } = await import('../src/diagnostics/purge.js');
  let runs = 0;
  const reported: unknown[] = [];
  let tick: () => void = () => undefined;
  let interval = 0;
  const stop = startDiagnosticsPurge(
    { purgeExpired: async () => { runs++; if (runs === 2) throw new Error('storage down'); return 0; } },
    { now: () => 0, report: (e) => reported.push(e), every: (run, ms) => { tick = run; interval = ms; return () => undefined; } },
  );
  await new Promise((r) => setImmediate(r));
  assert.equal(runs, 1, 'once at start');
  assert.equal(interval, PURGE_EVERY_MS);
  tick();
  await new Promise((r) => setImmediate(r));
  assert.equal(reported.length, 1);
  tick();
  await new Promise((r) => setImmediate(r));
  assert.equal(runs, 3, 'and it keeps going');
  stop();
});

test('storage and database errors surface as codes only', async () => {
  const { supabaseDiagnosticsBackend } = await import('../src/diagnostics/supabase-backend.js');
  const failing = {
    from: () => ({ select: () => ({ eq: () => ({ maybeSingle: async () => ({ data: null, error: { code: '42P01', message: `relation "x" (${WORDS})` } }) }) }) }),
    storage: { from: () => ({ upload: async () => ({ error: { statusCode: '500', message: WORDS } }) }) },
  };
  const backend = supabaseDiagnosticsBackend(failing as never);
  await assert.rejects(backend.findById('id'), (e: unknown) => e instanceof Error && e.message === 'diagnostics lookup failed (42P01)');
  await assert.rejects(backend.upload('p', '{}'), (e: unknown) => e instanceof Error && e.message === 'diagnostics upload failed (500)');
});
