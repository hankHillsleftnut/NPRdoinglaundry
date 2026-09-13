/**
 * Per-user feature flags.
 *
 * Resolution precedence, in order:
 *   1. an explicit `user_feature_flags` row for (user_id, flag_key)  -> that row's `enabled`
 *   2. the `feature_flags` row's `default_enabled`
 *   3. false
 *
 * Flags FAIL CLOSED. An unknown key, a missing user override, a missing flag
 * definition, or a database error all resolve to `false` — never to the new
 * behaviour. The point of this mechanism is that a risky variant reaches one
 * account at a time, so "we couldn't read the flags" must mean "everyone keeps
 * the shipped behaviour", not "everyone gets the experiment".
 *
 * Resolution happens ONCE per request (in `authMiddleware`) and the resolved
 * map is handed to the iOS client in the /auth/* response, so the client
 * branches on exactly the same map the server used for that request.
 */

import type { Request, Response, NextFunction } from 'express';
import { supabaseAdmin, Tables } from '../utils/supabase.js';

export type FeatureFlagMap = Readonly<Record<string, boolean>>;

// Declared here rather than in middleware/auth.ts so the flag mechanism owns
// its own request augmentation and stays out of a heavily contended file.
declare global {
  namespace Express {
    interface Request {
      /** Flags resolved ONCE per request by `featureFlagsMiddleware`. */
      featureFlags?: FeatureFlagMap;
    }
  }
}

/**
 * Known flag keys. Seeded in supabase/migrations/005_account_type_and_flags.sql.
 * Adding a constant here is optional — `isFlagEnabled` works with any string —
 * but it keeps the risky call sites greppable.
 */
export const FeatureFlagKeys = {
  /** Select the v2 CBT insight-synthesis system prompt for this user only. */
  INSIGHT_SYNTHESIS_PROMPT_V2: 'insight_synthesis_prompt_v2',
  /** Select v2 agent pipeline behaviour for this user only. */
  PIPELINE_AGENT_V2: 'pipeline_agent_v2',
} as const;

export type FeatureFlagKey = (typeof FeatureFlagKeys)[keyof typeof FeatureFlagKeys];

export const EMPTY_FLAGS: FeatureFlagMap = Object.freeze({});

// Flag DEFINITIONS (not per-user overrides) change rarely and are read on every
// authenticated request, so cache them briefly in-process. Overrides are always
// read fresh, so flipping a flag for one user takes effect on their next request.
const DEFAULTS_TTL_MS = 30_000;
let defaultsCache: { at: number; value: Record<string, boolean> } | null = null;

async function loadFlagDefaults(): Promise<Record<string, boolean>> {
  const now = Date.now();
  if (defaultsCache && now - defaultsCache.at < DEFAULTS_TTL_MS) {
    return defaultsCache.value;
  }

  const { data, error } = await supabaseAdmin
    .from(Tables.FEATURE_FLAGS)
    .select('key, default_enabled');

  if (error) {
    // Fail CLOSED. A warm cache would be friendlier, but it can only ever make
    // a flag read `true` that the database can no longer confirm — and serving
    // an unconfirmable `true` is the single outcome this module exists to
    // prevent. An outage turns every variant off; it never turns one on.
    console.error('[feature-flags] failed to load flag defaults:', error.message);
    return {};
  }

  const value: Record<string, boolean> = {};
  for (const row of (data ?? []) as { key: string; default_enabled: boolean | null }[]) {
    value[row.key] = row.default_enabled === true;
  }

  defaultsCache = { at: now, value };
  return value;
}

/** Test seam: drop the in-process flag-definition cache. */
export function clearFeatureFlagCache(): void {
  defaultsCache = null;
}

/**
 * Resolve every known flag for a user into a plain map.
 * Always returns a map (possibly empty); never throws.
 */
export async function resolveFlagsForUser(userId: string): Promise<FeatureFlagMap> {
  try {
    const defaults = await loadFlagDefaults();
    const resolved: Record<string, boolean> = { ...defaults };

    const { data, error } = await supabaseAdmin
      .from(Tables.USER_FEATURE_FLAGS)
      .select('flag_key, enabled')
      .eq('user_id', userId);

    if (error) {
      // Fail CLOSED — and note WHY this must not return `resolved`: `resolved`
      // is defaults-only at this point, so returning it would resolve a flag
      // with default_enabled=true to `true` for a user whose override row says
      // false. That row exists precisely because this user must NOT get the
      // variant, so a blip on this read must never be what overrides it.
      console.error(`[feature-flags] failed to load overrides for ${userId}:`, error.message);
      return EMPTY_FLAGS;
    }

    for (const row of (data ?? []) as { flag_key: string; enabled: boolean | null }[]) {
      // An explicit override wins in BOTH directions: a row with enabled=false
      // turns a default-on flag off for this user.
      resolved[row.flag_key] = row.enabled === true;
    }

    return Object.freeze(resolved);
  } catch (err) {
    console.error(`[feature-flags] resolution failed for ${userId}:`, err);
    return EMPTY_FLAGS;
  }
}

/**
 * Resolve this user's flags once and hang them on the request.
 *
 * Mount AFTER `authMiddleware`, and only on routers that actually branch on a
 * flag — it costs one indexed read, and a router that never reads
 * `req.featureFlags` should not pay for it. A route that reads the map without
 * this middleware mounted sees `undefined`, which `isFlagEnabled` treats as
 * all-off, so forgetting to mount it fails closed rather than open.
 */
export async function featureFlagsMiddleware(
  req: Request,
  _res: Response,
  next: NextFunction
): Promise<void> {
  const userId = req.user?.id;
  req.featureFlags = userId
    ? await resolveFlagsForUser(userId).catch(() => EMPTY_FLAGS)
    : EMPTY_FLAGS;
  next();
}

/**
 * Read one flag out of an already-resolved map.
 * Anything other than an explicit `true` is off.
 */
export function isFlagEnabled(
  flags: FeatureFlagMap | undefined | null,
  key: FeatureFlagKey | string
): boolean {
  return flags?.[key] === true;
}

/**
 * Turn a flag on or off for exactly one user (upsert on the unique pair).
 * This is the founder's production switch.
 */
export async function setUserFlag(
  userId: string,
  key: FeatureFlagKey | string,
  enabled: boolean
): Promise<void> {
  const { error } = await supabaseAdmin
    .from(Tables.USER_FEATURE_FLAGS)
    .upsert(
      { user_id: userId, flag_key: key, enabled, updated_at: new Date().toISOString() },
      { onConflict: 'user_id,flag_key' }
    );

  if (error) {
    throw new Error(`Failed to set flag ${key} for ${userId}: ${error.message}`);
  }
}

/** Remove a user's override so they fall back to the flag's default. */
export async function clearUserFlag(
  userId: string,
  key: FeatureFlagKey | string
): Promise<void> {
  const { error } = await supabaseAdmin
    .from(Tables.USER_FEATURE_FLAGS)
    .delete()
    .eq('user_id', userId)
    .eq('flag_key', key);

  if (error) {
    throw new Error(`Failed to clear flag ${key} for ${userId}: ${error.message}`);
  }
}

/** List flag definitions (admin tooling). */
export async function listFlagDefinitions(): Promise<
  { key: string; description: string | null; default_enabled: boolean; created_at: string }[]
> {
  const { data, error } = await supabaseAdmin
    .from(Tables.FEATURE_FLAGS)
    .select('key, description, default_enabled, created_at')
    .order('key', { ascending: true });

  if (error) throw new Error(`Failed to list feature flags: ${error.message}`);
  return (data ?? []) as {
    key: string;
    description: string | null;
    default_enabled: boolean;
    created_at: string;
  }[];
}
