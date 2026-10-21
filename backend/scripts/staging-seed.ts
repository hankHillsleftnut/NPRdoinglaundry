/**
 * `npm run staging:seed` -- create local staging's three test accounts and their
 * invented content (scripts/staging/seed.ts). Safe to run again.
 *
 *   npm run staging:seed               seed what is missing
 *   npm run staging:seed -- --reset    remove the three accounts, then seed them fresh
 *
 * Needs the backend running on local staging (`npm run dev:staging`): accounts
 * are made through its dev route, the way the app's test builds sign in.
 * Prints account names, ids and row counts only.
 */
import { createClient } from '@supabase/supabase-js';
import { assertStaging, requireVar } from './staging/guard.js';
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
  const backend = env.STAGING_BACKEND_URL ?? `http://localhost:${env.PORT ?? '3000'}`;

  return {
    async ensureAccount(key: AccountKey) {
      const res = await fetch(`${backend}/auth/dev/test-user`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ key }),
      });
      if (!res.ok) throw new Error(`the dev route answered ${res.status}; is the backend running with npm run dev:staging?`);
      const body = (await res.json()) as { data?: { user?: { id?: string } } };
      const id = body.data?.user?.id;
      if (!id) throw new Error('the dev route returned no user id');
      return id;
    },
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
      if (error) throw new Error(`inserting into ${table} failed (${error.code}): ${error.message}`);
      return (data ?? []).map((r: { id: string }) => r.id);
    },
    async deleteAccount(userId) {
      const { error } = await db.from('users').delete().eq('id', userId);
      if (error) throw new Error(`removing a test account failed (${error.code})`);
    },
  };
}

async function main(): Promise<void> {
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
