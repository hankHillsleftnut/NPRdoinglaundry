import assert from 'node:assert/strict';
import test from 'node:test';
import { getOrCreateUserWith, type UsersClient } from '../src/services/users.js';

type Row = { id: string; apple_user_id: string; email: string | null };

/**
 * A fake users table with the unique index on apple_user_id. Every call yields
 * to the event loop first, so two callers interleave the way two requests do:
 * both look, both find nothing, both insert, and the index lets one win.
 */
function fakeUsers(opts: { failLookup?: boolean; insertError?: { code?: string; message: string } } = {}) {
  const rows: Row[] = [];
  const updates: Record<string, unknown>[] = [];
  let next = 1;
  const tick = () => new Promise<void>((resolve) => setImmediate(resolve));

  const client: UsersClient = {
    from() {
      return {
        select() {
          return {
            eq(_column: string, apple: string) {
              return {
                async maybeSingle() {
                  await tick();
                  if (opts.failLookup) return { data: null, error: { message: 'connection reset' } };
                  return { data: rows.find((r) => r.apple_user_id === apple) ?? null, error: null };
                },
              };
            },
          };
        },
        insert(row: Record<string, unknown>) {
          return {
            select() {
              return {
                async single() {
                  await tick();
                  if (opts.insertError) return { data: null, error: opts.insertError };
                  if (rows.some((r) => r.apple_user_id === row.apple_user_id)) {
                    return { data: null, error: { code: '23505', message: 'duplicate key value violates unique constraint' } };
                  }
                  const stored = { id: `user-${next++}`, apple_user_id: String(row.apple_user_id), email: (row.email as string) ?? null };
                  rows.push(stored);
                  return { data: stored, error: null };
                },
              };
            },
          };
        },
        update(row: Record<string, unknown>) {
          return {
            async eq(_column: string, id: string) {
              updates.push({ ...row, id });
              const target = rows.find((r) => r.id === id);
              if (target && typeof row.email === 'string') target.email = row.email;
              return { error: null };
            },
          };
        },
      };
    },
  };
  return { client, rows, updates };
}

// BE0.0 (backend-reference §3): the second of two concurrent first sign-ins hit
// the unique index and became a 500.
test('two first sign-ins at once create one user', async () => {
  const db = fakeUsers();
  const [a, b] = await Promise.all([
    getOrCreateUserWith(db.client, 'users', 'apple-1'),
    getOrCreateUserWith(db.client, 'users', 'apple-1'),
  ]);
  assert.equal(a.id, b.id, 'both get the same user');
  assert.equal(db.rows.length, 1);
});

test('a returning user is found, not created again', async () => {
  const db = fakeUsers();
  const first = await getOrCreateUserWith(db.client, 'users', 'apple-1');
  const again = await getOrCreateUserWith(db.client, 'users', 'apple-1');
  assert.equal(again.id, first.id);
  assert.equal(db.rows.length, 1);
});

test('a new email from Apple replaces the stored one; no email keeps it', async () => {
  const db = fakeUsers();
  await getOrCreateUserWith(db.client, 'users', 'apple-1', 'a@example.com');
  const same = await getOrCreateUserWith(db.client, 'users', 'apple-1');
  assert.equal(same.email, 'a@example.com');
  assert.equal(db.updates.length, 0, 'nothing to update');
  const changed = await getOrCreateUserWith(db.client, 'users', 'apple-1', 'b@example.com');
  assert.equal(changed.email, 'b@example.com');
  assert.equal(db.rows[0]!.email, 'b@example.com');
});

test('two different Apple subjects are two users', async () => {
  const db = fakeUsers();
  const [a, b] = await Promise.all([
    getOrCreateUserWith(db.client, 'users', 'apple-1'),
    getOrCreateUserWith(db.client, 'users', 'apple-2'),
  ]);
  assert.notEqual(a.id, b.id);
});

test('a failed lookup is an error, never a new account', async () => {
  const db = fakeUsers({ failLookup: true });
  await assert.rejects(getOrCreateUserWith(db.client, 'users', 'apple-1'), /Failed to look up user/);
  assert.equal(db.rows.length, 0);
});

test('an insert that fails for another reason is an error, not a retry', async () => {
  const db = fakeUsers({ insertError: { code: '42501', message: 'permission denied' } });
  await assert.rejects(getOrCreateUserWith(db.client, 'users', 'apple-1'), /Failed to create user/);
});

test('a unique violation whose winner can no longer be found is an error', async () => {
  // The other sign-in's row vanished between its insert and our read (deleted in the gap).
  const db = fakeUsers({ insertError: { code: '23505', message: 'duplicate key value' } });
  await assert.rejects(getOrCreateUserWith(db.client, 'users', 'apple-1'), /Failed to create user/);
});
