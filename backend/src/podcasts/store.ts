import { createdKey, pageBeforeCreated, type BriefDbClient, type CreatedBefore } from '../briefs/store.js';

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

export interface PodcastStore {
  /** Ready episodes, newest first by `created_at` then id, strictly after `before` when given; at most `limit`. */
  library(userId: string, before: CreatedBefore | null, limit: number): Promise<EpisodeRow[]>;
}

/** The same supabase-js slice the brief store uses (tests answer it from PGlite). */
export type PodcastDbClient = BriefDbClient;

export const EPISODE_COLUMNS = 'id,title,generation_type,episode_number,duration_seconds,created_at,covers_period_start,covers_period_end,audio_path';

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

export function supabasePodcastStore(db: PodcastDbClient): PodcastStore {
  return {
    async library(userId, before, limit) {
      const base = () => db.from('podcast_episodes').select(EPISODE_COLUMNS).eq('user_id', userId).eq('status', 'ready');
      const rows = await pageBeforeCreated(base, before, limit, 'podcasts library');
      return rows.map(toRow);
    },
  };
}
