import type { AccessRpcClient } from '../access/store.js';
import type { AccessState } from '../access/store.js';

/**
 * Invites in the database (migration 007's functions): one call, one
 * transaction each. Codes arrive here already hashed and sealed; this module
 * never sees a plain code. Errors carry the database code only.
 */
export type RedeemOutcome =
  | { outcome: 'redeemed'; invitedBy: string | null }
  | { outcome: 'already_in'; access: AccessState }
  | { outcome: 'invalid' | 'used' | 'expired' | 'no_user' };

export interface MyInviteRow {
  id: string;
  sealed: string | null;
  createdAt: string;
  used: boolean;
  usedBy: string | null;
}

export interface WaitlistRow {
  id: string; source: 'app' | 'web'; userId: string | null; email: string | null; name: string | null;
  reason: string | null; status: 'waiting' | 'approved' | 'declined'; createdAt: string; decidedAt: string | null;
}

export interface InviteRow {
  id: string; kind: 'founder' | 'member' | 'review'; ownerUserId: string | null; ownerName: string | null;
  usedByUserId: string | null; usedByName: string | null; createdAt: string; usedAt: string | null;
  revokedAt: string | null; expiresAt: string | null;
}

export interface InviteStore {
  redeem(input: { userId: string; codeHash: string; nowIso: string; newHashes: string[]; newSealed: string[] }): Promise<RedeemOutcome>;
  mine(userId: string): Promise<MyInviteRow[]>;
  /** For the link page: whether the code is live, and the inviter's first name if so. */
  face(codeHash: string, nowIso: string): Promise<{ live: boolean; from: string | null }>;
  joinPublicWaitlist(input: { email: string; name: string | null; reason: string | null; nowIso: string }): Promise<void>;
  // Admin.
  waitlist(status: WaitlistRow['status'] | null): Promise<WaitlistRow[]>;
  approve(waitlistId: string, codeHash: string, sealed: string, nowIso: string): Promise<boolean>;
  decline(waitlistId: string, nowIso: string): Promise<boolean>;
  create(input: { kind: InviteRow['kind']; ownerUserId: string | null; hashes: string[]; sealed: string[]; expiresAt: string | null; nowIso: string }): Promise<string[]>;
  all(): Promise<InviteRow[]>;
  revoke(inviteId: string, nowIso: string): Promise<boolean>;
  setAccess(userId: string, access: AccessState): Promise<boolean>;
}

function data<T>(fn: string, r: { data: unknown; error: { code?: string } | null }): T {
  if (r.error) throw new Error(`${fn} failed (${r.error.code ?? 'unknown'})`);
  return r.data as T;
}

const str = (v: unknown) => (typeof v === 'string' ? v : null);

export function supabaseInviteStore(db: AccessRpcClient): InviteStore {
  const call = async <T>(fn: string, args: Record<string, unknown>) => data<T>(fn, await db.rpc(fn, args));
  return {
    async redeem({ userId, codeHash, nowIso, newHashes, newSealed }) {
      const raw = await call<Record<string, unknown>>('redeem_invite', {
        p_user: userId, p_code_hash: codeHash, p_now: nowIso, p_new_hashes: newHashes, p_new_ciphertexts: newSealed,
      });
      if (raw.outcome === 'redeemed') return { outcome: 'redeemed', invitedBy: str(raw.invited_by) };
      if (raw.outcome === 'already_in') return { outcome: 'already_in', access: raw.access as AccessState };
      if (raw.outcome === 'used' || raw.outcome === 'expired' || raw.outcome === 'no_user') return { outcome: raw.outcome };
      return { outcome: 'invalid' };
    },
    async mine(userId) {
      const rows = await call<Record<string, unknown>[]>('invites_of', { p_user: userId });
      return (rows ?? []).map((r) => ({
        id: String(r.id), sealed: str(r.code_ciphertext), createdAt: new Date(String(r.created_at)).toISOString(),
        used: r.used === true, usedBy: str(r.used_by),
      }));
    },
    async face(codeHash, nowIso) {
      const raw = await call<Record<string, unknown>>('invite_face', { p_code_hash: codeHash, p_now: nowIso });
      return { live: raw?.live === true, from: raw?.live === true ? str(raw.from) : null };
    },
    async joinPublicWaitlist({ email, name, reason, nowIso }) {
      await call('join_public_waitlist', { p_email: email, p_name: name, p_reason: reason, p_now: nowIso });
    },
    async waitlist(status) {
      const rows = await call<Record<string, unknown>[]>('admin_waitlist', { p_status: status });
      return (rows ?? []).map((r) => ({
        id: String(r.id), source: r.source as WaitlistRow['source'], userId: str(r.user_id), email: str(r.email), name: str(r.name),
        reason: str(r.reason), status: r.status as WaitlistRow['status'], createdAt: String(r.created_at), decidedAt: str(r.decided_at),
      }));
    },
    async approve(waitlistId, codeHash, sealed, nowIso) {
      const raw = await call<Record<string, unknown>>('approve_waitlister', { p_id: waitlistId, p_code_hash: codeHash, p_code_ciphertext: sealed, p_now: nowIso });
      return raw?.outcome === 'approved';
    },
    async decline(waitlistId, nowIso) {
      return (await call<boolean>('decline_waitlister', { p_id: waitlistId, p_now: nowIso })) === true;
    },
    async create({ kind, ownerUserId, hashes, sealed, expiresAt, nowIso }) {
      const ids = await call<unknown[]>('create_invites', {
        p_kind: kind, p_owner: ownerUserId, p_hashes: hashes, p_ciphertexts: sealed, p_expires: expiresAt, p_now: nowIso,
      });
      return (ids ?? []).map(String);
    },
    async all() {
      const rows = await call<Record<string, unknown>[]>('admin_invites', {});
      return (rows ?? []).map((r) => ({
        id: String(r.id), kind: r.kind as InviteRow['kind'], ownerUserId: str(r.owner_user_id), ownerName: str(r.owner_name),
        usedByUserId: str(r.used_by_user_id), usedByName: str(r.used_by_name), createdAt: String(r.created_at), usedAt: str(r.used_at),
        revokedAt: str(r.revoked_at), expiresAt: str(r.expires_at),
      }));
    },
    async revoke(inviteId, nowIso) {
      return (await call<boolean>('revoke_invite', { p_id: inviteId, p_now: nowIso })) === true;
    },
    async setAccess(userId, access) {
      return (await call<boolean>('set_user_access', { p_user: userId, p_access: access })) === true;
    },
  };
}
