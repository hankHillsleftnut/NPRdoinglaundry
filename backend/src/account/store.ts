import { check, type RpcClient } from '../sessions/store.js';

/**
 * The database side of account deletion (migration 028). Each method is one
 * SQL function, so one transaction; tested on PGlite (tests/account-lock.test.ts)
 * through the same calls supabase-js makes in production.
 *
 * Nothing here returns or accepts a person's data beyond ids: the only secret
 * that passes through is the sealed Apple token (written by the lock, read by
 * the Apple step), and it is never logged.
 */

export type DeletionState = 'requested' | 'user_deleted' | 'deleted';
export type AppleResult = 'revoked' | 'already_revoked' | 'no_token' | 'skipped' | 'failed';
export type StepResult = 'ok' | 'failed';

/** A claimed deletion, as the worker sees it. */
export interface DeletionRow {
  id: string;
  userId: string;
  state: DeletionState;
  apple: AppleResult | null;
  sweepBefore: StepResult | null;
  sweepAfter: StepResult | null;
  diagnostics: StepResult | null;
  grantsFailed: number;
  objectsSkipped: number;
  diagnosticsRemoved: number;
  /** How many runs have claimed it, this one included. */
  runs: number;
}

export type PrepareResult =
  | { outcome: 'ok'; appleUserId: string | null; hasAppleToken: boolean; deletionId: string | null }
  | { outcome: 'no_user' };

export type LockResult =
  | { outcome: 'locked'; id: string; created: boolean }
  | { outcome: 'apple_confirmation_required' }
  | { outcome: 'no_user' };

export interface DeletionNote {
  apple?: AppleResult;
  sweepBefore?: StepResult;
  sweepAfter?: StepResult;
  diagnostics?: StepResult;
  grantsFailed?: number;
  objectsSkipped?: number;
  diagnosticsRemoved?: number;
}

export interface DeletionStore {
  prepare(userId: string): Promise<PrepareResult>;
  /** The lock (one transaction). `appleCiphertext` is a fresh token sealed inside the request, stored with the lock. */
  lock(userId: string, nowIso: string, appleEnabled: boolean, appleCiphertext: string | null): Promise<LockResult>;
  claim(id: string, nowIso: string, leaseSeconds: number): Promise<DeletionRow | null>;
  claimDue(nowIso: string, leaseSeconds: number, limit: number): Promise<DeletionRow[]>;
  appleToken(id: string): Promise<string | null>;
  note(id: string, note: DeletionNote): Promise<void>;
  /** Deletes the users row of a person under deletion; answers the row's state after. */
  deleteUser(id: string, nowIso: string): Promise<DeletionState | 'not_found'>;
  defer(id: string, nextRunIso: string): Promise<void>;
  finish(id: string, nowIso: string): Promise<void>;
}

const STATES: readonly string[] = ['requested', 'user_deleted', 'deleted'];

function rowOf(raw: Record<string, unknown>): DeletionRow {
  const n = (v: unknown) => (typeof v === 'number' && Number.isFinite(v) ? v : 0);
  const word = <T extends string>(v: unknown) => (typeof v === 'string' ? v as T : null);
  if (!STATES.includes(String(raw.state))) throw new Error('account_deletions: unknown state');
  return {
    id: String(raw.id),
    userId: String(raw.user_id),
    state: raw.state as DeletionState,
    apple: word<AppleResult>(raw.apple),
    sweepBefore: word<StepResult>(raw.sweep_before),
    sweepAfter: word<StepResult>(raw.sweep_after),
    diagnostics: word<StepResult>(raw.diagnostics),
    grantsFailed: n(raw.grants_failed),
    objectsSkipped: n(raw.objects_skipped),
    diagnosticsRemoved: n(raw.diagnostics_removed),
    runs: n(raw.runs),
  };
}

export function supabaseDeletionStore(db: Pick<RpcClient, 'rpc'>): DeletionStore {
  return {
    async prepare(userId) {
      const raw = check<Record<string, unknown> | null>('account_deletion_prepare', await db.rpc('account_deletion_prepare', { p_user: userId }));
      if (!raw || raw.outcome !== 'ok') return { outcome: 'no_user' };
      return {
        outcome: 'ok',
        appleUserId: typeof raw.apple_user_id === 'string' ? raw.apple_user_id : null,
        hasAppleToken: raw.has_apple_token === true,
        deletionId: typeof raw.deletion_id === 'string' ? raw.deletion_id : null,
      };
    },
    async lock(userId, nowIso, appleEnabled, appleCiphertext) {
      const raw = check<Record<string, unknown> | null>('lock_account_for_deletion', await db.rpc('lock_account_for_deletion', {
        p_user: userId, p_now: nowIso, p_apple_enabled: appleEnabled, p_apple_ciphertext: appleCiphertext,
      }));
      if (raw?.outcome === 'locked') return { outcome: 'locked', id: String(raw.id), created: raw.created === true };
      if (raw?.outcome === 'apple_confirmation_required') return { outcome: 'apple_confirmation_required' };
      return { outcome: 'no_user' };
    },
    async claim(id, nowIso, leaseSeconds) {
      const raw = check<Record<string, unknown> | null>('claim_account_deletion', await db.rpc('claim_account_deletion', {
        p_id: id, p_now: nowIso, p_lease_seconds: leaseSeconds,
      }));
      return raw ? rowOf(raw) : null;
    },
    async claimDue(nowIso, leaseSeconds, limit) {
      const raw = check<unknown>('claim_due_account_deletions', await db.rpc('claim_due_account_deletions', {
        p_now: nowIso, p_lease_seconds: leaseSeconds, p_limit: limit,
      }));
      return Array.isArray(raw) ? raw.map((r) => rowOf(r as Record<string, unknown>)) : [];
    },
    async appleToken(id) {
      const raw = check<unknown>('account_deletion_apple_token', await db.rpc('account_deletion_apple_token', { p_id: id }));
      return typeof raw === 'string' && raw ? raw : null;
    },
    async note(id, note) {
      check('note_account_deletion', await db.rpc('note_account_deletion', {
        p_id: id,
        p_apple: note.apple ?? null,
        p_sweep_before: note.sweepBefore ?? null,
        p_sweep_after: note.sweepAfter ?? null,
        p_diagnostics: note.diagnostics ?? null,
        p_grants_failed: note.grantsFailed ?? null,
        p_objects_skipped: note.objectsSkipped ?? null,
        p_diagnostics_removed: note.diagnosticsRemoved ?? null,
      }));
    },
    async deleteUser(id, nowIso) {
      const raw = check<unknown>('delete_account_user', await db.rpc('delete_account_user', { p_id: id, p_now: nowIso }));
      return raw === 'not_found' || STATES.includes(String(raw)) ? raw as DeletionState | 'not_found' : 'not_found';
    },
    async defer(id, nextRunIso) {
      check('defer_account_deletion', await db.rpc('defer_account_deletion', { p_id: id, p_next_run_at: nextRunIso }));
    },
    async finish(id, nowIso) {
      check('finish_account_deletion', await db.rpc('finish_account_deletion', { p_id: id, p_now: nowIso }));
    },
  };
}
