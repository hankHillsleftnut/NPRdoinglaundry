/**
 * search_previous_podcasts — similarity search over past episode summaries.
 * Used by the Stage 2 agent for non-repetition ("what did the last few episodes
 * already cover?") and for continuity callbacks ("we talked about X three weeks
 * ago — reconnect to it").
 *
 * Recent episodes without an embedding yet fall back to title/description text.
 */

import { supabaseAdmin, Tables } from '../../../utils/supabase.js';
import { generateEmbedding } from '../../../utils/openai.js';
import type { AgentTool } from '../../agent-runtime/types.js';

interface Input {
  query?: string;
  limit?: number;
  similarity_threshold?: number;
  /** When true, returns the most recent N episodes instead of doing similarity search. */
  recent?: boolean;
}

interface EpisodeResult {
  id: string;
  title: string;
  summary: string | null;
  episode_number: number | null;
  created_at: string;
  similarity?: number;
}

interface Output {
  mode: 'recent' | 'similarity';
  results: EpisodeResult[];
}

export const searchPreviousPodcastsTool: AgentTool<Input, Output> = {
  name: 'search_previous_podcasts',
  description:
    'Look up previous podcast episodes the user has already received. Each episode carries a ' +
    '2-paragraph summary. Set recent=true (no query) to get the most recent episodes for ' +
    'non-repetition checks. Pass a query (recent=false or omitted) to similarity-search ' +
    'summaries for continuity callbacks.',
  input_schema: {
    type: 'object',
    properties: {
      query: {
        type: 'string',
        description: 'Natural-language query. Ignored when recent=true.',
      },
      limit: {
        type: 'number',
        description: 'Max episodes to return. Default 3, max 10.',
      },
      similarity_threshold: {
        type: 'number',
        description: 'Cosine similarity threshold 0..1 for query mode. Default 0.2.',
      },
      recent: {
        type: 'boolean',
        description:
          'If true, return the N most recent episodes by created_at (no query needed). ' +
          'Use this at the top of a run to survey what the last few episodes already covered.',
      },
    },
  },
  async execute(input, ctx) {
    const limit = clamp(input.limit ?? 3, 1, 10);

    if (input.recent || !input.query) {
      const { data, error } = await supabaseAdmin
        .from(Tables.PODCAST_EPISODES)
        .select('id, title, summary, episode_number, created_at')
        .eq('user_id', ctx.userId)
        .eq('status', 'ready')
        .order('created_at', { ascending: false })
        .limit(limit);

      if (error) throw new Error(`search_previous_podcasts (recent) failed: ${error.message}`);

      return {
        mode: 'recent',
        results: (data ?? []) as EpisodeResult[],
      };
    }

    const threshold = clamp(input.similarity_threshold ?? 0.2, 0, 1);
    const embedding = await generateEmbedding(input.query);

    const { data, error } = await supabaseAdmin.rpc('match_podcast_episodes', {
      query_embedding: embedding,
      match_threshold: threshold,
      match_count: limit,
      filter_user_id: ctx.userId,
    });

    if (error) throw new Error(`search_previous_podcasts (similarity) failed: ${error.message}`);

    const results: EpisodeResult[] = ((data ?? []) as EpisodeResult[]).map((r) => ({
      id: r.id,
      title: r.title,
      summary: r.summary,
      episode_number: r.episode_number,
      created_at: r.created_at,
      similarity:
        typeof r.similarity === 'number' ? Number(r.similarity.toFixed(3)) : undefined,
    }));

    return { mode: 'similarity', results };
  },
  summarize(output) {
    return {
      text: `${output.mode}: ${output.results.length} prior episodes`,
      itemsCount: output.results.length,
    };
  },
};

function clamp(n: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, n));
}
