/**
 * Tool registry for the Stage 2 historical agent. Import from here so every
 * caller uses the same canonical set and ordering.
 */

import type { AgentTool } from '../../agent-runtime/types.js';
import { searchObservationsTool } from './search-observations.js';
import { searchInsightsTool } from './search-insights.js';
import { searchPreviousPodcastsTool } from './search-previous-podcasts.js';
import { searchRawContentTool } from './search-raw-content.js';
import { perplexityResearchTool } from './perplexity-research.js';

// Tools are generic over their own input/output shapes. The agent runtime
// treats the registry as a heterogenous list — `AgentTool<any, any>[]` is the
// straightforward way to express that without fighting TS variance.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const historicalAgentTools: AgentTool<any, any>[] = [
  searchObservationsTool,
  searchInsightsTool,
  searchPreviousPodcastsTool,
  searchRawContentTool,
  perplexityResearchTool,
];

export {
  searchObservationsTool,
  searchInsightsTool,
  searchPreviousPodcastsTool,
  searchRawContentTool,
  perplexityResearchTool,
};
