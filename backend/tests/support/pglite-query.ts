import type { PGlite } from '@electric-sql/pglite' with { 'resolution-mode': 'import' };
import type { BriefDbClient, BriefFilter, BriefQueryResult } from '../../src/briefs/store.js';

/**
 * The supabase-js builder calls the brief store makes, answered by real SQL on
 * PGlite: `from().select().eq().lt().order().limit().maybeSingle()` and
 * `from().update().eq().select().maybeSingle()`. One code path in tests and in
 * production; a filter the store adds is a WHERE clause here, so a dropped
 * `eq('user_id')` shows up as another person's rows, never as a passing test.
 * Anything outside that subset throws.
 */
export function pgliteQuery(db: PGlite): BriefDbClient {
  const ident = (s: string) => {
    if (!/^[a-z_][a-z0-9_]*$/.test(s)) throw new Error(`pglite-query: bad identifier ${s}`);
    return `"${s}"`;
  };
  const columns = (cols: string) => cols.split(',').map((c) => ident(c.trim())).join(', ');
  const asResult = async (sql: string, params: unknown[], single: boolean): Promise<BriefQueryResult> => {
    try {
      const { rows } = await db.query<Record<string, unknown>>(sql, params);
      if (single) {
        if (rows.length > 1) return { data: null, error: { code: 'PGRST116', message: 'more than one row' } };
        return { data: rows[0] ?? null, error: null };
      }
      return { data: rows, error: null };
    } catch (e) {
      return { data: null, error: { code: (e as { code?: string }).code ?? 'unknown' } };
    }
  };

  function filter(table: string, cols: string): BriefFilter {
    const where: string[] = [];
    const params: unknown[] = [];
    const order: string[] = [];
    let limitN: number | null = null;
    const bind = (v: unknown) => { params.push(v); return `$${params.length}`; };
    const sql = () => `SELECT ${columns(cols)} FROM ${ident(table)}${where.length ? ` WHERE ${where.join(' AND ')}` : ''}${order.length ? ` ORDER BY ${order.join(', ')}` : ''}${limitN !== null ? ` LIMIT ${limitN}` : ''}`;
    const self: BriefFilter = {
      eq(c, v) { where.push(`${ident(c)} = ${bind(v)}`); return self; },
      lt(c, v) { where.push(`${ident(c)} < ${bind(v)}`); return self; },
      order(c, o) { order.push(`${ident(c)} ${o.ascending ? 'ASC' : 'DESC'}`); return self; },
      limit(n) { limitN = Math.max(0, Math.floor(n)); return self; },
      maybeSingle() { return asResult(sql(), params, true); },
      then(onFulfilled, onRejected) { return asResult(sql(), params, false).then(onFulfilled, onRejected); },
    };
    return self;
  }

  return {
    from(table) {
      return {
        select: (cols) => filter(table, cols),
        update(values) {
          return {
            eq(column, value) {
              return {
                select(cols) {
                  return {
                    maybeSingle() {
                      const keys = Object.keys(values);
                      const sets = keys.map((k, i) => `${ident(k)} = $${i + 1}`).join(', ');
                      return asResult(`UPDATE ${ident(table)} SET ${sets} WHERE ${ident(column)} = $${keys.length + 1} RETURNING ${columns(cols)}`, [...keys.map((k) => values[k]), value], true);
                    },
                  };
                },
              };
            },
          };
        },
      };
    },
  };
}
