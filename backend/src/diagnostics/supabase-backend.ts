import type { SupabaseClient } from '@supabase/supabase-js';
import type { DiagnosticsBackend, ReportRow } from './store.js';

const TABLE = 'diagnostic_reports';
const BUCKET = 'diagnostics';
const COLUMNS = 'id, user_id, reference, body_hash, storage_path, size_bytes, counts, app_version, created_at, expires_at';
const UNIQUE_VIOLATION = '23505';

/** Errors carry the code only: a database or storage message can carry row values. */
function fail(what: string, error: { code?: string; statusCode?: string; name?: string }): never {
  throw new Error(`diagnostics ${what} failed (${error.code ?? error.statusCode ?? error.name ?? 'unknown'})`);
}

export function supabaseDiagnosticsBackend(db: SupabaseClient): DiagnosticsBackend {
  return {
    async insert(row) {
      const { error } = await db.from(TABLE).insert(row);
      if (!error) return { conflict: null };
      if (error.code === UNIQUE_VIOLATION) {
        return { conflict: /reference/.test(error.message ?? '') ? 'reference' : 'id' };
      }
      return fail('insert', error);
    },
    async findById(id) {
      const { data, error } = await db.from(TABLE).select(COLUMNS).eq('id', id).maybeSingle();
      if (error) fail('lookup', error);
      return (data as ReportRow | null) ?? null;
    },
    async upload(path, body) {
      const { error } = await db.storage.from(BUCKET).upload(path, body, { contentType: 'application/json', upsert: true });
      if (error) fail('upload', error);
    },
    async download(path) {
      const { data, error } = await db.storage.from(BUCKET).download(path);
      if (error) return null;
      return data ? await data.text() : null;
    },
    async remove(paths) {
      for (let i = 0; i < paths.length; i += 100) {
        const { error } = await db.storage.from(BUCKET).remove(paths.slice(i, i + 100));
        if (error) fail('remove', error);
      }
    },
    async list(filter) {
      let q = db.from(TABLE).select(COLUMNS).order('created_at', { ascending: false }).limit(filter.limit);
      if (filter.userId) q = q.eq('user_id', filter.userId);
      if (filter.reference) q = q.eq('reference', filter.reference);
      const { data, error } = await q;
      if (error) fail('list', error);
      return (data ?? []) as ReportRow[];
    },
    async expired(nowIso, limit) {
      const { data, error } = await db.from(TABLE).select(COLUMNS).lt('expires_at', nowIso).limit(limit);
      if (error) fail('expiry scan', error);
      return (data ?? []) as ReportRow[];
    },
    async forUser(userId) {
      const { data, error } = await db.from(TABLE).select(COLUMNS).eq('user_id', userId);
      if (error) fail('user scan', error);
      return (data ?? []) as ReportRow[];
    },
    async deleteRows(ids) {
      for (let i = 0; i < ids.length; i += 100) {
        const { error } = await db.from(TABLE).delete().in('id', ids.slice(i, i + 100));
        if (error) fail('delete', error);
      }
    },
  };
}
