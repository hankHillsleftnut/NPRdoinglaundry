import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { config } from '../utils/config.js';
import { supabaseAdmin, Tables } from '../utils/supabase.js';
import { verifyAppleIdentityToken } from '../services/apple-auth.js';
import { normalizeAccountType } from '../services/accounts.js';
import { resolveFlagsForUser, EMPTY_FLAGS, type FeatureFlagMap } from '../services/feature-flags.js';
import type { AuthUser, JWTPayload } from '../types/index.js';

// Extend Express Request type to include user
declare global {
  namespace Express {
    interface Request {
      user?: AuthUser;
      /** Feature flags resolved ONCE per request. See services/feature-flags.ts. */
      featureFlags?: FeatureFlagMap;
    }
  }
}

export async function authMiddleware(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({
        success: false,
        error: 'Missing or invalid authorization header',
      });
      return;
    }

    const token = authHeader.substring(7);

    // Verify JWT
    let payload: JWTPayload;
    try {
      payload = jwt.verify(token, config.jwt.secret) as JWTPayload;
    } catch {
      res.status(401).json({
        success: false,
        error: 'Invalid or expired token',
      });
      return;
    }

    // Fetch user from database
    const { data: user, error } = await supabaseAdmin
      .from(Tables.USERS)
      .select('id, apple_user_id, email, account_type')
      .eq('id', payload.userId)
      .single();

    if (error || !user) {
      res.status(401).json({
        success: false,
        error: 'User not found',
      });
      return;
    }

    req.user = {
      id: user.id,
      // Nullable since 004; without the coalesce a Google/dev-only account
      // would carry `appleUserId: null` into the next minted JWT.
      appleUserId: user.apple_user_id ?? undefined,
      email: user.email ?? undefined,
      accountType: normalizeAccountType(user.account_type),
    };

    // Resolve feature flags once per request; never let a flag failure 500 a
    // request — resolveFlagsForUser already fails closed to an empty map.
    req.featureFlags = await resolveFlagsForUser(user.id).catch(() => EMPTY_FLAGS);

    next();
  } catch (error) {
    console.error('Auth middleware error:', error);
    res.status(500).json({
      success: false,
      error: 'Authentication error',
    });
  }
}

// Generate JWT for a user
export function generateToken(user: AuthUser): string {
  const payload: Omit<JWTPayload, 'iat' | 'exp'> = {
    userId: user.id,
    appleUserId: user.appleUserId,
  };

  return jwt.sign(payload, config.jwt.secret, {
    expiresIn: config.jwt.expiresIn,
  });
}

// ============================================
// Identity resolution
//
// `users` is the account. `auth_identities` holds the credentials that can
// open it: one row per (provider, provider_subject). A user may have many, so
// changing or adding a sign-in method never orphans their data. See
// supabase/migrations/004_auth_identities.sql.
// ============================================

export type AuthProvider = 'apple' | 'google' | 'dev';

export interface AuthIdentityInput {
  provider: AuthProvider;
  /** Stable subject issued by the provider (the `sub` claim for Apple/Google). */
  subject: string;
  email?: string;
}

interface AuthIdentityRow {
  id: string;
  user_id: string;
  email: string | null;
}

interface UserRow {
  id: string;
  apple_user_id: string | null;
  email: string | null;
  account_type: string | null;
}

/** Postgres unique-violation SQLSTATE, surfaced by PostgREST as `code`. */
const PG_UNIQUE_VIOLATION = '23505';

function isUniqueViolation(error: unknown): boolean {
  return (
    !!error &&
    typeof error === 'object' &&
    'code' in error &&
    (error as { code?: string }).code === PG_UNIQUE_VIOLATION
  );
}

/**
 * Raised when a credential is already bound to a *different* account.
 * Linking must never silently move a credential between accounts: doing so
 * would hand one person's second brain to whoever signed in last.
 */
export class IdentityLinkConflictError extends Error {
  readonly code = 'IDENTITY_ALREADY_LINKED';
  readonly provider: AuthProvider;

  constructor(provider: AuthProvider) {
    super(
      `That ${provider} account is already linked to a different Retrospect account.`
    );
    this.name = 'IdentityLinkConflictError';
    this.provider = provider;
  }
}

async function findIdentity(
  provider: AuthProvider,
  subject: string
): Promise<AuthIdentityRow | null> {
  const { data, error } = await supabaseAdmin
    .from(Tables.AUTH_IDENTITIES)
    .select('id, user_id, email')
    .eq('provider', provider)
    .eq('provider_subject', subject)
    .maybeSingle();

  if (error) {
    throw new Error(`Failed to look up auth identity: ${error.message}`);
  }

  return (data as AuthIdentityRow | null) ?? null;
}

async function loadUserRow(userId: string): Promise<UserRow | null> {
  const { data, error } = await supabaseAdmin
    .from(Tables.USERS)
    .select('id, apple_user_id, email, account_type')
    .eq('id', userId)
    .maybeSingle();

  if (error) {
    throw new Error(`Failed to load user: ${error.message}`);
  }

  return (data as UserRow | null) ?? null;
}

function toAuthUser(user: UserRow, email?: string): AuthUser {
  return {
    id: user.id,
    appleUserId: user.apple_user_id ?? undefined,
    email: email ?? user.email ?? undefined,
    accountType: normalizeAccountType(user.account_type),
  };
}

/**
 * Insert the identity row, tolerating a concurrent insert of the same
 * (provider, subject). `ignoreDuplicates` compiles to ON CONFLICT DO NOTHING,
 * so the loser of a race gets zero rows back instead of an error — and
 * critically, never overwrites the winner's `user_id`.
 *
 * Returns the row if we inserted it, or null if someone else got there first.
 */
async function insertIdentityIfAbsent(
  userId: string,
  identity: AuthIdentityInput
): Promise<AuthIdentityRow | null> {
  const { data, error } = await supabaseAdmin
    .from(Tables.AUTH_IDENTITIES)
    .upsert(
      {
        user_id: userId,
        provider: identity.provider,
        provider_subject: identity.subject,
        email: identity.email ?? null,
        last_seen_at: new Date().toISOString(),
      },
      { onConflict: 'provider,provider_subject', ignoreDuplicates: true }
    )
    .select('id, user_id, email');

  if (error) {
    // Some PostgREST versions surface the ignored conflict as an error rather
    // than an empty result set; treat both as "someone else won".
    if (isUniqueViolation(error)) return null;
    throw new Error(`Failed to create auth identity: ${error.message}`);
  }

  const rows = (data ?? []) as AuthIdentityRow[];
  return rows.length > 0 ? (rows[0] as AuthIdentityRow) : null;
}

async function touchIdentity(
  identityId: string,
  email?: string
): Promise<void> {
  const patch: Record<string, unknown> = {
    last_seen_at: new Date().toISOString(),
  };
  if (email) patch.email = email;

  const { error } = await supabaseAdmin
    .from(Tables.AUTH_IDENTITIES)
    .update(patch)
    .eq('id', identityId);

  // A failed last_seen_at bump is telemetry, not authentication. Never fail a
  // sign-in over it.
  if (error) {
    console.error('Failed to update auth identity last_seen_at:', error.message);
  }
}

async function syncUserEmail(user: UserRow, email?: string): Promise<void> {
  if (!email || email === user.email) return;

  const { error } = await supabaseAdmin
    .from(Tables.USERS)
    .update({ email })
    .eq('id', user.id);

  if (error) {
    console.error('Failed to sync user email:', error.message);
  }
}

/**
 * Resolve (provider, subject) to an account, creating the account on first
 * sign-in.
 *
 * Concurrency: two simultaneous first sign-ins for the same subject must not
 * produce two accounts. The unique index on (provider, provider_subject) is
 * the arbiter — exactly one insert wins. The loser adopts the winner's
 * `user_id` and deletes the empty account it had just created, so the caller
 * cannot observe the race.
 */
export async function resolveUserForIdentity(
  identity: AuthIdentityInput
): Promise<AuthUser> {
  const { provider, subject, email } = identity;

  if (!subject) {
    throw new Error('Identity subject is required');
  }

  // Fast path: known credential.
  const existing = await findIdentity(provider, subject);
  if (existing) {
    const user = await loadUserRow(existing.user_id);
    if (!user) {
      // The FK is ON DELETE CASCADE, so this means the row vanished between
      // the two reads. Surfacing it is better than inventing a new account.
      throw new Error('Auth identity points at a missing user');
    }
    await touchIdentity(existing.id, email);
    await syncUserEmail(user, email);
    return toAuthUser(user, email);
  }

  // First sign-in with this credential: create the account, then bind it.
  let userId: string;
  let createdUser = false;

  // Dual-write the deprecated users.apple_user_id during the staging window so
  // a rollback to the pre-004 backend can still resolve accounts created now.
  // Removed together with the column.
  const insertPayload: Record<string, unknown> = { email: email ?? null };
  if (provider === 'apple') insertPayload.apple_user_id = subject;
  // Integration seam between 004 (identities) and 005 (account types): the dev
  // provider only ever mints throwaway accounts, so they must be born `test` or
  // they land in analytics, admin listings and Sentry as real users. Every other
  // provider takes the column default (`real`).
  if (provider === 'dev') insertPayload.account_type = 'test';

  const { data: newUser, error: insertError } = await supabaseAdmin
    .from(Tables.USERS)
    .insert(insertPayload)
    .select('id, apple_user_id, email, account_type')
    .single();

  if (insertError || !newUser) {
    // A users.apple_user_id collision means a legacy account exists for this
    // Apple subject but its auth_identities row is missing (e.g. created
    // between the backfill and this deploy). Adopt that account rather than
    // stranding the user with a fresh empty one.
    if (provider === 'apple' && isUniqueViolation(insertError)) {
      const { data: legacyUser } = await supabaseAdmin
        .from(Tables.USERS)
        .select('id, apple_user_id, email, account_type')
        .eq('apple_user_id', subject)
        .maybeSingle();

      if (!legacyUser) {
        throw new Error(
          `Failed to create user: ${insertError?.message ?? 'unknown error'}`
        );
      }
      userId = (legacyUser as UserRow).id;
    } else {
      throw new Error(
        `Failed to create user: ${insertError?.message ?? 'unknown error'}`
      );
    }
  } else {
    userId = (newUser as UserRow).id;
    createdUser = true;
  }

  const inserted = await insertIdentityIfAbsent(userId, identity);

  if (!inserted) {
    // Lost the race. Someone else bound this credential microseconds ago.
    const winner = await findIdentity(provider, subject);
    if (!winner) {
      throw new Error('Failed to resolve auth identity after conflict');
    }

    if (createdUser && winner.user_id !== userId) {
      // Discard the account we just created. It is provably empty: it was
      // created inside this call, never returned to any caller, and no
      // identity row ever pointed at it.
      const { error: cleanupError } = await supabaseAdmin
        .from(Tables.USERS)
        .delete()
        .eq('id', userId);

      if (cleanupError) {
        console.error(
          `Failed to clean up orphaned user ${userId} after identity race:`,
          cleanupError.message
        );
      }
    }

    const winnerUser = await loadUserRow(winner.user_id);
    if (!winnerUser) {
      throw new Error('Auth identity points at a missing user');
    }
    await touchIdentity(winner.id, email);
    await syncUserEmail(winnerUser, email);
    return toAuthUser(winnerUser, email);
  }

  const user = await loadUserRow(userId);
  if (!user) {
    throw new Error('Failed to load user after creation');
  }

  return toAuthUser(user, email);
}

/**
 * Create or get a user from a verified provider credential.
 *
 * Preferred form:
 *   getOrCreateUser({ provider: 'apple', subject: verified.appleUserId, email })
 */
export async function getOrCreateUser(
  identity: AuthIdentityInput
): Promise<AuthUser>;
/**
 * @deprecated Legacy positional form. A transitional shim so in-flight call
 * sites keep compiling and behaving correctly through this refactor; convert
 * them to the object form and delete this overload.
 */
export async function getOrCreateUser(
  subject: string,
  email?: string
): Promise<AuthUser>;
export async function getOrCreateUser(
  identityOrSubject: AuthIdentityInput | string,
  legacyEmail?: string
): Promise<AuthUser> {
  if (typeof identityOrSubject !== 'string') {
    return resolveUserForIdentity(identityOrSubject);
  }

  // The positional form carries no provider. Defaulting everything to 'apple'
  // would file throwaway dev accounts as Apple identities, so recognise the
  // one known dev subject convention (`dev-test-user:<uuid>`, minted by
  // POST /auth/dev/test-user) and treat everything else as Apple, which is
  // what every other historical caller meant.
  const provider: AuthProvider = identityOrSubject.startsWith('dev-test-user:')
    ? 'dev'
    : 'apple';

  return resolveUserForIdentity({
    provider,
    subject: identityOrSubject,
    email: legacyEmail,
  });
}

/**
 * Attach a verified credential to an account that is *already signed in*.
 *
 * This is what makes "my notes stay mine no matter how I sign in" true: a user
 * who adds Google, or moves to a new Apple ID, keeps the same `users.id` and
 * therefore every goal, observation, insight and episode hanging off it.
 *
 * Refuses, loudly, to move a credential that belongs to another account.
 * Idempotent when the credential is already on this account.
 */
export async function linkAuthIdentity(
  userId: string,
  identity: AuthIdentityInput
): Promise<{ alreadyLinked: boolean }> {
  if (!userId) {
    throw new Error('userId is required to link an identity');
  }
  if (!identity.subject) {
    throw new Error('Identity subject is required');
  }

  // Check first so the common conflict case gives a clean answer without
  // relying on error parsing. The insert below is still the real arbiter.
  const existing = await findIdentity(identity.provider, identity.subject);
  if (existing) {
    if (existing.user_id !== userId) {
      throw new IdentityLinkConflictError(identity.provider);
    }
    await touchIdentity(existing.id, identity.email);
    return { alreadyLinked: true };
  }

  // Also check the deprecated column. A legacy `users` row can carry this
  // Apple subject with no auth_identities row yet — e.g. minted by pre-004
  // backend code still serving during a rolling deploy. Linking it here would
  // bind the credential to the *linking* account and strand the legacy one:
  // its owner's next sign-in would silently land in someone else's account.
  // That is exactly the data loss this whole change exists to prevent.
  // Remove this check when users.apple_user_id is dropped.
  if (identity.provider === 'apple') {
    const { data: legacyUser, error: legacyError } = await supabaseAdmin
      .from(Tables.USERS)
      .select('id')
      .eq('apple_user_id', identity.subject)
      .maybeSingle();

    if (legacyError) {
      throw new Error(
        `Failed to check legacy Apple binding: ${legacyError.message}`
      );
    }
    if (legacyUser && (legacyUser as { id: string }).id !== userId) {
      throw new IdentityLinkConflictError('apple');
    }
  }

  const inserted = await insertIdentityIfAbsent(userId, identity);

  if (!inserted) {
    // Raced against another link/sign-in for the same credential.
    const winner = await findIdentity(identity.provider, identity.subject);
    if (!winner) {
      throw new Error('Failed to resolve auth identity after conflict');
    }
    if (winner.user_id !== userId) {
      throw new IdentityLinkConflictError(identity.provider);
    }
    await touchIdentity(winner.id, identity.email);
    return { alreadyLinked: true };
  }

  // Best-effort: keep the deprecated column coherent for the staging window,
  // but only when it is empty — never clobber an existing Apple binding, and
  // never fail the link over a column that is on its way out.
  if (identity.provider === 'apple') {
    const { error: backfillError } = await supabaseAdmin
      .from(Tables.USERS)
      .update({ apple_user_id: identity.subject })
      .eq('id', userId)
      .is('apple_user_id', null);

    if (backfillError) {
      console.error(
        'Failed to mirror linked Apple subject onto deprecated users.apple_user_id:',
        backfillError.message
      );
    }
  }

  return { alreadyLinked: false };
}

/**
 * Verify a provider-issued token and return the credential it proves.
 *
 * The subject must come from a *verified* token, never from the request body:
 * accepting a client-supplied subject here would let any authenticated caller
 * attach someone else's credential to their own account.
 */
export async function verifyProviderIdentityToken(
  provider: AuthProvider,
  identityToken: string
): Promise<AuthIdentityInput> {
  switch (provider) {
    case 'apple': {
      const verified = await verifyAppleIdentityToken(identityToken);
      return {
        provider: 'apple',
        subject: verified.appleUserId,
        email: verified.email,
      };
    }
    default:
      throw new Error(`Unsupported identity provider: ${provider}`);
  }
}
