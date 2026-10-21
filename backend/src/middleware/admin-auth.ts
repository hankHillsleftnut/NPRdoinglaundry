import { createHash, timingSafeEqual } from 'node:crypto';
import type { NextFunction, Request, RequestHandler, Response } from 'express';

/**
 * The admin secret check.
 *
 * - Header only (`x-admin-secret`). A `?secret=` query string ends up in
 *   access logs and browser history, so it is ignored.
 * - Constant time. Both sides are hashed first, so the comparison is always
 *   over two 32-byte buffers and leaks neither the secret's content nor its
 *   length.
 * - There is no default secret: without ADMIN_SECRET the admin routes are not
 *   mounted at all (see mountAdmin in routes/admin-mount.ts).
 */
export function adminSecretMatches(
  provided: string,
  expected: string,
  compare: (a: Buffer, b: Buffer) => boolean = timingSafeEqual,
): boolean {
  const digest = (s: string) => createHash('sha256').update(s, 'utf8').digest();
  return compare(digest(provided), digest(expected));
}

export function makeAdminAuth(expected: string): RequestHandler {
  return (req: Request, res: Response, next: NextFunction): void => {
    const provided = req.header('x-admin-secret');
    if (!provided || !adminSecretMatches(provided, expected)) {
      res.status(403).json({ success: false, error: 'Invalid admin secret' });
      return;
    }
    next();
  };
}
