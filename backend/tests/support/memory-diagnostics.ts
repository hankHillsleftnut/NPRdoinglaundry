import type { DiagnosticsBackend, ReportRow } from '../../src/diagnostics/store.js';

/** diagnostic_reports and the private bucket, in memory, with the table's two unique keys. */
export function memoryDiagnostics() {
  const rows = new Map<string, ReportRow>();
  const files = new Map<string, string>();
  const backend: DiagnosticsBackend = {
    async insert(row) {
      if (rows.has(row.id)) return { conflict: 'id' };
      if ([...rows.values()].some((r) => r.reference === row.reference)) return { conflict: 'reference' };
      rows.set(row.id, { ...row });
      return { conflict: null };
    },
    async findById(id) { return rows.get(id) ?? null; },
    async upload(path, body) { files.set(path, body); },
    async download(path) { return files.get(path) ?? null; },
    async remove(paths) { for (const p of paths) files.delete(p); },
    async list(filter) {
      return [...rows.values()]
        .filter((r) => (!filter.userId || r.user_id === filter.userId) && (!filter.reference || r.reference === filter.reference))
        .sort((a, b) => b.created_at.localeCompare(a.created_at))
        .slice(0, filter.limit);
    },
    async expired(nowIso, limit) { return [...rows.values()].filter((r) => r.expires_at < nowIso).slice(0, limit); },
    async forUser(userId) { return [...rows.values()].filter((r) => r.user_id === userId); },
    async deleteRows(ids) { for (const id of ids) rows.delete(id); },
  };
  return { backend, rows, files };
}
