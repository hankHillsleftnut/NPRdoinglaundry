import assert from 'node:assert/strict';
import test from 'node:test';
import {
  insertRawContent,
  resetMissingMigrationWarningForTests,
  type InsertClient,
} from '../src/services/content-insert.js';

/**
 * A fake Supabase client that behaves like the real one closely enough to
 * exercise the three outcomes that matter -- stored, already there, and the
 * migration not yet applied -- without a database.
 *
 * It enforces the partial unique index the way Postgres does: only rows that
 * carry a dedup_key are checked, so rows written before migration 117 never
 * collide.
 */
function fakeClient(opts: { hasDedupColumns: boolean }) {
  const rows: Record<string, unknown>[] = [];
  let nextId = 1;
  const inserts: Record<string, unknown>[] = [];

  const client: InsertClient = {
    from() {
      return {
        insert(row: Record<string, unknown>) {
          return {
            select() {
              return {
                async single() {
                  inserts.push(row);
                  if (!opts.hasDedupColumns && 'dedup_key' in row) {
                    return { data: null, error: { code: '42703', message: 'column "dedup_key" does not exist' } };
                  }
                  if (row.dedup_key != null) {
                    const clash = rows.find((r) => r.user_id === row.user_id && r.dedup_key === row.dedup_key);
                    if (clash) {
                      return { data: null, error: { code: '23505', message: 'duplicate key value' } };
                    }
                  }
                  const stored = { ...row, id: `row-${nextId++}` };
                  rows.push(stored);
                  return { data: { id: stored.id as string }, error: null };
                },
              };
            },
          };
        },
        select() {
          const filters: [string, unknown][] = [];
          const chain = {
            eq(column: string, value: unknown) {
              filters.push([column, value]);
              return chain;
            },
            async maybeSingle() {
              const hit = rows.find((r) => filters.every(([c, v]) => r[c] === v));
              return { data: hit ? { id: hit.id as string } : null, error: null };
            },
          };
          return chain as any;
        },
      } as any;
    },
  };

  return { client, rows, inserts };
}

const USER = 'user-1';
const row = (content: string) => ({
  user_id: USER,
  content_type: 'journal_entry',
  content,
  processing_status: 'pending',
});

test('a new upload is stored with its dedup key', async () => {
  const db = fakeClient({ hasDedupColumns: true });
  const outcome = await insertRawContent(db.client, 'raw_content', row('went to the gym'), {
    userId: USER,
    contentType: 'journal_entry',
    content: 'went to the gym',
    contentDate: '2026-10-12T08:00:00Z',
  });

  assert.equal(outcome.kind, 'inserted');
  assert.equal(outcome.strategy, 'content_hash_day');
  assert.equal(db.rows.length, 1);
  assert.ok(db.rows[0]!.dedup_key, 'the key is written');
});

test('a repeat upload returns the original row instead of storing a copy', async () => {
  const db = fakeClient({ hasDedupColumns: true });
  const input = {
    userId: USER,
    contentType: 'journal_entry',
    content: 'went to the gym',
    contentDate: '2026-10-12T08:00:00Z',
  };

  const first = await insertRawContent(db.client, 'raw_content', row('went to the gym'), input);
  const second = await insertRawContent(db.client, 'raw_content', row('went to the gym'), input);

  assert.equal(first.kind, 'inserted');
  assert.equal(second.kind, 'duplicate', 'the second is recognised');
  assert.equal(second.id, first.id, 'and points at the row that already exists');
  assert.equal(db.rows.length, 1, 'only one row is ever stored');
});

test('the 188 health-summary copies become one row', async () => {
  // The largest duplicate group found in production.
  const db = fakeClient({ hasDedupColumns: true });
  const body = 'Apple Health summary for May 17, 2026:\n\nSteps: 14060';
  const outcomes = [];
  for (let i = 0; i < 188; i++) {
    outcomes.push(
      await insertRawContent(
        db.client,
        'raw_content',
        { user_id: USER, content_type: 'healthkit', content: body },
        { userId: USER, contentType: 'healthkit', content: body, contentDate: '2026-05-17T00:00:00Z' },
      ),
    );
  }

  assert.equal(db.rows.length, 1);
  assert.equal(outcomes.filter((o) => o.kind === 'inserted').length, 1, 'one ingest run, not 188');
  assert.equal(outcomes.filter((o) => o.kind === 'duplicate').length, 187);
});

test('if migration 117 has not been applied, uploads still work exactly as before', async () => {
  // Migrations here are applied by hand, so this route can reach production
  // first. A deduplication feature must never be able to break uploading.
  resetMissingMigrationWarningForTests();
  const db = fakeClient({ hasDedupColumns: false });

  const outcome = await insertRawContent(db.client, 'raw_content', row('went to the gym'), {
    userId: USER,
    contentType: 'journal_entry',
    content: 'went to the gym',
    contentDate: '2026-10-12T08:00:00Z',
  });

  assert.equal(outcome.kind, 'inserted', 'the upload succeeds');
  assert.equal(outcome.strategy, null, 'and reports that it was not deduplicated');
  assert.equal(db.rows.length, 1);
  assert.equal(db.rows[0]!.dedup_key, undefined, 'the fallback write carries no dedup columns');
});

test('onboarding is not keyed yet, so repeat profiles behave exactly as before', async () => {
  // Deliberately deferred: replacing a profile in place keeps its id, and
  // extraction skips ids it has already processed, so a new profile would never
  // be read. Until that is solved, onboarding is untouched by this change.
  const db = fakeClient({ hasDedupColumns: true });
  const profile = (v: string) => ({ user_id: USER, content_type: 'onboarding_profile', content: v });
  const input = (v: string) => ({ userId: USER, contentType: 'onboarding_profile', content: v });

  const a = await insertRawContent(db.client, 'raw_content', profile('v1'), input('v1'));
  const b = await insertRawContent(db.client, 'raw_content', profile('v2'), input('v2'));

  assert.equal(a.kind, 'inserted');
  assert.equal(b.kind, 'inserted');
  assert.equal(db.rows.length, 2);
  assert.equal(db.inserts.every((r) => !('dedup_key' in r)), true, 'no key is written for onboarding');
});

test('two users uploading identical content are never merged', async () => {
  const db = fakeClient({ hasDedupColumns: true });
  const body = 'Steps: 10000';
  for (const userId of ['user-a', 'user-b']) {
    await insertRawContent(
      db.client,
      'raw_content',
      { user_id: userId, content_type: 'healthkit', content: body },
      { userId, contentType: 'healthkit', content: body },
    );
  }

  assert.equal(db.rows.length, 2);
});
