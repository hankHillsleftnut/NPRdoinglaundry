import type { AuthUser } from '../types/index.js';

/** Postgres: a row with this unique value already exists. */
const UNIQUE_VIOLATION = '23505';
const USER_COLUMNS = 'id, apple_user_id, email';

type UserRow = { id: string; apple_user_id: string; email: string | null };
type DbError = { code?: string; message: string } | null;

/** The subset of the Supabase client getOrCreateUserWith uses. */
export interface UsersClient {
  from(table: string): {
    select(columns: string): {
      eq(column: string, value: string): {
        maybeSingle(): PromiseLike<{ data: UserRow | null; error: DbError }>;
      };
    };
    insert(row: Record<string, unknown>): {
      select(columns: string): {
        single(): PromiseLike<{ data: UserRow | null; error: DbError }>;
      };
    };
    update(row: Record<string, unknown>): {
      eq(column: string, value: string): PromiseLike<{ error: DbError }>;
    };
  };
}

async function findByApple(db: UsersClient, table: string, appleUserId: string): Promise<UserRow | null> {
  const { data, error } = await db.from(table).select(USER_COLUMNS).eq('apple_user_id', appleUserId).maybeSingle();
  if (error) throw new Error('Failed to look up user');
  return data;
}

async function withEmail(db: UsersClient, table: string, row: UserRow, email?: string): Promise<AuthUser> {
  // An email from Apple replaces the stored one when it differs (Apple sends it
  // only on the first authorisation, or when the person changes it).
  if (email && email !== row.email) {
    await db.from(table).update({ email }).eq('id', row.id);
  }
  return { id: row.id, appleUserId: row.apple_user_id, email: email ?? row.email ?? undefined };
}

/**
 * Finds the user for an Apple subject, creating it on first sign-in.
 *
 * Race-safe: two first sign-ins at once (a double tap, a retry) both try to
 * insert; the unique index on apple_user_id lets one win, and the other reads
 * the winner instead of failing. Both callers get the same user id.
 */
export async function getOrCreateUserWith(
  db: UsersClient,
  table: string,
  appleUserId: string,
  email?: string,
): Promise<AuthUser> {
  const existing = await findByApple(db, table, appleUserId);
  if (existing) return withEmail(db, table, existing, email);

  const { data: created, error } = await db
    .from(table)
    .insert({ apple_user_id: appleUserId, email })
    .select(USER_COLUMNS)
    .single();
  if (created) return { id: created.id, appleUserId: created.apple_user_id, email: created.email ?? undefined };

  if (error?.code === UNIQUE_VIOLATION) {
    const winner = await findByApple(db, table, appleUserId);
    if (winner) return withEmail(db, table, winner, email);
  }
  throw new Error('Failed to create user');
}
