import { randomUUID } from 'node:crypto';
import type { Request, RequestHandler, Response } from 'express';
import { z } from 'zod';
import type { AuthUser } from '../types/index.js';

/**
 * Who `POST /auth/dev/test-user` signs in as. Development only (the route 404s
 * in production).
 *
 * Without a key it is a brand new throwaway account every call, so the
 * new-account path can be exercised. With a key it is the same account every
 * call: local staging's seeded test accounts (`fresh`, `day-one`, `month`) are
 * reached this way, and seeding twice finds them instead of making more.
 *
 * Either way the Apple subject starts with `dev-test-user:`, which a real Apple
 * subject never does, so no real account can be reached through this route.
 */
export const DevTestUserRequestSchema = z
  .object({ key: z.string().regex(/^[a-z0-9-]{1,32}$/).optional() })
  .strict();

export interface DevTestIdentity {
  appleUserId: string;
  email: string;
}

export function devTestIdentity(key: string | undefined, newHandle: () => string = randomUUID): DevTestIdentity {
  if (key) return { appleUserId: `dev-test-user:seed-${key}`, email: `dev+seed-${key}@retrospect.test` };
  const handle = newHandle();
  return { appleUserId: `dev-test-user:${handle}`, email: `dev+${handle.slice(0, 8)}@retrospect.test` };
}

export interface DevTestUserDeps {
  isProduction: boolean;
  getOrCreateUser(appleUserId: string, email?: string): Promise<AuthUser>;
  generateToken(user: AuthUser): string;
  newHandle?: () => string;
}

/**
 * The route handler, with its dependencies passed in so it is tested over
 * HTTP without a database. Mints a real JWT for a throwaway user: a brand new
 * one by default, or a seeded staging account when the body names one
 * (`{ "key": "month" }`).
 *
 * Two first calls for the same key at once (two seed runs) race on the unique
 * apple_user_id; the loser's insert fails, so it looks the user up once more
 * and finds the winner instead of answering 500.
 */
export function devTestUserHandler(deps: DevTestUserDeps): RequestHandler {
  return async (req: Request, res: Response) => {
    if (deps.isProduction) {
      res.status(404).json({ success: false, error: 'Endpoint not found' });
      return;
    }
    const parsed = DevTestUserRequestSchema.safeParse(req.body ?? {});
    if (!parsed.success) {
      res.status(400).json({ success: false, error: 'key must be 1-32 lowercase letters, digits or dashes' });
      return;
    }
    const identity = devTestIdentity(parsed.data.key, deps.newHandle);
    try {
      let user: AuthUser;
      try {
        user = await deps.getOrCreateUser(identity.appleUserId, identity.email);
      } catch {
        user = await deps.getOrCreateUser(identity.appleUserId, identity.email);
      }
      console.log(`[dev] issued a test-user token for ${user.id}`);
      res.json({ success: true, data: { token: deps.generateToken(user), user: { id: user.id, email: user.email } } });
    } catch (error) {
      console.error('Dev test user error:', error);
      res.status(500).json({ success: false, error: 'Failed to create dev test user' });
    }
  };
}
