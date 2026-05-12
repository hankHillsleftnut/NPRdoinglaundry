/**
 * Stage 1 — current-context outline.
 *
 * Single Claude call (no tools). Given the user's active goals and the last ~14
 * days of insights/observations, produce a concise JSON outline of what's alive
 * for them right now. Stage 2 will reach further back to weave in older context.
 */

import { z } from 'zod';
import { supabaseAdmin, Tables } from '../../utils/supabase.js';
import { jsonChatCompletion } from '../../utils/openai.js';
import { STAGE1_CURRENT_CONTEXT_SYSTEM } from './prompts.js';
import type { DbGoal, DbInsight, DbObservation } from '../../types/index.js';

export const CurrentContextOutlineSchema = z.object({
  theme: z.string(),
  active_threads: z.array(
    z.object({
      title: z.string(),
      summary: z.string(),
      goal_id: z.string().nullable(),
      insight_ids: z.array(z.string()).default([]),
      observation_ids: z.array(z.string()).default([]),
    })
  ),
  open_questions: z.array(z.string()).default([]),
  emotional_tone: z.string(),
  notable_shifts_from_prior_week: z.array(z.string()).default([]),
});

export type CurrentContextOutline = z.infer<typeof CurrentContextOutlineSchema>;

export interface Stage1Input {
  userId: string;
  /** Number of days back to include as "current context". Default 14. */
  daysWindow?: number;
}

export interface Stage1Output {
  outline: CurrentContextOutline;
  goals: DbGoal[];
  insights: DbInsight[];
  observations: DbObservation[];
}

export async function runStage1(input: Stage1Input): Promise<Stage1Output> {
  const days = input.daysWindow ?? 14;
  const since = new Date();
  since.setDate(since.getDate() - days);
  const sinceIso = since.toISOString();

  const [goalsResult, insightsResult, observationsResult] = await Promise.all([
    supabaseAdmin
      .from(Tables.GOALS)
      .select('*')
      .eq('user_id', input.userId)
      .eq('is_active', true),
    supabaseAdmin
      .from(Tables.INSIGHTS)
      .select('*')
      .eq('user_id', input.userId)
      .gte('updated_at', sinceIso)
      .order('updated_at', { ascending: false })
      .limit(40),
    supabaseAdmin
      .from(Tables.OBSERVATIONS)
      .select('*')
      .eq('user_id', input.userId)
      .gte('observation_date', sinceIso)
      .order('observation_date', { ascending: false })
      .limit(80),
  ]);

  if (goalsResult.error) throw new Error(`Stage 1: goals fetch failed: ${goalsResult.error.message}`);
  if (insightsResult.error) throw new Error(`Stage 1: insights fetch failed: ${insightsResult.error.message}`);
  if (observationsResult.error) throw new Error(`Stage 1: observations fetch failed: ${observationsResult.error.message}`);

  const goals = (goalsResult.data ?? []) as DbGoal[];
  const insights = (insightsResult.data ?? []) as DbInsight[];
  const observations = (observationsResult.data ?? []) as DbObservation[];

  if (insights.length === 0 && observations.length === 0) {
    throw new Error('Stage 1: not enough recent data (no insights or observations in the window) to build a current-context outline.');
  }

  const userMessage = buildUserMessage({ goals, insights, observations, days });

  console.log(
    `[v2:stage1] running current-context outline for user=${input.userId} — ${goals.length} goals, ${insights.length} insights, ${observations.length} observations in last ${days}d`
  );

  const raw = await jsonChatCompletion<unknown>(STAGE1_CURRENT_CONTEXT_SYSTEM, userMessage, {
    temperature: 0.4,
    maxTokens: 3000,
  });

  const parsed = CurrentContextOutlineSchema.safeParse(raw);
  if (!parsed.success) {
    console.error('[v2:stage1] schema validation failed:', parsed.error.issues);
    throw new Error(`Stage 1 output failed schema validation: ${parsed.error.message}`);
  }

  console.log(
    `[v2:stage1] outline ready — theme="${parsed.data.theme}", ${parsed.data.active_threads.length} threads`
  );

  return { outline: parsed.data, goals, insights, observations };
}

function buildUserMessage(args: {
  goals: DbGoal[];
  insights: DbInsight[];
  observations: DbObservation[];
  days: number;
}): string {
  const { goals, insights, observations, days } = args;

  const goalLines = goals.map(
    (g) => `- [${g.id}] "${g.title}"${g.description ? ` — ${g.description}` : ''}`
  );

  const insightLines = insights.map(
    (i) =>
      `- [${i.id}] (goal=${i.goal_id ?? 'null'}) "${i.title}"\n    ${i.content}\n    evidence: ${i.evidence_summary}\n    updated: ${i.updated_at}`
  );

  const obsLines = observations.slice(0, 60).map(
    (o) =>
      `- [${o.id}] (goal=${o.goal_id ?? 'null'}, ${o.observation_date}) ${o.content} — ${o.reason_why}`
  );

  return `Window: last ${days} days.

## ACTIVE GOALS
${goalLines.join('\n') || '(none)'}

## RECENT INSIGHTS
${insightLines.join('\n') || '(none)'}

## RECENT OBSERVATIONS
${obsLines.join('\n') || '(none)'}

Produce the current-context outline JSON per the system prompt.`;
}
