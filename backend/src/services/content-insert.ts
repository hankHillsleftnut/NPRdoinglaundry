/**
 * Storing an upload, once.
 *
 * Separated from the route so it can be tested without a database: the client
 * is passed in, and the three outcomes that matter -- stored, already there, and
 * "the column does not exist yet" -- can each be produced on demand.
 */
import { deriveDedupKey, type DedupInput, type DedupStrategy } from './dedup-key.js';

/** Postgres: a row with this key already exists. */
const UNIQUE_VIOLATION = '23505';
/** Postgres: the column being written does not exist. */
const UNDEFINED_COLUMN = '42703';

/** The subset of the Supabase client this module uses. */
export interface InsertClient {
  from(table: string): {
    insert(row: Record<string, unknown>): {
      select(columns: string): {
        single(): PromiseLike<{ data: { id: string } | null; error: { code?: string; message: string } | null }>;
      };
    };
    select(columns: string): {
      eq(column: string, value: unknown): {
        eq(column: string, value: unknown): {
          maybeSingle(): PromiseLike<{ data: { id: string } | null; error: { message: string } | null }>;
        };
      };
    };
  };
}

export type InsertOutcome =
  | { kind: 'inserted'; id: string; strategy: DedupStrategy | null }
  | { kind: 'duplicate'; id: string; strategy: DedupStrategy };

/**
 * Store a raw_content row, or report the one that is already there.
 *
 * Three behaviours, each covered by a test:
 *
 * 1. NEW -- the row is inserted with its dedup key, and the caller starts
 *    ingestion.
 *
 * 2. DUPLICATE -- the unique index rejects it. We fetch the row that won and
 *    return it, and the caller must NOT start ingestion. That skip is most of
 *    the value: 188 copies of one health summary meant 188 ingest runs.
 *    Uniqueness is enforced by the index rather than by checking first, because
 *    a check-then-insert lets two concurrent retries from a flaky connection
 *    both see "not there yet" and both write.
 *
 * 3. MIGRATION NOT APPLIED -- the dedup columns do not exist yet. Migrations in
 *    this project are applied by hand, so this route can easily reach production
 *    before migration 117 does. Rather than failing every upload, it stores the
 *    row exactly as it did before this change and logs once. Deploy order stops
 *    mattering, which is the point: a deduplication feature must never be able
 *    to break uploading.
 *
 * Onboarding profiles are deliberately left unkeyed for now. They are one per
 * user and the latest should replace the earlier one, but replacing a row in
 * place keeps its id -- and extraction skips any id it has already processed,
 * so the new profile would never be read. That needs its own change; until then
 * onboarding behaves exactly as before.
 */
export async function insertRawContent(
  client: InsertClient,
  table: string,
  row: Record<string, unknown> & { user_id: string },
  dedup: DedupInput,
): Promise<InsertOutcome> {
  const derived = deriveDedupKey(dedup);
  const enforce = derived.dedupClass !== 'singleton';

  const keyed = enforce
    ? { ...row, dedup_key: derived.key, dedup_strategy: derived.strategy }
    : row;

  const first = await client.from(table).insert(keyed).select('id').single();

  if (!first.error && first.data) {
    return { kind: 'inserted', id: first.data.id, strategy: enforce ? derived.strategy : null };
  }

  if (first.error?.code === UNIQUE_VIOLATION && enforce) {
    const winner = await client
      .from(table)
      .select('id')
      .eq('user_id', row.user_id)
      .eq('dedup_key', derived.key)
      .maybeSingle();
    if (winner.data) {
      return { kind: 'duplicate', id: winner.data.id, strategy: derived.strategy };
    }
    // The winner vanished between the conflict and the read -- deleted in the
    // gap. Vanishingly rare; surface it rather than guess.
    throw new Error(`dedup conflict but no existing row found for key ${derived.key}`);
  }

  if (first.error?.code === UNDEFINED_COLUMN && enforce) {
    warnMigrationMissingOnce(first.error.message);
    const fallback = await client.from(table).insert(row).select('id').single();
    if (!fallback.error && fallback.data) {
      return { kind: 'inserted', id: fallback.data.id, strategy: null };
    }
    throw new Error(fallback.error?.message ?? 'insert failed');
  }

  throw new Error(first.error?.message ?? 'insert failed');
}

let warnedMissingMigration = false;

function warnMigrationMissingOnce(detail: string) {
  if (warnedMissingMigration) return;
  warnedMissingMigration = true;
  console.warn(
    '[content] dedup_key column missing -- migration 117 not applied. ' +
      `Uploads are stored without deduplication until it is. (${detail})`,
  );
}

/** Test-only: reset the once-per-process warning. */
export function resetMissingMigrationWarningForTests() {
  warnedMissingMigration = false;
}
