/**
 * Perplexity Sonar Pro Service
 *
 * Provides web-grounded research enrichment for podcast generation.
 * Uses the Perplexity API with the sonar-pro model for real-time
 * web search with citations.
 */

import { config } from '../utils/config.js';
import type { ResearchCitation } from '../types/index.js';

interface PerplexityMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

interface PerplexityCitation {
  url: string;
  text?: string;
}

interface PerplexityResponse {
  id: string;
  model: string;
  choices: Array<{
    message: {
      role: string;
      content: string;
    };
    finish_reason: string;
  }>;
  citations?: PerplexityCitation[] | string[];
}

/**
 * Perform a single research query using Perplexity Sonar Pro.
 * Returns the answer text plus any citations found.
 */
export async function researchQuery(
  query: string,
  systemContext?: string
): Promise<{ answer: string; citations: ResearchCitation[] }> {
  if (!config.perplexity.apiKey) {
    console.warn('[Perplexity] No API key configured, returning empty research.');
    return { answer: '', citations: [] };
  }

  const messages: PerplexityMessage[] = [];

  if (systemContext) {
    messages.push({
      role: 'system',
      content: systemContext,
    });
  }

  messages.push({
    role: 'user',
    content: query,
  });

  const response = await fetch('https://api.perplexity.ai/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${config.perplexity.apiKey}`,
    },
    body: JSON.stringify({
      model: config.perplexity.model,
      messages,
      temperature: 0.2,
      max_tokens: 2048,
      return_citations: true,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Perplexity API error (${response.status}): ${errorText}`);
  }

  const data = (await response.json()) as PerplexityResponse;

  const answerText = data.choices?.[0]?.message?.content ?? '';
  const rawCitations = data.citations ?? [];

  const citations: ResearchCitation[] = rawCitations.map((c) => {
    if (typeof c === 'string') {
      return { query, source: c, snippet: '', url: c };
    }
    return {
      query,
      source: c.text ?? c.url,
      snippet: c.text ?? '',
      url: c.url,
    };
  });

  return { answer: answerText, citations };
}

/**
 * Research multiple queries in parallel (with concurrency limit).
 * Returns a map of query → { answer, citations }.
 */
export async function batchResearch(
  queries: string[],
  systemContext?: string,
  concurrency = 3
): Promise<Map<string, { answer: string; citations: ResearchCitation[] }>> {
  const results = new Map<string, { answer: string; citations: ResearchCitation[] }>();

  // Process in batches of `concurrency`
  for (let i = 0; i < queries.length; i += concurrency) {
    const batch = queries.slice(i, i + concurrency);
    const batchResults = await Promise.all(
      batch.map(async (q) => {
        try {
          const result = await researchQuery(q, systemContext);
          return { query: q, result };
        } catch (err) {
          console.error(`[Perplexity] Research query failed: "${q}"`, err);
          return { query: q, result: { answer: '', citations: [] } };
        }
      })
    );
    for (const { query, result } of batchResults) {
      results.set(query, result);
    }
  }

  return results;
}
