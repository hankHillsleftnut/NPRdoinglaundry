import { readFileSync } from 'node:fs';
import { basename } from 'node:path';
import dotenv from 'dotenv';

/**
 * The checks every staging script runs before it touches a database.
 *
 * Staging scripts write (migrations, seeded accounts), so three things stand
 * between them and production:
 *
 * 1. loadStagingEnv: the script reads .env.staging itself, overriding anything
 *    already in the shell. `node --env-file` and plain dotenv never override, so
 *    an exported production DATABASE_URL would otherwise win silently.
 * 2. assertStaging: that file must say RETROSPECT_ENV=staging.
 * 3. A check on the database itself (migrations.ts assertOnlyTestUsers, and the
 *    seed's nonTestUserCount): a database holding any user who isn't a
 *    `dev-test-user:` account is refused, whatever the env says.
 */
export class NotStagingError extends Error {
  constructor(reason = 'RETROSPECT_ENV is not "staging"') {
    super(`Refusing to run: ${reason}.`);
    this.name = 'NotStagingError';
  }
}

/** Reads the staging env file into `env`, its values winning over the shell's. */
export function loadStagingEnv(file: string, env: NodeJS.ProcessEnv = process.env): void {
  const result = dotenv.config({ path: file, override: true, processEnv: env as dotenv.DotenvPopulateInput, quiet: true });
  if (result.error) throw new Error(`could not read ${basename(file)}; copy .env.staging.example and fill it in`);
}

export function assertStaging(env: NodeJS.ProcessEnv): void {
  if (env.RETROSPECT_ENV !== 'staging') throw new NotStagingError();
}

/** Reads a variable the script needs, naming it (never its value) when missing. */
export function requireVar(env: NodeJS.ProcessEnv, name: string): string {
  const value = env[name];
  if (!value) throw new Error(`${name} is not set in .env.staging`);
  return value;
}

/**
 * TLS for the direct Postgres connection, verified against Supabase's CA
 * certificate (Supabase dashboard → Database settings → SSL configuration →
 * download certificate). Supabase signs its database certificates with its own
 * root, so the system store can't verify them, and an unverified connection
 * could be intercepted.
 */
export function postgresTls(env: NodeJS.ProcessEnv, read: (path: string) => string = (p) => readFileSync(p, 'utf8')) {
  const path = env.DATABASE_CA_CERT;
  if (!path) {
    throw new Error('DATABASE_CA_CERT is not set: point it at the Supabase CA certificate (see docs/team/staging.md)');
  }
  return { ca: read(path), rejectUnauthorized: true };
}
