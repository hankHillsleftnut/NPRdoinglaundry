/**
 * `npm run staging:seed` -- create local staging's three test accounts and their
 * invented content (scripts/staging/seed.ts). Safe to run again.
 *
 *   npm run staging:seed               seed what is missing
 *   npm run staging:seed -- --reset    remove the three accounts, then seed them fresh
 *
 * Accounts are made with this script's own staging client (the same
 * `dev-test-user:seed-<key>` subjects the dev route reaches), so it needs no
 * backend running; test builds then get a token from the dev route.
 * Prints account names, ids, row counts and error codes only. Staging only
 * (scripts/staging/guard.ts): reads .env.staging itself, over the shell, and
 * refuses a database with any user who isn't a test account.
 */
import { join } from 'node:path';
import { createClient } from '@supabase/supabase-js';
import { assertStaging, loadStagingEnv, requireVar } from './staging/guard.js';
import { TEST_SUBJECT_PREFIX } from './staging/migrations.js';
import { ensureSeedAccount } from './staging/seed-accounts.js';
import type { UsersClient } from '../src/services/users.js';
import { seedAll, SEED_MODEL_VERSION, type AccountKey, type Row, type SeedPorts, type SeedTable } from './staging/seed.js';

const MARKED_BY_METADATA: ReadonlySet<SeedTable> = new Set<SeedTable>(['raw_content', 'podcast_episodes']);
const ORDER_COLUMN: Record<SeedTable, string> = {
  raw_content: 'content_date',
  daily_briefs: 'brief_date',
  hypotheses: 'created_at',
  podcast_episodes: 'created_at',
};

function ports(env: NodeJS.ProcessEnv): SeedPorts {
  const db = createClient(requireVar(env, 'SUPABASE_URL'), requireVar(env, 'SUPABASE_SERVICE_KEY'), {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  return {
    // Made with this script's own staging client, never through whatever
    // backend is listening locally (it could be configured for production).
    ensureAccount: (key: AccountKey) => ensureSeedAccount(db as unknown as UsersClient, key),
    async seededIds(table, userId) {
      const marker = MARKED_BY_METADATA.has(table)
        ? db.from(table).select('id').eq('user_id', userId).eq('metadata->>test_account', 'true')
        : db.from(table).select('id').eq('user_id', userId).eq('model_version', SEED_MODEL_VERSION);
      const { data, error } = await marker.order(ORDER_COLUMN[table], { ascending: true });
      if (error) throw new Error(`reading ${table} failed (${error.code})`);
      return (data ?? []).map((r: { id: string }) => r.id);
    },
    async insert(table, rows: Row[]) {
      const { data, error } = await db.from(table).insert(rows).select('id');
      if (error) throw new Error(`inserting into ${table} failed (${error.code})`);
      return (data ?? []).map((r: { id: string }) => r.id);
    },
    async hasBriefOn(userId, briefDate) {
      const { count, error } = await db.from('daily_briefs').select('id', { count: 'exact', head: true })
        .eq('user_id', userId).eq('brief_date', briefDate);
      if (error) throw new Error(`reading daily_briefs failed (${error.code})`);
      return (count ?? 0) > 0;
    },
    async nonTestUserCount() {
      // A row with no Apple subject isn't a test account either.
      const { count, error } = await db.from('users').select('id', { count: 'exact', head: true })
        .or(`apple_user_id.is.null,apple_user_id.not.like.${TEST_SUBJECT_PREFIX}*`);
      if (error) throw new Error(`reading users failed (${error.code})`);
      return count ?? 0;
    },
    async deleteAccount(userId) {
      const { error } = await db.from('users').delete().eq('id', userId);
      if (error) throw new Error(`removing a test account failed (${error.code})`);
    },
  };
}

async function main(): Promise<void> {
  loadStagingEnv(join(__dirname, '..', '.env.staging'));
  assertStaging(process.env);
  const reset = process.argv.includes('--reset');
  const reports = await seedAll(ports(process.env), new Date(), { reset });
  for (const r of reports) {
    const inserted = Object.entries(r.inserted).map(([t, n]) => `${t} ${n}`).join(', ') || 'nothing new';
    console.log(`${r.account.padEnd(8)} ${r.userId}  ${inserted}`);
  }
}

main().catch((err: unknown) => {
  console.error(err instanceof Error ? err.message : 'staging:seed failed');
  process.exitCode = 1;
});
