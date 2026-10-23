import { insertRawContent, type InsertClient, type InsertOutcome } from '../services/content-insert.js';
import type { DedupInput } from '../services/dedup-key.js';
import { ACCESS_STATES, type AccessState } from '../access/store.js';
import { GIVEN, QUESTION_KEYS, answerFingerprint, type Given, type ProfileAnswer, type QuestionKey } from './profile.js';

/**
 * First run's answers and the onboarding-complete step in the shared database
 * (BE2.2b.min). Every read and write names the caller (`user_id = $user`), so
 * one person's answers can never reach another's profile.
 *
 * - An answer is one `raw_content` row (`onboarding_answer`), stored once per
 *   clientEntryId through insertRawContent's explicit key. It is stored
 *   `completed` and never handed to ingest: the brain reads the person's words
 *   through the composed profile, and a `pending` row would hold the
 *   onboarding pipeline in "reading" (agent loadOnboardingFacts counts
 *   pending/processing only).
 * - The profile is one `onboarding_profile` row per composition (explicit key
 *   from profile.ts's profileKey), left `pending` for ingest.
 * - complete is one guarded UPDATE: only `approved` becomes `member`.
 *
 * Errors carry no row values: a database message can quote the words.
 */

export const ANSWER_TYPE = 'onboarding_answer';
export const PROFILE_TYPE = 'onboarding_profile';
/** How many of a person's answer rows the profile reads (newest first); 12 keys answered a few times each fit well under it. */
export const ANSWER_READ_LIMIT = 500;

export interface StoredAnswer extends ProfileAnswer {
  /** The person's moment (content_date), ISO 8601 UTC with ms. */
  createdAt: string;
}

export type SaveAnswerOutcome =
  | { outcome: 'created' | 'replayed'; answer: StoredAnswer }
  | { outcome: 'mismatch' };

export interface OnboardingStore {
  /** Stores one answer once per (person, clientEntryId); the same key with another body is a mismatch. */
  saveAnswer(input: {
    userId: string; clientEntryId: string; questionKey: QuestionKey; given: Given; text: string; createdAtIso: string; appVersion: string | null;
  }): Promise<SaveAnswerOutcome>;
  /** The caller's latest answer per key (by their moment, then arrival), in no particular order. */
  latestAnswers(userId: string): Promise<StoredAnswer[]>;
  /** Stores one composed profile once per key; `created` false when it was already there. */
  saveProfile(input: { userId: string; text: string; key: string; answers: number; nowIso: string }): Promise<{ id: string; created: boolean }>;
  /** approved -> member (guarded); any other state unchanged. The state now, or null when there is no such person. */
  complete(userId: string): Promise<AccessState | null>;
}

/** The supabase-js builder slice the store uses (tests answer it from PGlite: tests/support/pglite-onboarding.ts). */
export interface OnboardingQueryResult { data: unknown; error: { code?: string } | null }
export interface OnboardingFilter extends PromiseLike<OnboardingQueryResult> {
  eq(column: string, value: unknown): OnboardingFilter;
  order(column: string, opts: { ascending: boolean }): OnboardingFilter;
  limit(n: number): OnboardingFilter;
  maybeSingle(): PromiseLike<OnboardingQueryResult>;
}
export interface OnboardingUpdate {
  eq(column: string, value: unknown): OnboardingUpdate;
  select(columns: string): { maybeSingle(): PromiseLike<OnboardingQueryResult> };
}
export interface OnboardingDbClient {
  from(table: string): {
    insert(row: Record<string, unknown>): { select(columns: string): { single(): PromiseLike<{ data: { id: string } | null; error: { code?: string; message: string } | null }> } };
    select(columns: string): OnboardingFilter;
    update(values: Record<string, unknown>): OnboardingUpdate;
  };
}

const TABLE = 'raw_content';
const ANSWER_COLUMNS = 'id,content,metadata,content_date,created_at';

function failed(what: string, r: { error: { code?: string } | null }): never {
  throw new Error(`${what} failed (${r.error?.code ?? 'unknown'})`);
}

const iso = (v: unknown): string => new Date(v as string | Date).toISOString();
const record = (v: unknown): Record<string, unknown> => (v && typeof v === 'object' && !Array.isArray(v) ? v as Record<string, unknown> : {});
const isKey = (v: unknown): v is QuestionKey => typeof v === 'string' && (QUESTION_KEYS as readonly string[]).includes(v);
const isGiven = (v: unknown): v is Given => typeof v === 'string' && (GIVEN as readonly string[]).includes(v);

/** A stored answer row and when it arrived, or null when it isn't one this door wrote (a row without a known key). */
function toAnswer(raw: Record<string, unknown>): { answer: StoredAnswer; arrivedAt: string } | null {
  const meta = record(raw.metadata);
  if (!isKey(meta.questionKey) || !isGiven(meta.given) || typeof raw.content !== 'string') return null;
  const createdAt = iso(raw.content_date ?? raw.created_at);
  return {
    answer: { id: String(raw.id), questionKey: meta.questionKey, given: meta.given, text: raw.content, createdAt },
    arrivedAt: raw.created_at ? iso(raw.created_at) : createdAt,
  };
}

/** insertRawContent, with any error's words left behind (a Postgres message can quote the row). */
async function insertOnce(db: OnboardingDbClient, what: string, row: Record<string, unknown> & { user_id: string }, dedup: DedupInput): Promise<InsertOutcome> {
  try {
    // The cast is confined to this boundary, as in routes/content.ts.
    return await insertRawContent(db as unknown as InsertClient, TABLE, row, dedup);
  } catch {
    throw new Error(`${what} insert failed`);
  }
}

export function supabaseOnboardingStore(db: OnboardingDbClient): OnboardingStore {
  return {
    async saveAnswer({ userId, clientEntryId, questionKey, given, text, createdAtIso, appVersion }) {
      const outcome = await insertOnce(db, 'onboarding answer', {
        user_id: userId,
        content_type: ANSWER_TYPE,
        content: text,
        content_date: createdAtIso,
        metadata: { questionKey, given, client_entry_id: clientEntryId, ...(appVersion ? { app_version: appVersion } : {}) },
        authorship: 'self',
        // Read through the profile, never on its own: not pending, so the brain neither ingests it nor waits on it.
        processing_status: 'completed',
      }, {
        userId, contentType: ANSWER_TYPE, content: answerFingerprint({ questionKey, given, text }), idempotencyKey: clientEntryId,
      });
      if (outcome.kind === 'key_reused') return { outcome: 'mismatch' };
      if (outcome.kind === 'inserted') {
        return { outcome: 'created', answer: { id: outcome.id, questionKey, given, text, createdAt: iso(createdAtIso) } };
      }
      const r = await db.from(TABLE).select(ANSWER_COLUMNS).eq('user_id', userId).eq('id', outcome.id).maybeSingle();
      if (r.error) failed('onboarding answer replay', r);
      const stored = r.data ? toAnswer(r.data as Record<string, unknown>) : null;
      if (!stored) throw new Error('onboarding answer replay: stored row unreadable');
      return { outcome: 'replayed', answer: stored.answer };
    },

    async latestAnswers(userId) {
      const r = await db.from(TABLE).select(ANSWER_COLUMNS).eq('user_id', userId).eq('content_type', ANSWER_TYPE)
        .order('created_at', { ascending: false }).limit(ANSWER_READ_LIMIT);
      if (r.error) failed('onboarding answers', r);
      const latest = new Map<QuestionKey, { answer: StoredAnswer; arrivedAt: string }>();
      for (const raw of (Array.isArray(r.data) ? r.data : []) as Record<string, unknown>[]) {
        const a = toAnswer(raw);
        if (!a) continue;
        const held = latest.get(a.answer.questionKey);
        const newer = !held || a.answer.createdAt > held.answer.createdAt || (a.answer.createdAt === held.answer.createdAt && a.arrivedAt > held.arrivedAt);
        if (newer) latest.set(a.answer.questionKey, a);
      }
      return [...latest.values()].map((a) => a.answer);
    },

    async saveProfile({ userId, text, key, answers, nowIso }) {
      const outcome = await insertOnce(db, 'onboarding profile', {
        user_id: userId,
        content_type: PROFILE_TYPE,
        content: text,
        content_date: nowIso,
        metadata: { source: 'v2.onboarding.answers', answers },
        authorship: 'self',
      }, { userId, contentType: PROFILE_TYPE, content: text, idempotencyKey: `profile:${key}` });
      return { id: outcome.id, created: outcome.kind === 'inserted' };
    },

    async complete(userId) {
      const moved = await db.from('users').update({ access: 'member' }).eq('id', userId).eq('access', 'approved').select('access').maybeSingle();
      if (moved.error) failed('onboarding complete', moved);
      if (moved.data) return 'member';
      const now = await db.from('users').select('access').eq('id', userId).maybeSingle();
      if (now.error) failed('onboarding complete read', now);
      if (now.data === null || now.data === undefined) return null;
      const state = record(now.data).access;
      if (typeof state !== 'string' || !(ACCESS_STATES as readonly string[]).includes(state)) throw new Error('onboarding complete: unknown access state');
      return state as AccessState;
    },
  };
}
