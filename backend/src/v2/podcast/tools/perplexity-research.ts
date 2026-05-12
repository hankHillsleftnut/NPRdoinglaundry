/**
 * perplexity_research — optional tool for pulling in external research
 * (academic papers, studies, evidence-based techniques). Thin wrapper around
 * services/perplexity.ts.
 *
 * Gracefully degrades if PERPLEXITY_API_KEY is not set — returns empty citations
 * rather than throwing.
 */

import { batchResearch } from '../../../services/perplexity.js';
import { config } from '../../../utils/config.js';
import type { AgentTool } from '../../agent-runtime/types.js';
import type { ResearchCitation } from '../../../types/index.js';

interface Input {
  queries: string[];
  context?: string;
}

interface QueryResult {
  query: string;
  answer: string;
  citations: ResearchCitation[];
}

interface Output {
  results: QueryResult[];
  citations_total: number;
  api_configured: boolean;
}

export const perplexityResearchTool: AgentTool<Input, Output> = {
  name: 'perplexity_research',
  description:
    'Research external sources (academic papers, evidence-based techniques, public data) via ' +
    'Perplexity Sonar. Use sparingly — only for information the user\'s own data cannot answer, ' +
    'such as CBT research, frameworks, or recent news tied to their goals. Returns answers and ' +
    'citations per query.',
  input_schema: {
    type: 'object',
    properties: {
      queries: {
        type: 'array',
        items: { type: 'string' },
        description: 'One or more research questions to run in parallel. Max 5 per call.',
      },
      context: {
        type: 'string',
        description:
          'Optional system context for the research assistant (e.g. "focus on CBT techniques for ' +
          'challenging catastrophizing").',
      },
    },
    required: ['queries'],
  },
  async execute(input) {
    if (!config.perplexity.apiKey) {
      return {
        results: input.queries.map((q) => ({ query: q, answer: '', citations: [] })),
        citations_total: 0,
        api_configured: false,
      };
    }

    const queries = input.queries.slice(0, 5);
    const resultMap = await batchResearch(queries, input.context);

    const results: QueryResult[] = queries.map((q) => {
      const r = resultMap.get(q) ?? { answer: '', citations: [] };
      return { query: q, answer: r.answer, citations: r.citations };
    });

    const citations_total = results.reduce((sum, r) => sum + r.citations.length, 0);

    return { results, citations_total, api_configured: true };
  },
  summarize(output) {
    return {
      text: `${output.results.length} research queries, ${output.citations_total} citations`,
      itemsCount: output.citations_total,
    };
  },
};
