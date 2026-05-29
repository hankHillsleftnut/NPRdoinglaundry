import { supabaseAdmin, Tables } from '../utils/supabase.js';
import type { DbPodcastEpisode } from '../types/index.js';

export async function listPodcastEpisodes(
  userId: string,
  limit = 20,
  offset = 0
): Promise<{ episodes: DbPodcastEpisode[]; total: number }> {
  const { data, error, count } = await supabaseAdmin
    .from(Tables.PODCAST_EPISODES)
    .select('*', { count: 'exact' })
    .eq('user_id', userId)
    .eq('status', 'ready')
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1);

  if (error) throw new Error(`Failed to list episodes: ${error.message}`);

  return {
    episodes: (data ?? []) as DbPodcastEpisode[],
    total: count ?? 0,
  };
}

export async function getPodcastEpisode(
  episodeId: string,
  userId: string
): Promise<DbPodcastEpisode | null> {
  const { data, error } = await supabaseAdmin
    .from(Tables.PODCAST_EPISODES)
    .select('*')
    .eq('id', episodeId)
    .eq('user_id', userId)
    .single();

  if (error) return null;
  return data as DbPodcastEpisode;
}

export async function getLatestEpisode(userId: string): Promise<DbPodcastEpisode | null> {
  const { data } = await supabaseAdmin
    .from(Tables.PODCAST_EPISODES)
    .select('*')
    .eq('user_id', userId)
    .eq('status', 'ready')
    .order('created_at', { ascending: false })
    .limit(1)
    .single();

  return (data as DbPodcastEpisode) ?? null;
}
