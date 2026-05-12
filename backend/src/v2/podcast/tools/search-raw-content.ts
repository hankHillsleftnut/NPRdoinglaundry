/**
 * search_raw_content — last-resort tool the agent can call when it really needs
 * to dig into the original voice notes / text entries / docs the user uploaded.
 * Raw content does not currently carry embeddings at write time, so this is an
 * ILIKE keyword search via the search_raw_content_text RPC.
 *
 * The agent is system-prompted to treat this as a last resort because it's
 * expensive in tokens and rarely better than search_observations/search_insights.
 */

import { supabaseAdmin } from '../../../utils/supabase.js';
import type { AgentTool } from '../../agent-runtime/types.js';

interface Input {
  query: string;
  limit?: number;
  content_type?: string;
  max_chars?: number;
}

interface RawResult {
  id: string;
  content_type: string;
  excerpt: string;
  content_date: string | null;
  created_at: string;
}

interface Output {
  query: string;
  results: RawResult[];
}

export const searchRawContentTool: AgentTool<Input, Output> = {
  name: 'search_raw_content',
  description:
    'Last-resort keyword search over the user\'s raw content (voice transcripts, text entries, ' +
    'doc excerpts, screen-time summaries). Use ONLY when search_observations and search_insights ' +
    'cannot find what you need. Expensive in tokens; returns excerpts, not full text.',
  input_schema: {
    type: 'object',
    properties: {
      query: {
        type: 'string',
        description: 'Keyword or phrase to search for. Case-insensitive substring match.',
      },
      limit: {
        type: 'number',
        description: 'Max results. Default 5, max 10.',
      },
      content_type: {
        type: 'string',
        description:
          'Optional content_type filter (voice_recording, text_entry, video_entry, google_docs, ' +
          'screen_time, healthkit, calendar, twitter_bookmarks).',
      },
      max_chars: {
        type: 'number',
        description: 'Max chars to return per result excerpt. Default 400, max 1000.',
      },
    },
    required: ['query'],
  },
  async execute(input, ctx) {
    const limit = clamp(input.limit ?? 5, 1, 10);
    const maxChars = clamp(input.max_chars ?? 400, 100, 1000);

    const { data, error } = await supabaseAdmin.rpc('search_raw_content_text', {
      search_query: input.query,
      filter_user_id: ctx.userId,
      match_count: limit * 3, // over-fetch so we can filter by content_type client-side
    });

    if (error) throw new Error(`search_raw_content failed: ${error.message}`);

    type Row = {
      id: string;
      content_type: string;
      content: string;
      content_date: string | null;
      created_at: string;
    };
    let rows: Row[] = (data ?? []) as Row[];
    if (input.content_type) {
      rows = rows.filter((r) => r.content_type === input.content_type);
    }
    rows = rows.slice(0, limit);

    const results: RawResult[] = rows.map((r) => ({
      id: r.id,
      content_type: r.content_type,
      excerpt: extractExcerpt(r.content, input.query, maxChars),
      content_date: r.content_date,
      created_at: r.created_at,
    }));

    return { query: input.query, results };
  },
  summarize(output) {
    return {
      text: `${output.results.length} raw-content hits for "${output.query.slice(0, 40)}"`,
      itemsCount: output.results.length,
    };
  },
};

function extractExcerpt(content: string, query: string, maxChars: number): string {
  const lower = content.toLowerCase();
  const idx = lower.indexOf(query.toLowerCase());
  if (idx < 0) {
    return content.slice(0, maxChars);
  }
  const half = Math.floor(maxChars / 2);
  const start = Math.max(0, idx - half);
  const end = Math.min(content.length, idx + query.length + half);
  const prefix = start > 0 ? '…' : '';
  const suffix = end < content.length ? '…' : '';
  return `${prefix}${content.slice(start, end)}${suffix}`;
}

function clamp(n: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, n));
}
