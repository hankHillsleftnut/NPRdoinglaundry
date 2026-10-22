import { createHash, randomInt } from 'node:crypto';
import { countsOf, type DiagnosticsReport } from './schema.js';

/**
 * Where diagnostics reports live (DG.1): the bundle in the private
 * `diagnostics` bucket under the sender's id, one row in diagnostic_reports
 * for listing, kept 30 days.
 *
 * Saving is idempotent on the report id: the same person sending the same
 * report again gets the same reference and stores nothing new; the same id
 * with a different bundle (or from someone else) is refused.
 */
export const REPORT_TTL_DAYS = 30;
const CROCKFORD = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

export function newReference(pick: (n: number) => number = randomInt): string {
  let out = 'r-';
  for (let i = 0; i < 4; i++) out += CROCKFORD[pick(CROCKFORD.length)];
  return out;
}

export interface ReportRow {
  id: string;
  user_id: string;
  reference: string;
  body_hash: string;
  storage_path: string;
  size_bytes: number;
  counts: Record<string, number | boolean>;
  app_version: string | null;
  created_at: string;
  expires_at: string;
}

/** The two things a store needs: a table and a bucket. Real ones wrap supabase-js; tests use memory. */
export interface DiagnosticsBackend {
  /** Inserts a row; `conflict` names the unique column that clashed, if any. */
  insert(row: ReportRow): Promise<{ conflict: 'id' | 'reference' | null }>;
  findById(id: string): Promise<ReportRow | null>;
  upload(path: string, body: string): Promise<void>;
  download(path: string): Promise<string | null>;
  remove(paths: string[]): Promise<void>;
  list(filter: { userId?: string; reference?: string; limit: number }): Promise<ReportRow[]>;
  expired(nowIso: string, limit: number): Promise<ReportRow[]>;
  forUser(userId: string): Promise<ReportRow[]>;
  deleteRows(ids: string[]): Promise<void>;
}

/** What a save stored, for the answer and the door log: sizes and counts, never content. */
export interface SavedReport {
  reference: string;
  sizeBytes: number;
  counts: ReturnType<typeof countsOf>;
}

export type SaveResult =
  | ({ outcome: 'stored' | 'replayed' } & SavedReport)
  | { outcome: 'mismatch' };

export function bodyHash(body: string): string {
  return createHash('sha256').update(body, 'utf8').digest('hex');
}

export function createDiagnosticsStore(backend: DiagnosticsBackend, pick?: (n: number) => number) {
  return {
    async save(userId: string, report: DiagnosticsReport, nowMs: number): Promise<SaveResult> {
      const body = JSON.stringify(report);
      const hash = bodyHash(body);
      const path = `${userId}/${report.reportId}.json`;
      const sizeBytes = Buffer.byteLength(body, 'utf8');
      const counts = countsOf(report);

      // A retry of a report we already have. The bundle is written again
      // (upsert, same bytes): if an earlier attempt's upload failed and its row
      // could not be removed, the retry still leaves a complete report.
      const replay = async (row: ReportRow): Promise<SaveResult> => {
        if (row.user_id !== userId || row.body_hash !== hash) return { outcome: 'mismatch' };
        await backend.upload(path, body);
        return { outcome: 'replayed', reference: row.reference, sizeBytes, counts };
      };

      const existing = await backend.findById(report.reportId);
      if (existing) return replay(existing);

      // The row first, then the bundle: every stored file has a row, so the
      // 30-day purge and deleteFor(userId) always find it. A failed upload
      // takes its row back out, so the retry starts clean.
      for (let attempt = 0; attempt < 5; attempt++) {
        const row: ReportRow = {
          id: report.reportId, user_id: userId, reference: newReference(pick), body_hash: hash, storage_path: path,
          size_bytes: sizeBytes, counts, app_version: report.environment.appVersion,
          created_at: new Date(nowMs).toISOString(), expires_at: new Date(nowMs + REPORT_TTL_DAYS * 86_400_000).toISOString(),
        };
        const { conflict } = await backend.insert(row);
        if (conflict === 'id') {
          // Two sends of one report raced; the other won.
          const winner = await backend.findById(report.reportId);
          if (winner) return replay(winner);
          // The other send's upload failed and took its row back out: a retry starts clean.
          throw new Error('diagnostics: a racing send of this report failed');
        }
        if (conflict === 'reference') continue; // a reference already in use: draw another
        try {
          await backend.upload(path, body);
        } catch (err) {
          // If this fails too, the row stays without a file until it expires;
          // a retry of the report writes the file (replay, above).
          await backend.deleteRows([row.id]).catch(() => undefined);
          throw err;
        }
        return { outcome: 'stored', reference: row.reference, sizeBytes, counts };
      }
      throw new Error('diagnostics: no free reference after 5 tries');
    },

    list: (filter: { userId?: string; reference?: string; limit?: number }) => backend.list({ ...filter, limit: Math.min(filter.limit ?? 100, 500) }),

    /** One report's bundle, for the admin viewer. */
    async read(reference: string): Promise<{ row: ReportRow; body: string } | null> {
      const [row] = await backend.list({ reference, limit: 1 });
      if (!row) return null;
      const body = await backend.download(row.storage_path);
      return body === null ? null : { row, body };
    },

    /** The 30-day rule: removes expired bundles, then their rows. Returns how many went. */
    async purgeExpired(nowMs: number): Promise<number> {
      let removed = 0;
      for (;;) {
        const batch = await backend.expired(new Date(nowMs).toISOString(), 100);
        if (batch.length === 0) return removed;
        await backend.remove(batch.map((r) => r.storage_path));
        await backend.deleteRows(batch.map((r) => r.id));
        removed += batch.length;
      }
    },

    /** For delete-my-data and account deletion (BE0.6-BE0.8): the bucket doesn't cascade. */
    async deleteFor(userId: string): Promise<number> {
      const rows = await backend.forUser(userId);
      if (rows.length === 0) return 0;
      await backend.remove(rows.map((r) => r.storage_path));
      await backend.deleteRows(rows.map((r) => r.id));
      return rows.length;
    },
  };
}

export type DiagnosticsStore = ReturnType<typeof createDiagnosticsStore>;
