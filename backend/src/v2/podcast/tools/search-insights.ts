/**
 * search_insights — embedding search over the insights table. Hydrates each
 * insight with its supporting observations so the agent sees the evidence
 * chain in one call instead of having to follow up with search_observations.
 */

import { supabaseAdmin, Tables } from '../../../utils/supabase.js';
import { generateEmbedding } from '../../../utils/openai.js';
import type { AgentTool } from '../../agent-runtime/types.js';

interface Input {
  query: string;
  date_start?: string;
  date_end?: string;
  goal_id?: string;
  limit?: number;
  similarity_threshold?: number;
  include_supporting_observations?: boolean;
}

interface InsightResult {
  id: string;
  title: string;
  content: string;
  evidence_summary: string;
  goal_id: string | null;
  confidence_score: number;
  created_at: string;
  similarity: number;
  supporting_observations?: Array<{
    id: string;
    content: string;
    reason_why: string;
    observation_date: string;
  }>;
}

interface Output {
  query: string;
  results: InsightResult[];
}

export const searchInsightsTool: AgentTool<Input, Output> = {
  name: 'search_insights',
  description:
    'Embedding-search the user\'s synthesized insights (higher-level conclusions drawn from ' +
    'clusters of observations). Each result is hydrated with its supporting observations so you ' +
    'see the evidence trail. Use an ISO date window to bias toward older insights for long-term ' +
    'pattern continuity. Insights with goal_id=null represent patterns not yet tied to any tracked goal.',
  input_schema: {
    type: 'object',
    properties: {
      query: { type: 'string', description: 'Natural-language query to embed and search against.' },
      date_start: { type: 'string', description: 'Optional ISO timestamp lower bound.' },
      date_end: { type: 'string', description: 'Optional ISO timestamp upper bound.' },
      goal_id: {
        type: 'string',
        description: 'Optional goal UUID. Pass "null" as a string to restrict to insights with no goal.',
      },
      limit: { type: 'number', description: 'Max results. Default 5, max 15.' },
      similarity_threshold: { type: 'number', description: 'Cosine similarity 0..1. Default 0.3.' },
      include_supporting_observations: {
        type: 'boolean',
        description:
          'Whether to hydrate supporting observations for each insight. Default true. Set false to ' +
          'save tokens if you only need titles.',
      },
    },
    required: ['query'],
  },
  async execute(input, ctx) {
    const limit = clamp(input.limit ?? 5, 1, 15);
    const threshold = clamp(input.similarity_threshold ?? 0.3, 0, 1);
    const hydrate = input.include_supporting_observations ?? true;

    const embedding = await generateEmbedding(input.query);

    const { data, error } = await supabaseAdmin.rpc('match_insights_dated', {
      query_embedding: embedding,
      match_threshold: threshold,
      match_count: limit,
      filter_user_id: ctx.userId,
      date_start: input.date_start ?? null,
      date_end: input.date_end ?? null,
      filter_goal_id: input.goal_id && input.goal_id !== 'null' ? input.goal_id : null,
    });

    if (error) {
      throw new Error(`search_insights failed: ${error.message}`);
    }

    type Row = InsightResult & { supporting_observation_ids?: string[] };
    const rows: Row[] = (data ?? []) as Row[];

    const allObsIds = new Set<string>();
    if (hydrate) {
      for (const row of rows) {
        for (const obsId of row.supporting_observation_ids ?? []) {
          allObsIds.add(obsId);
        }
      }
    }

    const obsById = new Map<
      string,
      { id: string; content: string; reason_why: string; observation_date: string }
    >();
    if (hydrate && allObsIds.size > 0) {
      const { data: obsData } = await supabaseAdmin
        .from(Tables.OBSERVATIONS)
        .select('id, content, reason_why, observation_date')
        .in('id', Array.from(allObsIds))
        .eq('user_id', ctx.userId);

      for (const o of (obsData ?? []) as Array<{
        id: string;
        content: string;
        reason_why: string;
        observation_date: string;
      }>) {
        obsById.set(o.id, o);
      }
    }

    const results: InsightResult[] = rows.map((r) => {
      const base: InsightResult = {
        id: r.id,
        title: r.title,
        content: r.content,
        evidence_summary: r.evidence_summary,
        goal_id: r.goal_id,
        confidence_score: Number(r.confidence_score),
        created_at: r.created_at,
        similarity: Number(r.similarity.toFixed(3)),
      };
      if (hydrate) {
        const ids = r.supporting_observation_ids ?? [];
        base.supporting_observations = ids
          .map((id) => obsById.get(id))
          .filter((v): v is NonNullable<typeof v> => v !== undefined);
      }
      return base;
    });

    return { query: input.query, results };
  },
  summarize(output) {
    return {
      text: `${output.results.length} insights for "${output.query.slice(0, 60)}"`,
      itemsCount: output.results.length,
    };
  },
};

function clamp(n: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, n));
}
