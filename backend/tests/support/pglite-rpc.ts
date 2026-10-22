import type { PGlite } from '@electric-sql/pglite' with { 'resolution-mode': 'import' };
import type { RpcClient } from '../../src/sessions/store.js';

/**
 * Just enough of supabase-js over PGlite for the session store: `rpc` calls
 * the SQL function with named arguments, `from().select().eq().maybeSingle()`
 * reads one row. Errors come back as `{ code }`, as PostgREST returns them.
 */
export function pgliteRpc(db: PGlite): RpcClient {
  const ident = (s: string) => {
    if (!/^[a-z_][a-z0-9_]*$/.test(s)) throw new Error(`bad identifier ${s}`);
    return s;
  };
  return {
    async rpc(fn, args) {
      const names = Object.keys(args);
      const call = `${ident(fn)}(${names.map((n, i) => `${ident(n)} => $${i + 1}`).join(', ')})`;
      try {
        const { rows } = await db.query<{ result: unknown }>(`SELECT ${call} AS result`, names.map((n) => args[n]));
        return { data: rows[0]?.result ?? null, error: null };
      } catch (e) {
        return { data: null, error: { code: (e as { code?: string }).code ?? 'unknown' } };
      }
    },
    from(table) {
      return {
        select(columns) {
          return {
            eq(column, value) {
              return {
                async maybeSingle() {
                  try {
                    const cols = columns.split(',').map((c) => ident(c.trim())).join(', ');
                    const { rows } = await db.query<{ user_id: string }>(`SELECT ${cols} FROM ${ident(table)} WHERE ${ident(column)} = $1 LIMIT 1`, [value]);
                    return { data: rows[0] ?? null, error: null };
                  } catch (e) {
                    return { data: null, error: { code: (e as { code?: string }).code ?? 'unknown' } };
                  }
                },
              };
            },
          };
        },
      };
    },
  };
}
