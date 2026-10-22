/** DG.2: the diagnostics viewer behind the admin secret, over HTTP. */
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import type { AddressInfo } from 'node:net';
import { join } from 'node:path';
import test from 'node:test';
import express from 'express';
import { mountAdmin } from '../src/routes/admin-mount.js';
import { DiagnosticsReport } from '../src/diagnostics/schema.js';
import { createDiagnosticsStore } from '../src/diagnostics/store.js';
import { memoryDiagnostics } from './support/memory-diagnostics.js';

const SECRET = 'admin-secret-for-tests';
const PUBLIC_DIR = join(__dirname, '..', 'src', 'public');
const FIXTURE = join(__dirname, '..', '..', 'docs', 'team', 'contracts', 'fixtures', '00', 'diagnostics.request.json');
const ALICE = '11111111-1111-4111-8111-111111111111';
const BOB = '22222222-2222-4222-8222-222222222222';

async function viewer(opts: { secret?: string | null } = {}) {
  const mem = memoryDiagnostics();
  let n = 0;
  const store = createDiagnosticsStore(mem.backend, () => (n++ % 4 === 3 ? Math.floor(n / 4) : 0));
  const report = DiagnosticsReport.parse(JSON.parse(readFileSync(FIXTURE, 'utf8')));
  const alice = await store.save(ALICE, report, Date.parse('2026-10-22T09:30:00Z'));
  const bob = await store.save(BOB, { ...report, reportId: '00000000-0000-4000-8000-0000000000e1', note: null }, Date.parse('2026-10-22T10:00:00Z'));
  const app = express();
  const warn = console.warn;
  console.warn = () => undefined;
  try {
    mountAdmin(app, { secret: opts.secret === undefined ? SECRET : opts.secret, publicDir: PUBLIC_DIR, diagnostics: store });
  } finally {
    console.warn = warn;
  }
  const server = app.listen(0, '127.0.0.1');
  await new Promise<void>((resolve) => server.once('listening', () => resolve()));
  const base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
  const get = (path: string, secret: string | null = SECRET) => fetch(`${base}${path}`, { headers: secret ? { 'x-admin-secret': secret } : {} });
  const refs = { alice: alice.outcome === 'mismatch' ? '' : alice.reference, bob: bob.outcome === 'mismatch' ? '' : bob.reference };
  return { get, refs, report, close: () => new Promise<void>((resolve) => server.close(() => resolve())) };
}

test('the list shows reports newest first, by reference, user and date, without the bundle or where it is kept', async () => {
  const v = await viewer();
  try {
    const body = await (await v.get('/admin/diagnostics')).json() as { data: Array<Record<string, unknown>> };
    assert.deepEqual(body.data.map((r) => r.reference), [v.refs.bob, v.refs.alice]);
    assert.deepEqual(Object.keys(body.data[0]!).sort(), ['appVersion', 'counts', 'createdAt', 'expiresAt', 'reference', 'sizeBytes', 'userId']);
    assert.equal(JSON.stringify(body).includes('brief stopped'), false, 'no note or bundle in the list');
  } finally {
    await v.close();
  }
});

test('the list filters by user and by reference, in any case', async () => {
  const v = await viewer();
  try {
    const byUser = await (await v.get(`/admin/diagnostics?userId=${ALICE}`)).json() as { data: Array<{ userId: string }> };
    assert.deepEqual(byUser.data.map((r) => r.userId), [ALICE]);
    const byRef = await (await v.get(`/admin/diagnostics?reference=${v.refs.bob.toLowerCase()}`)).json() as { data: Array<{ reference: string }> };
    assert.deepEqual(byRef.data.map((r) => r.reference), [v.refs.bob]);
  } finally {
    await v.close();
  }
});

test('bad filters are refused, never queried', async () => {
  const v = await viewer();
  try {
    for (const q of ['?userId=not-a-uuid', "?reference=r-1'; drop", '?limit=0', '?limit=9999', '?limit=abc']) {
      assert.equal((await v.get(`/admin/diagnostics${q}`)).status, 400, q);
    }
    assert.equal((await v.get('/admin/diagnostics/not-a-ref')).status, 400);
  } finally {
    await v.close();
  }
});

test('one report shows its whole bundle for the timeline; an unknown reference is a 404', async () => {
  const v = await viewer();
  try {
    const body = await (await v.get(`/admin/diagnostics/${v.refs.alice}`)).json() as { data: { report: unknown; userId: string } };
    assert.deepEqual(body.data.report, v.report);
    assert.equal(body.data.userId, ALICE);
    assert.equal((await v.get('/admin/diagnostics/r-ZZZZ')).status, 404);
  } finally {
    await v.close();
  }
});

test('a report downloads as a JSON file named by its reference', async () => {
  const v = await viewer();
  try {
    const res = await v.get(`/admin/diagnostics/${v.refs.alice}/download`);
    assert.equal(res.status, 200);
    assert.equal(res.headers.get('content-disposition'), `attachment; filename="${v.refs.alice}.json"`);
    assert.deepEqual(await res.json(), v.report);
  } finally {
    await v.close();
  }
});

test('the viewer needs the admin secret, and is absent without one', async () => {
  const v = await viewer();
  try {
    assert.equal((await v.get('/admin/diagnostics', null)).status, 403);
    assert.equal((await v.get('/admin/diagnostics', 'wrong')).status, 403);
    assert.equal((await v.get(`/admin/diagnostics/${v.refs.alice}/download`, null)).status, 403);
    assert.equal((await v.get('/dashboard/diagnostics', null)).status, 200, 'the page itself asks for the secret');
  } finally {
    await v.close();
  }
  const none = await viewer({ secret: null });
  try {
    assert.equal((await none.get('/admin/diagnostics')).status, 404);
    assert.equal((await none.get('/dashboard/diagnostics')).status, 404);
  } finally {
    await none.close();
  }
});

test('a storage failure is a generic 500', async () => {
  const mem = memoryDiagnostics();
  const store = createDiagnosticsStore({ ...mem.backend, list: async () => { throw new Error('diagnostics list failed (08006)'); } });
  const app = express();
  mountAdmin(app, { secret: SECRET, publicDir: PUBLIC_DIR, diagnostics: store });
  const server = app.listen(0, '127.0.0.1');
  await new Promise<void>((resolve) => server.once('listening', () => resolve()));
  const error = console.error;
  console.error = () => undefined;
  try {
    const res = await fetch(`http://127.0.0.1:${(server.address() as AddressInfo).port}/admin/diagnostics`, { headers: { 'x-admin-secret': SECRET } });
    assert.equal(res.status, 500);
    assert.deepEqual(await res.json(), { success: false, error: 'Failed to read diagnostics' });
  } finally {
    console.error = error;
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});

// The note is a person's own words: the page must show it as text, never run it as HTML.
test('the viewer page puts report content on the page as text only', () => {
  const page = readFileSync(join(PUBLIC_DIR, 'diagnostics.html'), 'utf8');
  assert.equal(/innerHTML|outerHTML|insertAdjacentHTML|document\.write/.test(page), false);
  assert.ok(page.includes('textContent'));
});
