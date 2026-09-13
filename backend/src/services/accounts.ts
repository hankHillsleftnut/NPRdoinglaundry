/**
 * Test accounts.
 *
 * A `test` account is a founder-owned throwaway that lives in the PRODUCTION
 * database and uses the REAL integrations — that is the whole point: it has to
 * be able to exercise a genuine Google/Gmail sync against production code.
 *
 * What it must never do is show up in anything that treats users in aggregate,
 * or cause money to be spent on its behalf by a batch the founder did not
 * personally trigger. So the rule is deliberately narrow:
 *
 *   ALLOWED   — every normal single-user request the account makes itself
 *               (sign in, upload content, connect Gmail, run its own pipeline,
 *               generate its own podcast). It is a real user to itself.
 *   EXCLUDED  — aggregate counts and analytics, admin user listings, error
 *               telemetry rollups, revenue/billing reporting, and any
 *               "for every user" batch/cron fan-out.
 *
 * This module is the single chokepoint for that rule. Do not scatter
 * `account_type === 'test'` checks through routes — add the path here.
 */

import { supabaseAdmin, Tables } from '../utils/supabase.js';

export type AccountType = 'real' | 'test';

export const ACCOUNT_TYPE_REAL: AccountType = 'real';
export const ACCOUNT_TYPE_TEST: AccountType = 'test';

/** Anything that is not explicitly 'test' is treated as a real user. */
export function normalizeAccountType(value: unknown): AccountType {
  return value === ACCOUNT_TYPE_TEST ? ACCOUNT_TYPE_TEST : ACCOUNT_TYPE_REAL;
}

/** The guard. Accepts a row, an AuthUser, or a bare account_type string. */
export function isTestAccount(
  subject: { accountType?: unknown; account_type?: unknown } | string | null | undefined
): boolean {
  if (subject == null) return false;
  if (typeof subject === 'string') return subject === ACCOUNT_TYPE_TEST;
  const raw =
    subject.accountType !== undefined ? subject.accountType : subject.account_type;
  return raw === ACCOUNT_TYPE_TEST;
}

/**
 * Apply the exclusion to a query against the `users` table itself.
 *
 *   excludeTestAccounts(supabaseAdmin.from(Tables.USERS).select('id'))
 *
 * Generic over the builder type so it composes with any PostgREST chain
 * without importing Supabase's internal filter generics.
 */
export function excludeTestAccounts<T>(query: T): T {
  // Cast rather than constraining T structurally: PostgREST's builder type is
  // self-referential, and a `T extends { eq(...): T }` bound sends tsc into an
  // "excessively deep" instantiation. The cast is checked by the call sites,
  // which always pass a users-table builder.
  return (query as unknown as { eq(column: string, value: unknown): T }).eq(
    'account_type',
    ACCOUNT_TYPE_REAL
  );
}

/**
 * Every TEST user's id.
 *
 * Deliberately the test list, not the real list. Tables like raw_content and
 * pipeline_runs carry `user_id` but not `account_type`, so the exclusion has to
 * name ids — and supabase-js serialises `.in()` into the GET query string. A
 * real-user list is unbounded and would blow past the ~8KB request-line limit
 * (HTTP 414) somewhere around a couple hundred users, silently breaking
 * /admin/stats as the product grew. The test-account list is a handful by
 * construction, so filtering by its complement stays small forever.
 *
 * Fails CLOSED: a failed read throws rather than returning [] (which would
 * silently skip the filter and leak test data into aggregates).
 */
export async function listTestUserIds(): Promise<string[]> {
  const { data, error } = await supabaseAdmin
    .from(Tables.USERS)
    .select('id')
    .eq('account_type', ACCOUNT_TYPE_TEST);

  if (error) {
    throw new Error(`Failed to load test user ids: ${error.message}`);
  }

  return ((data ?? []) as { id: string }[]).map((row) => row.id);
}

/** Count of real accounts, without materialising their ids. */
export async function countRealAccounts(): Promise<number> {
  const { count, error } = await excludeTestAccounts(
    supabaseAdmin.from(Tables.USERS).select('id', { count: 'exact', head: true })
  );

  if (error) throw new Error(`Failed to count real accounts: ${error.message}`);
  return count ?? 0;
}

/**
 * Scope a query on a user-scoped table to real accounts only, by excluding the
 * test ids. Use for every aggregate read that fans out across users.
 *
 * SYNCHRONOUS on purpose — pass the ids in from `listTestUserIds()`. A
 * `Promise<Builder>` would be a trap here: PostgREST builders are thenable, so
 * `await scopeToRealAccounts(q)` would execute the query instead of returning
 * it, and the caller's later `.eq()`/`.limit()` would fail at runtime.
 *
 * With no test accounts the query is returned untouched — correct, because the
 * complement of the empty set is everyone.
 */
export function scopeToRealAccounts<T>(
  query: T,
  testIds: readonly string[],
  userIdColumn = 'user_id'
): T {
  if (testIds.length === 0) return query;

  return (query as unknown as {
    not(column: string, operator: string, value: string): T;
  }).not(userIdColumn, 'in', `(${testIds.join(',')})`);
}

/**
 * Count rows in a user-scoped table, excluding test accounts.
 * Used by /admin/stats so one helper owns the "aggregate count" shape.
 */
export async function countForRealAccounts(
  table: string,
  userIdColumn = 'user_id',
  /** Pass a pre-fetched list to avoid re-reading `users` once per table. */
  knownTestIds?: readonly string[]
): Promise<number> {
  const testIds = knownTestIds ?? (await listTestUserIds());

  const { count, error } = await scopeToRealAccounts(
    supabaseAdmin.from(table).select('id', { count: 'exact', head: true }),
    testIds,
    userIdColumn
  );

  if (error) throw new Error(`Failed to count ${table}: ${error.message}`);
  return count ?? 0;
}

/** Read one user's account type. Returns 'real' if the user is unknown. */
export async function getAccountType(userId: string): Promise<AccountType> {
  const { data, error } = await supabaseAdmin
    .from(Tables.USERS)
    .select('account_type')
    .eq('id', userId)
    .single();

  if (error || !data) return ACCOUNT_TYPE_REAL;
  return normalizeAccountType((data as { account_type?: unknown }).account_type);
}

/**
 * Guard for batch / cron fan-out that spends money (LLM calls, TTS, podcast
 * generation, email/push sends). Filters a user list down to real accounts.
 *
 * NOTE: this is for work the SYSTEM initiates across many users. Do not use it
 * on a user-initiated request — a test account generating its own podcast is
 * exactly the behaviour we want to be able to exercise in production.
 *
 * Currently UNUSED in this repo on purpose: `index.ts` disables the legacy
 * backend crons and the surviving fan-out lives in the agent service, behind
 * `agent-client.ts`. It is kept as the contract that fan-out is supposed to
 * honour, and as the helper the agent-side work should mirror.
 */
export function filterBatchRecipients<T extends { account_type?: unknown; accountType?: unknown }>(
  users: readonly T[]
): T[] {
  return users.filter((u) => !isTestAccount(u));
}
