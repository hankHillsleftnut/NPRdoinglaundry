/**
 * BE1.1: the door suite on the sending doors, against a real Postgres
 * (PGlite, migration 022), with each happy path equal to its contract 02
 * fixture. The create suite's person already holds the fixture's entry, so the
 * happy path is the outbox's replay (200, the stored row); the create itself
 * is proven in entries.test.ts.
 */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { before } from 'node:test';
import { asServiceRole, freshDatabase, type PGlite } from './support/database.js';
import { pgliteRpc } from './support/pglite-rpc.js';
import { doorSuite } from './support/door-suite.js';
import { supabaseEntryStore, type EntryStore } from '../src/entries/store.js';
import { requestHash } from '../src/services/content-insert.js';

const FIXTURES = join(__dirname, '..', '..', 'docs', 'team', 'contracts', 'fixtures', '02');
const fixture = (name: string) => (JSON.parse(readFileSync(join(FIXTURES, name), 'utf8')) as { data: unknown }).data;
const request = JSON.parse(readFileSync(join(FIXTURES, 'entry.create.request.json'), 'utf8')) as { text: string; clientEntryId: string; createdAt: string };
const USER = '11111111-1111-4111-8111-111111111111';
const OTHER = '22222222-2222-4222-8222-222222222222';
/** 21 Oct, 23:00Z: the fixtures' day, in UTC (no X-Time-Zone header in the suite). */
const T0 = Date.parse('2026-10-21T23:00:00.000Z');

let db: PGlite;
let entries: EntryStore;
function asService<T extends object>(store: T): T {
  return Object.fromEntries(Object.entries(store).map(([k, fn]) => [k, (...a: unknown[]) => asServiceRole(db, () => (fn as (...x: unknown[]) => Promise<unknown>)(...a))])) as T;
}
before(async () => {
  db = await freshDatabase();
  entries = asService(supabaseEntryStore(pgliteRpc(db)));
  for (const id of [USER, OTHER]) await db.query(`INSERT INTO users (id, apple_user_id, access) VALUES ($1, $2, 'member')`, [id, `apple-${id}`]);
});
/** The fixture's entry, as the first send stored it (once; the suite's sends are its replays). Runs after the today suite, whose day is empty. */
async function storeFixtureEntry(): Promise<void> {
  const stored = (fixture('entry.create.response.json') as { entry: { id: string; text: string; createdAt: string; clientEntryId: string } }).entry;
  await db.query(
    `INSERT INTO raw_content (id, user_id, content_type, content, content_date, metadata, processing_status, created_at) VALUES ($1, $2, 'journal_entry', $3, $4, $5, 'pending', $4) ON CONFLICT (id) DO NOTHING`,
    [stored.id, USER, stored.text, stored.createdAt, JSON.stringify({ client_entry_id: stored.clientEntryId, request_hash: requestHash('journal_entry', stored.text), app_version: '1.0 (42)' })],
  );
}
const ingested: string[] = [];
const stores = () => ({ entries, startIngest: (_u: string, id: string) => { ingested.push(id); } });

doorSuite({
  method: 'GET', path: '/v2/entries/today', bucket: 'read',
  invalid: { query: 'userId=someone' },
  expect: () => fixture('entries.today.empty.json'),
  stores, now: T0,
});

doorSuite({
  method: 'POST', path: '/v2/entries', bucket: 'write',
  validBody: request,
  invalid: { body: { ...request, kind: 'conversation' } },
  headers: { 'Idempotency-Key': request.clientEntryId },
  setup: () => storeFixtureEntry(),
  expect: () => fixture('entry.create.response.json'),
  stores, now: T0,
});
