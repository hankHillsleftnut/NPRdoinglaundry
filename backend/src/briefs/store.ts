/**
 * Briefs in the shared database (BE1.3): the agent's `daily_briefs` rows
 * (agent migrations 128, 155) and the switch on `users.daily_brief_enabled`,
 * read and written here directly, so the brief card keeps working when the
 * brain is down (BE1.3-BE1.4 pass, Q1). Nothing here calls a model.
 *
 * Errors carry the database code only: a message can carry row values.
 */

export type AudioStatus = 'none' | 'making' | 'ready' | 'failed';

/** One `daily_briefs` row, as the doors read it. */
export interface BriefRow {
  id: string;
  /** `YYYY-MM-DD`, the UTC day the brief was made for (BE6.2 makes it the local day). */
  briefDate: string;
  kind: 'brief' | 'quiet';
  throughLine: string;
  /** `'planner v2'` for v2 rows, whose through_line is the spoken text. */
  spineMovement: string | null;
  /** v1 items: `{ text, why, sourceRef: { raw_content_id } }`; v2 items are bookkeeping and never shown. */
  items: Array<{ text?: unknown; why?: unknown; sourceRef?: { raw_content_id?: unknown } }>;
  createdAt: string;
  audioStatus: AudioStatus;
  audioPath: string | null;
  audioDurationSeconds: number | null;
  /** What was spoken, in order (agent BE1.3b). */
  audioParts: Array<{ index: number; startSeconds: number; text: string }>;
  audioUpdatedAt: string | null;
}

export interface BriefStore {
  /** The person's most recent brief by date, or null. */
  latest(userId: string): Promise<BriefRow | null>;
  /** One brief, only when it is the person's. */
  byId(userId: string, briefId: string): Promise<BriefRow | null>;
  /** Newest first, strictly before `beforeDate` when given; at most `limit`. */
  list(userId: string, beforeDate: string | null, limit: number): Promise<BriefRow[]>;
  /** The switch; null when there is no such person. */
  enabled(userId: string): Promise<boolean | null>;
  /** Sets the switch; false when there is no such person. */
  setEnabled(userId: string, enabled: boolean): Promise<boolean>;
}

/** The slice of supabase-js the store uses; tests answer it from PGlite (tests/support/pglite-query.ts). */
export interface BriefQueryResult { data: unknown; error: { code?: string; message?: string } | null }
export interface BriefFilter extends PromiseLike<BriefQueryResult> {
  eq(column: string, value: unknown): BriefFilter;
  lt(column: string, value: unknown): BriefFilter;
  order(column: string, opts: { ascending: boolean }): BriefFilter;
  limit(n: number): BriefFilter;
  maybeSingle(): PromiseLike<BriefQueryResult>;
}
export interface BriefDbClient {
  from(table: string): {
    select(columns: string): BriefFilter;
    update(values: Record<string, unknown>): { eq(column: string, value: unknown): { select(columns: string): { maybeSingle(): PromiseLike<BriefQueryResult> } } };
  };
}

const COLUMNS = 'id,brief_date,kind,through_line,spine_movement,items,created_at,audio_status,audio_path,audio_duration_seconds,audio_parts,audio_updated_at';

function failed(what: string, r: BriefQueryResult): never {
  throw new Error(`${what} failed (${r.error?.code ?? 'unknown'})`);
}

const isoDay = (v: unknown): string => (v instanceof Date ? v.toISOString().slice(0, 10) : String(v).slice(0, 10));
const iso = (v: unknown): string => new Date(v as string | Date).toISOString();
const AUDIO_STATUSES: ReadonlySet<string> = new Set(['none', 'making', 'ready', 'failed']);

function toRow(raw: Record<string, unknown>): BriefRow {
  const parts = Array.isArray(raw.audio_parts) ? raw.audio_parts : [];
  return {
    id: String(raw.id),
    briefDate: isoDay(raw.brief_date),
    kind: raw.kind === 'quiet' ? 'quiet' : 'brief',
    throughLine: typeof raw.through_line === 'string' ? raw.through_line : '',
    spineMovement: typeof raw.spine_movement === 'string' ? raw.spine_movement : null,
    items: Array.isArray(raw.items) ? (raw.items as BriefRow['items']) : [],
    createdAt: iso(raw.created_at),
    audioStatus: typeof raw.audio_status === 'string' && AUDIO_STATUSES.has(raw.audio_status) ? (raw.audio_status as AudioStatus) : 'none',
    audioPath: typeof raw.audio_path === 'string' ? raw.audio_path : null,
    audioDurationSeconds: raw.audio_duration_seconds === null || raw.audio_duration_seconds === undefined ? null : Number(raw.audio_duration_seconds),
    audioParts: (parts as Array<Record<string, unknown>>)
      .filter((p) => typeof p.text === 'string' && typeof p.index === 'number' && typeof p.startSeconds === 'number')
      .map((p) => ({ index: p.index as number, startSeconds: p.startSeconds as number, text: p.text as string }))
      .sort((a, b) => a.index - b.index),
    audioUpdatedAt: raw.audio_updated_at ? iso(raw.audio_updated_at) : null,
  };
}

export function supabaseBriefStore(db: BriefDbClient): BriefStore {
  return {
    async latest(userId) {
      const r = await db.from('daily_briefs').select(COLUMNS).eq('user_id', userId).order('brief_date', { ascending: false }).limit(1).maybeSingle();
      if (r.error) failed('briefs latest', r);
      return r.data ? toRow(r.data as Record<string, unknown>) : null;
    },
    async byId(userId, briefId) {
      const r = await db.from('daily_briefs').select(COLUMNS).eq('user_id', userId).eq('id', briefId).maybeSingle();
      if (r.error) failed('briefs by id', r);
      return r.data ? toRow(r.data as Record<string, unknown>) : null;
    },
    async list(userId, beforeDate, limit) {
      let q = db.from('daily_briefs').select(COLUMNS).eq('user_id', userId);
      if (beforeDate) q = q.lt('brief_date', beforeDate);
      const r = await q.order('brief_date', { ascending: false }).limit(limit);
      if (r.error) failed('briefs list', r);
      return ((r.data ?? []) as Record<string, unknown>[]).map(toRow);
    },
    async enabled(userId) {
      const r = await db.from('users').select('daily_brief_enabled').eq('id', userId).maybeSingle();
      if (r.error) failed('brief switch', r);
      return r.data ? (r.data as { daily_brief_enabled: boolean }).daily_brief_enabled === true : null;
    },
    async setEnabled(userId, enabled) {
      const r = await db.from('users').update({ daily_brief_enabled: enabled }).eq('id', userId).select('daily_brief_enabled').maybeSingle();
      if (r.error) failed('brief switch', r);
      return r.data !== null && r.data !== undefined;
    },
  };
}
