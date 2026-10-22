import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { assertOnlyTestUsers, type Executor } from '../scripts/staging/migrations.js';
import { ensureSeedAccount } from '../scripts/staging/seed-accounts.js';
import type { UsersClient } from '../src/services/users.js';

const pkg = JSON.parse(readFileSync(join(__dirname, '..', 'package.json'), 'utf8')) as { scripts: Record<string, string> };

// Integrator review of #59: the dev server must read .env.staging over the
// shell from its first line, so Sentry and every module see staging.
test('dev:staging preloads the staging env file with override', () => {
  const script = pkg.scripts['dev:staging'] ?? '';
  assert.match(script, /DOTENV_CONFIG_PATH=\.env\.staging/);
  assert.match(script, /DOTENV_CONFIG_OVERRIDE=true/);
  assert.match(script, /--require dotenv\/config/);

  const dir = mkdtempSync(join(tmpdir(), 'backend-staging-'));
  const file = join(dir, '.env.staging');
  writeFileSync(file, 'SUPABASE_URL=https://staging.invalid\nRETROSPECT_ENV=staging\n');
  const out = spawnSync(process.execPath, ['--require', 'dotenv/config', '-e', 'process.stdout.write(process.env.SUPABASE_URL + " " + process.env.RETROSPECT_ENV)'], {
    cwd: join(__dirname, '..'),
    env: { PATH: process.env.PATH, SUPABASE_URL: 'https://production.invalid', RETROSPECT_ENV: 'production', DOTENV_CONFIG_PATH: file, DOTENV_CONFIG_OVERRIDE: 'true' },
    encoding: 'utf8',
  });
  assert.equal(out.stdout, 'https://staging.invalid staging');
});

/** A users table with the unique index on apple_user_id, yielding between calls like real requests. */
function fakeUsers() {
  const rows: { id: string; apple_user_id: string; email: string | null }[] = [];
  const tick = () => new Promise<void>((resolve) => setImmediate(resolve));
  const client = {
    from() {
      return {
        select() {
          return { eq: (_c: string, v: string) => ({ maybeSingle: async () => { await tick(); return { data: rows.find((r) => r.apple_user_id === v) ?? null, error: null }; } }) };
        },
        insert(row: Record<string, unknown>) {
          return { select: () => ({ single: async () => {
            await tick();
            if (rows.some((r) => r.apple_user_id === row.apple_user_id)) return { data: null, error: { code: '23505', message: 'duplicate' } };
            const stored = { id: `user-${rows.length + 1}`, apple_user_id: String(row.apple_user_id), email: (row.email as string) ?? null };
            rows.push(stored);
            return { data: stored, error: null };
          } }) };
        },
        update() {
          return { eq: async () => ({ error: null }) };
        },
      };
    },
  } as unknown as UsersClient;
  return { client, rows };
}

// Integrator review of #59: accounts are made with the seed's own staging client,
// never through whatever backend is listening on :3000.
test('seed accounts are the dev route\'s seeded subjects, made once even when two seeds race', async () => {
  const db = fakeUsers();
  const [a, b] = await Promise.all([ensureSeedAccount(db.client, 'month'), ensureSeedAccount(db.client, 'month')]);
  assert.equal(a, b);
  assert.deepEqual(db.rows.map((r) => r.apple_user_id), ['dev-test-user:seed-month']);
  assert.equal(await ensureSeedAccount(db.client, 'month'), a, 'a re-run finds it');
  assert.notEqual(await ensureSeedAccount(db.client, 'fresh'), a);
});

// Integrator review: a row with no Apple subject isn't a test account either.
test('the database check counts users with no Apple subject as real', async () => {
  const seen: { sql: string; params: unknown[] }[] = [];
  const db: Executor = {
    async query(sql, params = []) {
      seen.push({ sql, params });
      return sql.includes('to_regclass') ? { rows: [{ present: true }] } : { rows: [{ n: 0 }] };
    },
  };
  await assertOnlyTestUsers(db);
  const count = seen.find((q) => q.sql.includes('FROM users'));
  assert.match(count?.sql ?? '', /apple_user_id IS NULL OR apple_user_id NOT LIKE \$1/);
  assert.deepEqual(count?.params, ['dev-test-user:%']);
});
