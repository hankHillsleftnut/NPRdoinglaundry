/**
 * A real Postgres for tests (PGlite: Postgres compiled to WebAssembly, in
 * process, no server), built the way staging is (scripts/staging/migrations.ts):
 * the combined base schema, then every numbered migration after 003.
 *
 * service_role is set up as Supabase sets it up (it bypasses row-level security
 * and gets every privilege a migration doesn't revoke), so a test that runs
 * `SET ROLE service_role` sees production's permissions, not a superuser's.
 */
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import type { PGlite } from '@electric-sql/pglite' with { 'resolution-mode': 'import' };
import { BASE_COVERS_THROUGH, BASE_FILE, numberedFiles } from '../../scripts/staging/migrations.js';

export type { PGlite };

const SUPABASE_DIR = join(__dirname, '..', '..', '..', 'supabase');

const SUPABASE_ENVIRONMENT = `
  CREATE SCHEMA IF NOT EXISTS auth;
  CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS 'SELECT NULL::uuid';
  DO $$ BEGIN CREATE ROLE anon; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
  DO $$ BEGIN CREATE ROLE authenticated; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
  DO $$ BEGIN CREATE ROLE service_role; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
  ALTER ROLE service_role BYPASSRLS;
  GRANT USAGE ON SCHEMA public TO service_role;
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO service_role;
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO service_role;
  -- Supabase Storage's bucket table, as far as migrations touch it (019 creates a private bucket).
  CREATE SCHEMA IF NOT EXISTS storage;
  CREATE TABLE IF NOT EXISTS storage.buckets (
    id text PRIMARY KEY, name text NOT NULL, public boolean DEFAULT FALSE, file_size_limit bigint
  );
`;

/**
 * A database built the way staging is. `before` stops short of one migration
 * (e.g. to put rows in place and then apply it with applyMigration).
 */
export async function freshDatabase(opts: { before?: string } = {}): Promise<PGlite> {
  // Dynamic imports: PGlite and its extensions are ESM-only; this repo is CommonJS.
  const { PGlite } = await import('@electric-sql/pglite');
  const { uuid_ossp } = await import('@electric-sql/pglite/contrib/uuid_ossp');
  const { vector } = await import('@electric-sql/pglite-pgvector');
  const db = new PGlite({ extensions: { uuid_ossp, vector } });
  await db.exec(SUPABASE_ENVIRONMENT);
  await db.exec(readFileSync(join(SUPABASE_DIR, BASE_FILE), 'utf8'));
  for (const file of numberedFiles(readdirSync(join(SUPABASE_DIR, 'migrations')))) {
    if (file <= BASE_COVERS_THROUGH) continue;
    if (opts.before && file >= opts.before) break;
    await db.exec(readFileSync(join(SUPABASE_DIR, 'migrations', file), 'utf8'));
  }
  return db;
}

/** Applies one numbered migration file (after freshDatabase({ before })). */
export async function applyMigration(db: PGlite, file: string): Promise<void> {
  await db.exec(readFileSync(join(SUPABASE_DIR, 'migrations', file), 'utf8'));
}

let users = 0;

/** A user with a distinct, deterministic Apple subject (a counter, no randomness). */
export async function insertUser(db: PGlite, appleUserId = `apple-test-${++users}`): Promise<string> {
  const { rows } = await db.query<{ id: string }>(`INSERT INTO users (apple_user_id) VALUES ($1) RETURNING id`, [appleUserId]);
  return rows[0]!.id;
}

/** Runs `fn` as service_role, as the backend does in production. */
export async function asServiceRole<T>(db: PGlite, fn: () => Promise<T>): Promise<T> {
  await db.exec('SET ROLE service_role');
  try {
    return await fn();
  } finally {
    await db.exec('RESET ROLE');
  }
}
