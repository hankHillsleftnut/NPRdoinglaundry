/**
 * `npm run staging:migrate` -- build the backend's tables on the staging database.
 *
 *   npm run staging:migrate              show the plan; change nothing
 *   npm run staging:migrate -- --apply   apply it, then make the staging bucket
 *
 * Staging only: refuses unless .env.staging says RETROSPECT_ENV=staging. Needs
 * DATABASE_URL (the staging project's direct Postgres string). Prints file
 * names only, never the connection string or its host. The agent's migrations
 * (100 onward) are applied afterwards from the agent repo; see docs/team/staging.md.
 */
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import pg from 'pg';
import { assertStaging, requireVar } from './staging/guard.js';
import { STAGING_BUCKETS_SQL, applyPlan, plan, recordedMigrations } from './staging/migrations.js';

const SUPABASE_DIR = join(__dirname, '..', '..', 'supabase');
const MIGRATIONS_DIR = join(SUPABASE_DIR, 'migrations');

function readSql(file: string): string {
  return readFileSync(file.startsWith('combined') ? join(SUPABASE_DIR, file) : join(MIGRATIONS_DIR, file), 'utf8');
}

async function main(): Promise<void> {
  assertStaging(process.env);
  const apply = process.argv.includes('--apply');
  const client = new pg.Client({ connectionString: requireVar(process.env, 'DATABASE_URL'), ssl: { rejectUnauthorized: false } });
  await client.connect();
  try {
    const p = plan(readdirSync(MIGRATIONS_DIR), await recordedMigrations(client, { create: apply }));
    console.log(`Already recorded: ${p.alreadyRecorded.length ? p.alreadyRecorded.join(', ') : 'none'}`);
    if (p.base) console.log(`Base schema: ${p.base} (records ${p.toBaseline.join(', ')} as contained in it)`);
    console.log(`To apply: ${p.toApply.length ? p.toApply.join(', ') : 'nothing'}`);
    if (!apply) {
      console.log('\nPlan only. Re-run with --apply to carry it out.');
      return;
    }
    const result = await applyPlan(client, p, readSql);
    if (result.applied.length) console.log(`Applied: ${result.applied.join(', ')}`);
    if (result.baselined.length) console.log(`Recorded as contained in the base: ${result.baselined.join(', ')}`);
    if (result.failed) {
      console.error(`FAILED: ${result.failed.file}: ${result.failed.error}\nRolled back; nothing after it ran.`);
      process.exitCode = 1;
      return;
    }
    await client.query(STAGING_BUCKETS_SQL);
    console.log('Bucket podcast-audio: present, private.');
  } finally {
    await client.end();
  }
}

// A driver error can carry the database host, so only its code is printed.
main().catch((err: unknown) => {
  const code = (err as { code?: unknown }).code;
  console.error(typeof code === 'string' ? `staging:migrate failed (${code})` : err instanceof Error ? err.message : 'staging:migrate failed');
  process.exitCode = 1;
});
