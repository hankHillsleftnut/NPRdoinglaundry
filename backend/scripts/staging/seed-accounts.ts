import { devTestIdentity } from '../../src/services/dev-test-user.js';
import { getOrCreateUserWith, type UsersClient } from '../../src/services/users.js';
import type { AccountKey } from './seed.js';

/**
 * Finds or creates a seeded test account on the staging database, with the
 * same Apple subject the dev route uses for that key, so a test build signing
 * in with `{ "key": "month" }` lands on it. Race-safe (services/users.ts).
 */
export async function ensureSeedAccount(db: UsersClient, key: AccountKey): Promise<string> {
  const identity = devTestIdentity(key);
  const user = await getOrCreateUserWith(db, 'users', identity.appleUserId, identity.email);
  return user.id;
}
