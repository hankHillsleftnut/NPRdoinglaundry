/**
 * v2 ingestion — one Claude call replaces the dual legacy pipeline
 * (extraction + observations + insight-synthesis).
 *
 * Inputs: new raw_content rows + active goals + last 14d of insights.
 * Output: observations[], insights[] (with supporting_observation indices),
 * suggested_goals[].
 *
 * We generate embeddings for every observation and insight before insert, mark
 * the raw_content rows processed, and track the run in pipeline_runs.
 */

import { z } from 'zod';
import { supabaseAdmin, Tables } from '../../utils/supabase.js';
import { jsonChatCompletion, generateEmbeddings } from '../../utils/openai.js';
import { INGESTION_SYSTEM } from '../podcast/prompts.js';
import type { DbGoal, DbInsight, DbRawContent } from '../../types/index.js';

// ============================================
// Zod schemas for the LLM output
// ============================================

const ObservationSchema = z.object({
  raw_content_id: z.string().uuid(),
  content: z.string().min(1),
  reason_why: z.string().min(1),
  goal_id: z.string().uuid().nullable(),
  confidence_score: z.number().min(0).max(1),
  observation_date: z.string(),
});

const InsightSchema = z.object({
  title: z.string().min(1),
  content: z.string().min(1),
  evidence_summary: z.string().min(1),
  supporting_observation_indices: z.array(z.number().int().nonnegative()).default([]),
  goal_id: z.string().uuid().nullable(),
  confidence_score: z.number().min(0).max(1),
});

const SuggestedGoalSchema = z.object({
  title: z.string().min(1),
  rationale: z.string().min(1),
  supporting_observation_indices: z.array(z.number().int().nonnegative()).default([]),
  supporting_insight_indices: z.array(z.number().int().nonnegative()).default([]),
});

const IngestionOutputSchema = z.object({
  observations: z.array(ObservationSchema).default([]),
  insights: z.array(InsightSchema).default([]),
  suggested_goals: z.array(SuggestedGoalSchema).default([]),
});

type IngestionOutput = z.infer<typeof IngestionOutputSchema>;

// ============================================
// Public API
// ============================================

export interface RunIngestionOptions {
  userId: string;
  /** Specific raw_content.id values to process. Leave empty to sweep unprocessed. */
  rawContentIds?: string[];
  /** Sweep window when rawContentIds not provided. Default 24h. */
  sweepHours?: number;
  /** Max raw_content rows to include in one call. Default 10. */
  maxRawContent?: number;
}

export interface RunIngestionResult {
  pipelineRunId: string;
  rawContentCount: number;
  observationsCreated: number;
  insightsCreated: number;
  suggestedGoalsCreated: number;
}

export async function runV2Ingestion(options: RunIngestionOptions): Promise<RunIngestionResult> {
  const { userId, rawContentIds, sweepHours = 24, maxRawContent = 10 } = options;

  const pipelineRun = await createPipelineRun(userId);

  try {
    // ============================================
    // 1. Load data
    // ============================================
    const rawContent = await loadRawContent({
      userId,
      ids: rawContentIds,
      sweepHours,
      limit: maxRawContent,
    });

    if (rawContent.length === 0) {
      console.log(`[v2:ingestion] no new raw content for user=${userId}, skipping`);
      await closePipelineRun(pipelineRun.id, 'completed', 0, 0, null);
      return {
        pipelineRunId: pipelineRun.id,
        rawContentCount: 0,
        observationsCreated: 0,
        insightsCreated: 0,
        suggestedGoalsCreated: 0,
      };
    }

    const since14 = new Date(Date.now() - 14 * 24 * 60 * 60 * 1000).toISOString();
    const [goalsRes, insightsRes] = await Promise.all([
      supabaseAdmin
        .from(Tables.GOALS)
        .select('*')
        .eq('user_id', userId)
        .eq('is_active', true),
      supabaseAdmin
        .from(Tables.INSIGHTS)
        .select('id, title, content, goal_id, updated_at')
        .eq('user_id', userId)
        .gte('updated_at', since14)
        .order('updated_at', { ascending: false })
        .limit(40),
    ]);

    const goals = (goalsRes.data ?? []) as DbGoal[];
    const recentInsights = (insightsRes.data ?? []) as Pick<
      DbInsight,
      'id' | 'title' | 'content' | 'goal_id' | 'updated_at'
    >[];

    console.log(
      `[v2:ingestion] user=${userId} — ${rawContent.length} raw, ${goals.length} goals, ${recentInsights.length} recent insights`
    );

    // ============================================
    // 2. LLM call
    // ============================================
    const userMessage = buildUserMessage({ rawContent, goals, recentInsights });

    const rawOutput = await jsonChatCompletion<unknown>(INGESTION_SYSTEM, userMessage, {
      temperature: 0.3,
      maxTokens: 6000,
    });

    const parsed = IngestionOutputSchema.safeParse(rawOutput);
    if (!parsed.success) {
      console.error('[v2:ingestion] schema validation failed:', parsed.error.issues);
      throw new Error(`Ingestion output failed schema validation: ${parsed.error.message}`);
    }
    const result = parsed.data;

    // Validate raw_content_id references and goal_id references
    validateReferences(result, rawContent, goals);

    // ============================================
    // 3. Embeddings
    // ============================================
    const obsTexts = result.observations.map((o) => `${o.content}\n${o.reason_why}`);
    const insightTexts = result.insights.map(
      (i) => `${i.title}\n${i.content}\n${i.evidence_summary}`
    );

    const [obsEmbeddings, insightEmbeddings] = await Promise.all([
      obsTexts.length ? generateEmbeddings(obsTexts) : Promise.resolve([] as number[][]),
      insightTexts.length ? generateEmbeddings(insightTexts) : Promise.resolve([] as number[][]),
    ]);

    // ============================================
    // 4. Insert observations
    // ============================================
    let observationIds: string[] = [];
    if (result.observations.length > 0) {
      const rows = result.observations.map((o, idx) => ({
        user_id: userId,
        goal_id: o.goal_id,
        raw_content_id: o.raw_content_id,
        content: o.content,
        reason_why: o.reason_why,
        confidence_score: o.confidence_score,
        observation_date: o.observation_date,
        embedding: obsEmbeddings[idx] ?? null,
        metadata: { pipeline_version: 'v2' },
      }));

      const { data, error } = await supabaseAdmin
        .from(Tables.OBSERVATIONS)
        .insert(rows)
        .select('id');

      if (error) throw new Error(`observations insert failed: ${error.message}`);
      observationIds = (data ?? []).map((r) => r.id as string);
    }

    // ============================================
    // 5. Insert insights (remap indices -> UUIDs)
    // ============================================
    let insightIds: string[] = [];
    if (result.insights.length > 0) {
      const now = new Date().toISOString();
      const rows = result.insights.map((i, idx) => ({
        user_id: userId,
        goal_id: i.goal_id,
        title: i.title,
        content: i.content,
        evidence_summary: i.evidence_summary,
        supporting_observation_ids: i.supporting_observation_indices
          .map((n) => observationIds[n])
          .filter((v): v is string => Boolean(v)),
        confidence_score: i.confidence_score,
        time_range_start: earliestObservationDate(result.observations, i.supporting_observation_indices),
        time_range_end: now,
        embedding: insightEmbeddings[idx] ?? null,
        metadata: { pipeline_version: 'v2' },
      }));

      const { data, error } = await supabaseAdmin
        .from(Tables.INSIGHTS)
        .insert(rows)
        .select('id');

      if (error) throw new Error(`insights insert failed: ${error.message}`);
      insightIds = (data ?? []).map((r) => r.id as string);
    }

    // ============================================
    // 6. Insert suggested_goals (remap indices -> UUIDs)
    // ============================================
    let suggestedGoalsCreated = 0;
    if (result.suggested_goals.length > 0) {
      const rows = result.suggested_goals.map((sg) => ({
        user_id: userId,
        title: sg.title,
        rationale: sg.rationale,
        supporting_observation_ids: sg.supporting_observation_indices
          .map((n) => observationIds[n])
          .filter((v): v is string => Boolean(v)),
        supporting_insight_ids: sg.supporting_insight_indices
          .map((n) => insightIds[n])
          .filter((v): v is string => Boolean(v)),
        status: 'pending' as const,
      }));

      const { error } = await supabaseAdmin.from('suggested_goals').insert(rows);
      if (error) throw new Error(`suggested_goals insert failed: ${error.message}`);
      suggestedGoalsCreated = rows.length;
    }

    // ============================================
    // 7. Mark raw_content rows processed
    // ============================================
    const rawIds = rawContent.map((r) => r.id);
    await supabaseAdmin
      .from(Tables.RAW_CONTENT)
      .update({
        processing_status: 'completed',
        processed_at: new Date().toISOString(),
      })
      .in('id', rawIds)
      .eq('user_id', userId);

    // ============================================
    // 8. Close pipeline_runs
    // ============================================
    await closePipelineRun(
      pipelineRun.id,
      'completed',
      observationIds.length,
      insightIds.length,
      null,
      rawIds
    );

    console.log(
      `[v2:ingestion] user=${userId} done — ${observationIds.length} observations, ${insightIds.length} insights, ${suggestedGoalsCreated} suggested goals`
    );

    return {
      pipelineRunId: pipelineRun.id,
      rawContentCount: rawContent.length,
      observationsCreated: observationIds.length,
      insightsCreated: insightIds.length,
      suggestedGoalsCreated,
    };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error('[v2:ingestion] failed:', message);
    await closePipelineRun(pipelineRun.id, 'failed', 0, 0, message);
    throw err;
  }
}

// ============================================
// helpers
// ============================================

async function createPipelineRun(userId: string): Promise<{ id: string }> {
  const { data, error } = await supabaseAdmin
    .from(Tables.PIPELINE_RUNS)
    .insert({
      user_id: userId,
      run_type: 'v2_ingestion',
      status: 'running',
      raw_content_ids: [],
    })
    .select('id')
    .single();
  if (error || !data) throw new Error(`Failed to create pipeline_runs row: ${error?.message}`);
  return { id: data.id as string };
}

async function closePipelineRun(
  runId: string,
  status: 'completed' | 'failed',
  observationsCreated: number,
  insightsCreated: number,
  errorMessage: string | null,
  rawContentIds?: string[]
): Promise<void> {
  const update: Record<string, unknown> = {
    status,
    completed_at: new Date().toISOString(),
    observations_created: observationsCreated,
    insights_created: insightsCreated,
    error_message: errorMessage,
  };
  if (rawContentIds) update.raw_content_ids = rawContentIds;

  await supabaseAdmin.from(Tables.PIPELINE_RUNS).update(update).eq('id', runId);
}

async function loadRawContent(args: {
  userId: string;
  ids?: string[];
  sweepHours: number;
  limit: number;
}): Promise<DbRawContent[]> {
  if (args.ids && args.ids.length > 0) {
    const { data, error } = await supabaseAdmin
      .from(Tables.RAW_CONTENT)
      .select('*')
      .in('id', args.ids)
      .eq('user_id', args.userId);
    if (error) throw new Error(`raw_content fetch failed: ${error.message}`);
    return (data ?? []) as DbRawContent[];
  }

  const since = new Date(Date.now() - args.sweepHours * 60 * 60 * 1000).toISOString();
  const { data, error } = await supabaseAdmin
    .from(Tables.RAW_CONTENT)
    .select('*')
    .eq('user_id', args.userId)
    .in('processing_status', ['pending', 'processing'])
    .gte('created_at', since)
    .order('created_at', { ascending: false })
    .limit(args.limit);
  if (error) throw new Error(`raw_content sweep failed: ${error.message}`);
  return (data ?? []) as DbRawContent[];
}

function buildUserMessage(args: {
  rawContent: DbRawContent[];
  goals: DbGoal[];
  recentInsights: Pick<DbInsight, 'id' | 'title' | 'content' | 'goal_id' | 'updated_at'>[];
}): string {
  const rawLines = args.rawContent.map(
    (r) =>
      `- id: ${r.id}\n  content_type: ${r.content_type}\n  content_date: ${r.content_date ?? r.created_at}\n  content: |\n${indent(r.content.slice(0, 8000), 4)}`
  );

  const goalLines = args.goals.map(
    (g) => `- [${g.id}] "${g.title}"${g.description ? ` — ${g.description}` : ''}`
  );

  const insightLines = args.recentInsights.map(
    (i) => `- [${i.id}] (goal=${i.goal_id ?? 'null'}) "${i.title}" — ${i.content}`
  );

  return `## NEW_CONTENT
${rawLines.join('\n\n') || '(none)'}

## ACTIVE_GOALS
${goalLines.join('\n') || '(none)'}

## RECENT_INSIGHTS (last 14 days)
${insightLines.join('\n') || '(none)'}

Produce the ingestion JSON per the system prompt.`;
}

function validateReferences(out: IngestionOutput, rawContent: DbRawContent[], goals: DbGoal[]): void {
  const rawIds = new Set(rawContent.map((r) => r.id));
  const goalIds = new Set(goals.map((g) => g.id));

  for (const obs of out.observations) {
    if (!rawIds.has(obs.raw_content_id)) {
      throw new Error(
        `Ingestion produced an observation referencing unknown raw_content_id=${obs.raw_content_id}`
      );
    }
    if (obs.goal_id && !goalIds.has(obs.goal_id)) {
      throw new Error(
        `Ingestion observation referenced unknown goal_id=${obs.goal_id} — the model must use null for unassigned`
      );
    }
  }

  for (const ins of out.insights) {
    if (ins.goal_id && !goalIds.has(ins.goal_id)) {
      throw new Error(
        `Ingestion insight referenced unknown goal_id=${ins.goal_id}`
      );
    }
    for (const idx of ins.supporting_observation_indices) {
      if (idx < 0 || idx >= out.observations.length) {
        throw new Error(
          `Ingestion insight referenced supporting_observation_index=${idx} out of range (0..${out.observations.length - 1})`
        );
      }
    }
  }

  for (const sg of out.suggested_goals) {
    for (const idx of sg.supporting_observation_indices) {
      if (idx < 0 || idx >= out.observations.length) {
        throw new Error(
          `Suggested goal referenced supporting_observation_index=${idx} out of range`
        );
      }
    }
    for (const idx of sg.supporting_insight_indices) {
      if (idx < 0 || idx >= out.insights.length) {
        throw new Error(
          `Suggested goal referenced supporting_insight_index=${idx} out of range`
        );
      }
    }
  }
}

function earliestObservationDate(
  observations: IngestionOutput['observations'],
  indices: number[]
): string | null {
  if (indices.length === 0) return null;
  const dates = indices
    .map((i) => observations[i]?.observation_date)
    .filter((d): d is string => Boolean(d));
  if (dates.length === 0) return null;
  return dates.sort()[0] ?? null;
}

function indent(text: string, spaces: number): string {
  const pad = ' '.repeat(spaces);
  return text
    .split('\n')
    .map((line) => `${pad}${line}`)
    .join('\n');
}
