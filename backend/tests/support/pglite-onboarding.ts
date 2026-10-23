import type { PGlite } from '@electric-sql/pglite' with { 'resolution-mode': 'import' };
import type { OnboardingDbClient, OnboardingFilter, OnboardingQueryResult, OnboardingUpdate } from '../../src/onboarding/store.js';

/**
 * The supabase-js builder calls the onboarding store makes (and
 * insertRawContent under it), answered by real SQL on PGlite:
 *   from().insert().select().single()
 *   from().select().eq()...order().limit() / .maybeSingle()
 *   from().update().eq()...select().maybeSingle()
 * Every `eq` is a WHERE clause, so a dropped `eq('user_id')` shows up as
 * another person's rows and a dropped `eq('access', 'approved')` as a staff
 * person made a member, never as a passing test. Anything else throws.
 */
export function pgliteOnboarding(db: PGlite): OnboardingDbClient {
  const ident = (s: string) => {
    if (!/^[a-z_][a-z0-9_]*$/.test(s)) throw new Error(`pglite-onboarding: bad identifier ${s}`);
    return `"${s}"`;
  };
  const columns = (cols: string) => cols.split(',').map((c) => ident(c.trim())).join(', ');
  // jsonb columns take objects; everything else as given.
  const param = (v: unknown) => (v !== null && typeof v === 'object' && !(v instanceof Date) ? JSON.stringify(v) : v);
  const run = async (sql: string, params: unknown[], single: boolean): Promise<OnboardingQueryResult> => {
    try {
      const { rows } = await db.query<Record<string, unknown>>(sql, params);
      if (single) {
        if (rows.length > 1) return { data: null, error: { code: 'PGRST116' } };
        return { data: rows[0] ?? null, error: null };
      }
      return { data: rows, error: null };
    } catch (e) {
      return { data: null, error: { code: (e as { code?: string }).code ?? 'unknown' } };
    }
  };

  function filter(table: string, cols: string): OnboardingFilter {
    const where: string[] = [];
    const params: unknown[] = [];
    const order: string[] = [];
    let limitN: number | null = null;
    const sql = () => `SELECT ${columns(cols)} FROM ${ident(table)}${where.length ? ` WHERE ${where.join(' AND ')}` : ''}${order.length ? ` ORDER BY ${order.join(', ')}` : ''}${limitN !== null ? ` LIMIT ${limitN}` : ''}`;
    const self: OnboardingFilter = {
      eq(c, v) { params.push(param(v)); where.push(`${ident(c)} = $${params.length}`); return self; },
      order(c, o) { order.push(`${ident(c)} ${o.ascending ? 'ASC' : 'DESC'}`); return self; },
      limit(n) { limitN = Math.max(0, Math.floor(n)); return self; },
      maybeSingle() { return run(sql(), params, true); },
      then(onFulfilled, onRejected) { return run(sql(), params, false).then(onFulfilled, onRejected); },
    };
    return self;
  }

  function update(table: string, values: Record<string, unknown>): OnboardingUpdate {
    const keys = Object.keys(values);
    const params: unknown[] = keys.map((k) => param(values[k]));
    const where: string[] = [];
    const self: OnboardingUpdate = {
      eq(c, v) { params.push(param(v)); where.push(`${ident(c)} = $${params.length}`); return self; },
      select(cols) {
        return {
          maybeSingle() {
            if (where.length === 0) throw new Error('pglite-onboarding: an update without a filter');
            const sets = keys.map((k, i) => `${ident(k)} = $${i + 1}`).join(', ');
            return run(`UPDATE ${ident(table)} SET ${sets} WHERE ${where.join(' AND ')} RETURNING ${columns(cols)}`, params, true);
          },
        };
      },
    };
    return self;
  }

  return {
    from(table) {
      return {
        insert(row) {
          return {
            select(cols) {
              return {
                async single() {
                  const keys = Object.keys(row);
                  try {
                    const { rows } = await db.query<{ id: string }>(
                      `INSERT INTO ${ident(table)} (${keys.map(ident).join(', ')}) VALUES (${keys.map((_k, i) => `$${i + 1}`).join(', ')}) RETURNING ${columns(cols)}`,
                      keys.map((k) => param(row[k])),
                    );
                    return { data: rows[0] ?? null, error: null };
                  } catch (e) {
                    const err = e as { code?: string; message?: string };
                    return { data: null, error: { code: err.code ?? 'unknown', message: err.message ?? 'insert failed' } };
                  }
                },
              };
            },
          };
        },
        select: (cols) => filter(table, cols),
        update: (values) => update(table, values),
      };
    },
  };
}

/**
 * The brain's raw_content columns the answers doors write (agent migrations
 * 115 authorship and 117 dedup_key, verbatim in type and index), for a backend
 * test database: the backend's own migrations never create them.
 */
export const AGENT_RAW_CONTENT_COLUMNS_SQL = `
  ALTER TABLE raw_content ADD COLUMN IF NOT EXISTS authorship TEXT;
  ALTER TABLE raw_content ADD COLUMN IF NOT EXISTS dedup_key TEXT;
  ALTER TABLE raw_content ADD COLUMN IF NOT EXISTS dedup_strategy TEXT
    CHECK (dedup_strategy IS NULL OR dedup_strategy IN ('explicit_key', 'provider_object_id', 'sync_day', 'content_hash', 'content_hash_day', 'singleton'));
  CREATE UNIQUE INDEX IF NOT EXISTS raw_content_user_dedup_key_uniq ON raw_content (user_id, dedup_key) WHERE dedup_key IS NOT NULL;
`;

export async function createAgentRawContentColumns(db: PGlite): Promise<void> {
  await db.exec(AGENT_RAW_CONTENT_COLUMNS_SQL);
}
