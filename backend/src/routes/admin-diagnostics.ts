import { Router, type Request, type Response } from 'express';
import type { DiagnosticsStore, ReportRow } from '../diagnostics/store.js';

/**
 * The diagnostics viewer (DG.2), behind the admin secret (mounted by
 * mountAdmin). Reports are read only because a person chose to send one.
 *
 *   GET /admin/diagnostics?userId=&reference=&limit=   the list, newest first
 *   GET /admin/diagnostics/:reference                  one report: its row and bundle (the timeline)
 *   GET /admin/diagnostics/:reference/download         the bundle as a JSON file
 *
 * Filters are checked against strict patterns; a bad one is a 400, never a
 * query. Errors answer with a generic message; the detail is logged by code.
 */
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const REFERENCE = /^r-[0-9A-HJKMNP-TV-Z]{4}$/;

/** What the list shows: never the bundle, never a storage path. */
function summary(row: ReportRow) {
  return {
    reference: row.reference,
    userId: row.user_id,
    createdAt: row.created_at,
    expiresAt: row.expires_at,
    sizeBytes: row.size_bytes,
    appVersion: row.app_version,
    counts: row.counts,
  };
}

export function createAdminDiagnosticsRouter(store: DiagnosticsStore): Router {
  const router = Router();
  const failed = (res: Response, err: unknown) => {
    console.error(`[admin] diagnostics read failed (${err instanceof Error ? err.name : 'unknown'})`);
    res.status(500).json({ success: false, error: 'Failed to read diagnostics' });
  };

  router.get('/', async (req: Request, res: Response) => {
    const userId = typeof req.query.userId === 'string' ? req.query.userId : undefined;
    const reference = typeof req.query.reference === 'string' ? req.query.reference.toUpperCase().replace(/^R-/, 'r-') : undefined;
    const limit = typeof req.query.limit === 'string' ? Number(req.query.limit) : 100;
    if ((userId && !UUID.test(userId)) || (reference && !REFERENCE.test(reference)) || !Number.isInteger(limit) || limit < 1 || limit > 500) {
      res.status(400).json({ success: false, error: 'userId must be a UUID, reference like r-7KQ2, limit 1-500' });
      return;
    }
    try {
      const rows = await store.list({ ...(userId ? { userId } : {}), ...(reference ? { reference } : {}), limit });
      res.json({ success: true, data: rows.map(summary) });
    } catch (err) {
      failed(res, err);
    }
  });

  const one = (download: boolean) => async (req: Request, res: Response) => {
    const reference = String(req.params.reference ?? '').toUpperCase().replace(/^R-/, 'r-');
    if (!REFERENCE.test(reference)) {
      res.status(400).json({ success: false, error: 'reference like r-7KQ2' });
      return;
    }
    try {
      const found = await store.read(reference);
      if (!found) {
        res.status(404).json({ success: false, error: 'No report with that reference' });
        return;
      }
      if (download) {
        res.setHeader('Content-Type', 'application/json');
        res.setHeader('Content-Disposition', `attachment; filename="${found.row.reference}.json"`);
        res.send(found.body);
        return;
      }
      res.json({ success: true, data: { ...summary(found.row), report: JSON.parse(found.body) as unknown } });
    } catch (err) {
      failed(res, err);
    }
  };
  router.get('/:reference', one(false));
  router.get('/:reference/download', one(true));
  return router;
}
