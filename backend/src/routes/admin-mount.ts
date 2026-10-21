import path from 'path';
import type { Express } from 'express';
import { makeAdminAuth } from '../middleware/admin-auth.js';
import { adminRouter } from './admin.js';

/**
 * Mounts `/admin` and `/dashboard` only when an admin secret is configured.
 * Admin exposes every user's content and can start paid runs, so with no
 * secret there is no admin at all, rather than a guessable default.
 * Returns whether it mounted.
 */
export function mountAdmin(app: Express, opts: { secret: string | null; publicDir: string }): boolean {
  if (!opts.secret) {
    console.warn('[admin] ADMIN_SECRET is not set: /admin and /dashboard are not mounted.');
    return false;
  }
  app.get('/dashboard', (_req, res) => {
    res.sendFile(path.join(opts.publicDir, 'dashboard.html'));
  });
  app.use('/admin', makeAdminAuth(opts.secret), adminRouter);
  return true;
}
