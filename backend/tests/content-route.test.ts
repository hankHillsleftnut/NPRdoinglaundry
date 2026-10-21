import assert from 'node:assert/strict';
import type { AddressInfo } from 'node:net';
import test from 'node:test';
import express from 'express';
import { insertRawContent, type InsertClient } from '../src/services/content-insert.js';
import { MAX_IDEMPOTENCY_KEY_LENGTH, uploadContentHandler } from '../src/routes/content-upload.js';

type Row = Record<string, unknown> & { id: string };

/**
 * raw_content in memory, with the partial unique index on (user_id, dedup_key).
 * Each call yields first, so two concurrent uploads interleave like two requests.
 */
function fakeRawContent() {
  const rows: Row[] = [];
  let next = 1;
  const tick = () => new Promise<void>((resolve) => setImmediate(resolve));
  const client = {
    from() {
      return {
        insert(row: Record<string, unknown>) {
          return {
            select() {
              return {
                async single() {
                  await tick();
                  if (row.dedup_key != null && rows.some((r) => r.user_id === row.user_id && r.dedup_key === row.dedup_key)) {
                    return { data: null, error: { code: '23505', message: 'duplicate key value' } };
                  }
                  const stored = { ...row, id: `row-${next++}` };
                  rows.push(stored);
                  return { data: { id: stored.id }, error: null };
                },
              };
            },
          };
        },
        select() {
          const filters: [string, unknown][] = [];
          const chain = {
            eq(column: string, value: unknown) { filters.push([column, value]); return chain; },
            async maybeSingle() {
              await tick();
              const hit = rows.find((r) => filters.every(([c, v]) => r[c] === v));
              return { data: hit ? { id: hit.id, metadata: hit.metadata as Record<string, unknown> } : null, error: null };
            },
          };
          return chain;
        },
      };
    },
  } as unknown as InsertClient;
  return { client, rows };
}

async function startApp() {
  const db = fakeRawContent();
  const ingested: string[] = [];
  const app = express();
  app.use(express.json());
  app.use((req, _res, next) => { req.user = { id: 'user-1', appleUserId: 'apple-1' }; next(); });
  app.post('/content', uploadContentHandler({
    findDataSourceId: async () => null,
    insert: (row, dedup) => insertRawContent(db.client, 'raw_content', row, dedup),
    markConnected: async () => undefined,
    startIngest: (_userId, id) => { ingested.push(id); },
    now: () => new Date('2026-10-21T12:00:00.000Z'),
  }));
  const server = app.listen(0, '127.0.0.1');
  await new Promise<void>((resolve) => server.once('listening', () => resolve()));
  const { port } = server.address() as AddressInfo;
  const upload = async (body: Record<string, unknown>, key?: string) => {
    const res = await fetch(`http://127.0.0.1:${port}/content`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...(key === undefined ? {} : { 'Idempotency-Key': key }) },
      body: JSON.stringify(body),
    });
    return { status: res.status, replayed: res.headers.get('Idempotency-Replayed'), body: (await res.json()) as Record<string, unknown> };
  };
  return { db, ingested, upload, close: () => new Promise<void>((resolve) => server.close(() => resolve())) };
}

const entry = (content: string, metadata?: Record<string, unknown>) =>
  ({ contentType: 'journal_entry', content, ...(metadata ? { metadata } : {}) });

// BE0.0 (backend-reference §0 finding 7): the Idempotency-Key had no length cap.
test('a key over 128 characters is refused before anything is stored', async () => {
  const app = await startApp();
  try {
    const res = await app.upload(entry('test entry'), 'k'.repeat(MAX_IDEMPOTENCY_KEY_LENGTH + 1));
    assert.equal(res.status, 400);
    assert.deepEqual(res.body, { success: false, error: 'Idempotency-Key too long' });
    assert.equal(app.db.rows.length, 0);
  } finally {
    await app.close();
  }
});

// Integrator review of #61: the cap must cover the key actually used.
test('a client_event_id over 128 characters is refused too, and the length is measured trimmed', async () => {
  const app = await startApp();
  try {
    const long = await app.upload(entry('test entry', { client_event_id: 'e'.repeat(MAX_IDEMPOTENCY_KEY_LENGTH + 1) }));
    assert.equal(long.status, 400);
    const padded = await app.upload(entry('test entry'), `  ${'k'.repeat(MAX_IDEMPOTENCY_KEY_LENGTH)}  `);
    assert.equal(padded.status, 202, 'surrounding spaces are not part of the key');
  } finally {
    await app.close();
  }
});

test('a reused key with a different body is a 409, and nothing is stored or ingested', async () => {
  const app = await startApp();
  try {
    assert.equal((await app.upload(entry('first'), 'key-1')).status, 202);
    const reused = await app.upload(entry('second'), 'key-1');
    assert.equal(reused.status, 409);
    assert.deepEqual(reused.body, { success: false, error: 'Idempotency-Key reused with a different body' });
    assert.equal(app.db.rows.length, 1);
    assert.equal(app.ingested.length, 1);
  } finally {
    await app.close();
  }
});

test('an onboarding_profile upload repeated with the same key is a 200 replay, never a second row', async () => {
  const app = await startApp();
  try {
    const profile = { contentType: 'onboarding_profile', content: 'test profile' };
    const first = await app.upload(profile, 'key-1');
    const replay = await app.upload(profile, 'key-1');
    assert.equal(first.status, 202);
    assert.equal(replay.status, 200);
    assert.equal(replay.replayed, 'true');
    assert.equal((replay.body.data as { rawContentId: string }).rawContentId, (first.body.data as { rawContentId: string }).rawContentId);
    assert.equal(app.db.rows.length, 1);
    assert.equal(app.ingested.length, 1, 'one ingest run');
  } finally {
    await app.close();
  }
});

test('the same key with two different bodies at once stores one row and refuses the other', async () => {
  const app = await startApp();
  try {
    const [a, b] = await Promise.all([app.upload(entry('one'), 'key-1'), app.upload(entry('two'), 'key-1')]);
    assert.deepEqual([a.status, b.status].sort(), [202, 409]);
    assert.equal(app.db.rows.length, 1);
    assert.equal(app.ingested.length, 1);
  } finally {
    await app.close();
  }
});

test('the same key and body at once stores one row and replays the other', async () => {
  const app = await startApp();
  try {
    const [a, b] = await Promise.all([app.upload(entry('one'), 'key-1'), app.upload(entry('one'), 'key-1')]);
    assert.deepEqual([a.status, b.status].sort(), [200, 202]);
    assert.equal(app.db.rows.length, 1);
    assert.equal(app.ingested.length, 1);
  } finally {
    await app.close();
  }
});
