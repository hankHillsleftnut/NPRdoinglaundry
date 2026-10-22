/**
 * Access and the waitlist (BE0.12a, contract 00 §4), over migration 007's
 * functions: one statement each, so a retry or two calls at once can't add a
 * person twice. Errors carry the database code only (a message can carry row
 * values).
 */

/** contract 00 §4's access states, in users.access. */
export const ACCESS_STATES = ['waitlisted', 'approved', 'member', 'staff', 'suspended'] as const;
export type AccessState = (typeof ACCESS_STATES)[number];

export interface AccessStore {
  /** Whether this person has a waiting row on the waitlist. */
  onWaitlist(userId: string): Promise<boolean>;
  /** Adds a waitlisted person once (the first reason stays); returns whether they are waiting now. */
  joinWaitlist(userId: string, reason: string | null, nowIso: string): Promise<boolean>;
}

/** The slice of supabase-js the store uses. */
export interface AccessRpcClient {
  rpc(fn: string, args: Record<string, unknown>): PromiseLike<{ data: unknown; error: { code?: string } | null }>;
}

function bool(fn: string, r: { data: unknown; error: { code?: string } | null }): boolean {
  if (r.error) throw new Error(`${fn} failed (${r.error.code ?? 'unknown'})`);
  return r.data === true;
}

export function supabaseAccessStore(db: AccessRpcClient): AccessStore {
  return {
    async onWaitlist(userId) {
      return bool('waitlist_state', await db.rpc('waitlist_state', { p_user: userId }));
    },
    async joinWaitlist(userId, reason, nowIso) {
      return bool('join_waitlist', await db.rpc('join_waitlist', { p_user: userId, p_reason: reason, p_now: nowIso }));
    },
  };
}
