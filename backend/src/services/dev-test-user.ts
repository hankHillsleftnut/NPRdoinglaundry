import { randomUUID } from 'node:crypto';
import { z } from 'zod';

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
