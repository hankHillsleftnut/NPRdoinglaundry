/**
 * The one check every staging script runs first.
 *
 * Staging scripts write to a database (migrations, seeded accounts). The only
 * thing standing between them and production is which env file was loaded, so
 * they refuse to run unless that file says, in so many words, that it is
 * staging. `.env.staging.example` sets RETROSPECT_ENV=staging; production's
 * environment never does.
 */
export class NotStagingError extends Error {
  constructor() {
    super('Refusing to run: RETROSPECT_ENV is not "staging". Run through the npm script, which loads .env.staging.');
    this.name = 'NotStagingError';
  }
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
