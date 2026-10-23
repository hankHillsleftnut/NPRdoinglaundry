import { createdKey, pageBeforeCreated, type BriefDbClient, type CreatedBefore } from '../briefs/store.js';
import { supabaseSignAudio, type SignAudio, type SigningClient } from '../briefs/audio.js';
import type { SignedLink } from '../briefs/map.js';

/**
 * Episodes in the shared database (BE3.x.lib): the brain's `podcast_episodes`
 * rows (root migration 004, `audio_path` from the brain's 154), read here
 * directly with named columns, so the podcasts tab keeps working when the
 * brain is down. Only `ready` rows, only the person's own.
 *
 * The column list is closed on purpose: never the script, the outline, the
 * description or the embedding (the legacy route ships all four).
 * Errors carry the database code only: a message can carry row values.
 */

/** One ready `podcast_episodes` row, as the library reads it. */
export interface EpisodeRow {
  id: string;
  title: string;
  /** `weekly` | `on_demand` | `milestone` today; anything else is kept as given. */
  generationType: string | null;
  episodeNumber: number | null;
  durationSeconds: number | null;
  /** ISO 8601 UTC, ms (what the contract shows). */
  createdAt: string;
  /** `created_at` exactly as the database gave it, for paging. */
  createdKey: string;
  /** `YYYY-MM-DD` (UTC day of `covers_period_*`), or null. */
  coversFrom: string | null;
  coversTo: string | null;
  hasAudio: boolean;
}

/** One ready episode as the player reads it (BE3.x.ep): the library row plus the words. */
export interface EpisodeDetailRow extends EpisodeRow {
  /** The spoken script; read only to build `lines`, never logged. */
  script: string;
  /** The agent's one-line description; shown only when there are no lines. */
  description: string | null;
}

/** An episode with its private audio link (null: no audio, or storage refused). */
export interface EpisodeFound {
  row: EpisodeDetailRow;
  audio: SignedLink | null;
}

export interface PodcastStore {
  /** Ready episodes, newest first by `created_at` then id, strictly after `before` when given; at most `limit`. */
  library(userId: string, before: CreatedBefore | null, limit: number): Promise<EpisodeRow[]>;
  /**
   * The person's own ready episode with this id, its audio signed for an hour
   * from `nowMs`; null for anyone else's, a missing id, or a row not `ready`.
   * Optional so a store built without it fails closed (`internal`) instead of 404ing.
   */
  episode?(userId: string, id: string, nowMs: number): Promise<EpisodeFound | null>;
}

/** The same supabase-js slice the brief store uses (tests answer it from PGlite). */
export type PodcastDbClient = BriefDbClient;

export const EPISODE_COLUMNS = 'id,title,generation_type,episode_number,duration_seconds,created_at,covers_period_start,covers_period_end,audio_path';

/** The player's columns: the library's plus the script and description (never the outline or the embedding). */
export const EPISODE_DETAIL_COLUMNS = `${EPISODE_COLUMNS},description,script`;

/** The brain's private episode audio bucket (BEA.7). */
export const PODCAST_AUDIO_BUCKET = 'podcast-audio';

const day = (v: unknown): string | null => {
  if (v === null || v === undefined) return null;
  const d = v instanceof Date ? v : new Date(String(v));
  return Number.isNaN(d.getTime()) ? null : d.toISOString().slice(0, 10);
};

function toRow(raw: Record<string, unknown>): EpisodeRow {
  return {
    id: String(raw.id),
    title: typeof raw.title === 'string' ? raw.title : '',
    generationType: typeof raw.generation_type === 'string' ? raw.generation_type : null,
    episodeNumber: raw.episode_number === null || raw.episode_number === undefined ? null : Number(raw.episode_number),
    durationSeconds: raw.duration_seconds === null || raw.duration_seconds === undefined ? null : Number(raw.duration_seconds),
    createdAt: new Date(raw.created_at as string | Date).toISOString(),
    createdKey: createdKey(raw.created_at),
    coversFrom: day(raw.covers_period_start),
    coversTo: day(raw.covers_period_end),
    hasAudio: typeof raw.audio_path === 'string' && raw.audio_path.length > 0,
  };
}

function toDetail(raw: Record<string, unknown>): EpisodeDetailRow {
  return {
    ...toRow(raw),
    script: typeof raw.script === 'string' ? raw.script : '',
    description: typeof raw.description === 'string' && raw.description.trim() ? raw.description.trim() : null,
  };
}

/** A signer for the podcast bucket from the client the store already has; none when it has no storage. */
function podcastSigner(db: PodcastDbClient): SignAudio {
  const storage = (db as Partial<SigningClient>).storage;
  if (storage && typeof storage.from === 'function') return supabaseSignAudio({ storage }, undefined, PODCAST_AUDIO_BUCKET);
  return () => {
    console.warn('[podcasts] audio link not signed (no storage)');
    return Promise.resolve(null);
  };
}

/** `signAudio` defaults to signing in `podcast-audio` with `db`'s own storage (supabase-js); tests pass their own. */
export function supabasePodcastStore(db: PodcastDbClient, opts: { signAudio?: SignAudio } = {}): PodcastStore {
  const sign = opts.signAudio ?? podcastSigner(db);
  return {
    async library(userId, before, limit) {
      const base = () => db.from('podcast_episodes').select(EPISODE_COLUMNS).eq('user_id', userId).eq('status', 'ready');
      const rows = await pageBeforeCreated(base, before, limit, 'podcasts library');
      return rows.map(toRow);
    },
    async episode(userId, id, nowMs) {
      // The owner filter is the only guard (the service role skips RLS): never drop it.
      const r = await db.from('podcast_episodes').select(EPISODE_DETAIL_COLUMNS).eq('user_id', userId).eq('id', id).eq('status', 'ready').maybeSingle();
      if (r.error) throw new Error(`podcasts episode failed (${r.error.code ?? 'unknown'})`);
      if (!r.data) return null;
      const raw = r.data as Record<string, unknown>;
      const row = toDetail(raw);
      const path = typeof raw.audio_path === 'string' && raw.audio_path.length > 0 ? raw.audio_path : null;
      return { row, audio: path ? await sign(path, nowMs) : null };
    },
  };
}
