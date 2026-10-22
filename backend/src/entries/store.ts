import type { AccessRpcClient } from '../access/store.js';

/**
 * Journal entries in the database (migration 022's functions): one call, one
 * transaction each. Rows come back as the door reads them; the door maps
 * content_type to the contract's kind and processing_status to reading.
 * Errors carry the database code only (a message can carry the words).
 */
export interface StoredEntry {
  id: string;
  contentType: string;
  text: string;
  /** The person's moment (content_date, else created_at), ISO. */
  at: string;
  /** YYYY-MM-DD in the resolved zone. */
  day: string;
  processingStatus: string | null;
  clientEntryId: string | null;
}

export type CreateOutcome =
  | { outcome: 'created'; entry: StoredEntry }
  | { outcome: 'replayed'; entry: StoredEntry }
  | { outcome: 'mismatch' }
  | { outcome: 'no_user' };

export type TodayOutcome =
  | { outcome: 'ok'; date: string; entries: StoredEntry[] }
  | { outcome: 'no_user' };

export interface EntryStore {
  /** `zone` is the validated X-Time-Zone header or null; the function stores it and falls back to the user's, then UTC. */
  create(input: {
    userId: string; clientEntryId: string; contentType: string; text: string; contentDateIso: string;
    requestHash: string; appVersion: string | null; zone: string | null; nowIso: string;
  }): Promise<CreateOutcome>;
  today(input: { userId: string; types: readonly string[]; zone: string | null; nowIso: string; limit: number }): Promise<TodayOutcome>;
}

function data<T>(fn: string, r: { data: unknown; error: { code?: string } | null }): T {
  if (r.error) throw new Error(`${fn} failed (${r.error.code ?? 'unknown'})`);
  return r.data as T;
}

const str = (v: unknown) => (typeof v === 'string' ? v : null);

function entry(fn: string, raw: unknown): StoredEntry {
  const r = (raw && typeof raw === 'object' ? raw : {}) as Record<string, unknown>;
  const id = str(r.id);
  const contentType = str(r.content_type);
  const text = str(r.content);
  const at = str(r.at);
  const day = str(r.day);
  if (!id || !contentType || text === null || !at || !day) throw new Error(`${fn}: malformed entry`);
  return {
    id, contentType, text, at: new Date(at).toISOString(), day, processingStatus: str(r.processing_status), clientEntryId: str(r.client_entry_id),
  };
}

export function supabaseEntryStore(db: AccessRpcClient): EntryStore {
  const call = async <T>(fn: string, args: Record<string, unknown>) => data<T>(fn, await db.rpc(fn, args));
  return {
    async create({ userId, clientEntryId, contentType, text, contentDateIso, requestHash, appVersion, zone, nowIso }) {
      const raw = await call<Record<string, unknown>>('entry_create', {
        p_user: userId, p_client_entry_id: clientEntryId, p_content_type: contentType, p_content: text, p_content_date: contentDateIso,
        p_request_hash: requestHash, p_app_version: appVersion, p_zone: zone, p_now: nowIso,
      });
      if (raw.outcome === 'created' || raw.outcome === 'replayed') return { outcome: raw.outcome, entry: entry('entry_create', raw.entry) };
      if (raw.outcome === 'no_user') return { outcome: 'no_user' };
      return { outcome: 'mismatch' };
    },
    async today({ userId, types, zone, nowIso, limit }) {
      const raw = await call<Record<string, unknown>>('entries_today', { p_user: userId, p_types: [...types], p_zone: zone, p_now: nowIso, p_limit: limit });
      if (raw.outcome === 'no_user') return { outcome: 'no_user' };
      const date = str(raw.date);
      if (!date || !Array.isArray(raw.entries)) throw new Error('entries_today: malformed answer');
      return { outcome: 'ok', date, entries: raw.entries.map((e) => entry('entries_today', e)) };
    },
  };
}
