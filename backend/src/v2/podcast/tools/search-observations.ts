/**
 * search_observations — embedding search over the observations table with an
 * optional ISO date range and optional goal filter. Used by the Stage 2
 * historical agent to pull older context relevant to a query.
 */

import { supabaseAdmin } from '../../../utils/supabase.js';
import { generateEmbedding } from '../../../utils/openai.js';
import type { AgentTool } from '../../agent-runtime/types.js';

interface Input {
  query: string;
  date_start?: string;
  date_end?: string;
  goal_id?: string;
  limit?: number;
  similarity_threshold?: number;
}

interface ObservationResult {
  id: string;
  content: string;
  reason_why: string;
  goal_id: string | null;
  observation_date: string;
  similarity: number;
}

interface Output {
  query: string;
  results: ObservationResult[];
}

export const searchObservationsTool: AgentTool<Input, Output> = {
  name: 'search_observations',
  description:
    'Embedding-search the user\'s observations (atomic moments pulled from raw content). ' +
    'Use this to find older observations relevant to the current-context outline. ' +
    'Pass an ISO date_start/date_end to restrict the window (e.g. older than 30 days). ' +
    'Returns ranked observations with content and reason_why.',
  input_schema: {
    type: 'object',
    properties: {
      query: {
        type: 'string',
        description: 'Natural-language query to embed and search against.',
      },
      date_start: {
        type: 'string',
        description: 'Optional ISO timestamp. Only observations on or after this date are returned.',
      },
      date_end: {
        type: 'string',
        description: 'Optional ISO timestamp. Only observations on or before this date are returned.',
      },
      goal_id: {
        type: 'string',
        description: 'Optional goal UUID. Restricts results to observations tied to this goal.',
      },
      limit: {
        type: 'number',
        description: 'Max results to return. Default 10, max 25.',
      },
      similarity_threshold: {
        type: 'number',
        description: 'Cosine similarity threshold 0..1. Default 0.3.',
      },
    },
    required: ['query'],
  },
  async execute(input, ctx) {
    const limit = clamp(input.limit ?? 10, 1, 25);
    const threshold = clamp(input.similarity_threshold ?? 0.3, 0, 1);

    const embedding = await generateEmbedding(input.query);

    const { data, error } = await supabaseAdmin.rpc('match_observations_dated', {
      query_embedding: embedding,
      match_threshold: threshold,
      match_count: limit,
      filter_user_id: ctx.userId,
      date_start: input.date_start ?? null,
      date_end: input.date_end ?? null,
      filter_goal_id: input.goal_id ?? null,
    });

    if (error) {
      throw new Error(`search_observations failed: ${error.message}`);
    }

    const results: ObservationResult[] = ((data ?? []) as ObservationResult[]).map((r) => ({
      id: r.id,
      content: r.content,
      reason_why: r.reason_why,
      goal_id: r.goal_id,
      observation_date: r.observation_date,
      similarity: Number(r.similarity.toFixed(3)),
    }));

    return { query: input.query, results };
  },
  summarize(output) {
    return {
      text: `${output.results.length} observations for "${output.query.slice(0, 60)}"`,
      itemsCount: output.results.length,
    };
  },
};

function clamp(n: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, n));
}
