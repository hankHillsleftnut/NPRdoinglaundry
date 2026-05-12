/**
 * v2 podcast orchestrator. Chains Stage 1 → Stage 2 → Stage 3 → Stage 4 with a
 * pipeline_runs row tracking the whole episode generation, and per-stage error
 * boundaries so a failure in one stage marks the episode and pipeline_runs
 * failed without partial state.
 *
 * Call from:
 *   - POST /v2/podcasts/generate (on-demand)
 *   - cron:v2-weekly-podcast (Sunday 06:00 UTC)
 */

import { supabaseAdmin, Tables } from '../../utils/supabase.js';
import { runStage1 } from './stage1-current-context.js';
import { runStage2 } from './stage2-historical-agent.js';
import { runStage3 } from './stage3-script.js';
import { runStage4 } from './stage4-tts.js';
import { getUserPreferences } from './user-preferences.js';
import type { VoicePersona } from '../../services/elevenlabs.js';
import type { DbPodcastEpisode } from '../../types/index.js';

export interface RunPodcastOptions {
  userId: string;
  /** window of days for Stage 1 "current context". default 14. */
  daysWindow?: number;
  /** override the voice persona. otherwise users.voice_persona. */
  persona?: VoicePersona;
  /** skip ElevenLabs (useful in testing). default false. */
  skipTTS?: boolean;
  /** max tool-use iterations in Stage 2. default 8. */
  stage2MaxSteps?: number;
  /** classify the run. default 'weekly'. */
  generationType?: 'weekly' | 'on_demand' | 'milestone';
}

export interface RunPodcastResult {
  episode: DbPodcastEpisode;
  pipelineRunId: string;
  stepsUsedStage2: number;
  toolCallsStage2: number;
}

export async function runV2Podcast(options: RunPodcastOptions): Promise<RunPodcastResult> {
  const {
    userId,
    daysWindow = 14,
    persona,
    skipTTS = false,
    stage2MaxSteps = 8,
    generationType = 'weekly',
  } = options;

  console.log(
    `[v2:orchestrator] starting for user=${userId} daysWindow=${daysWindow} persona=${persona ?? '(user default)'}`
  );

  // ============================================
  // 0. Create pipeline_runs row AND placeholder episode row up front
  // ============================================
  const pipelineRun = await createPipelineRun(userId);
  let episodeId: string | null = null;

  // Track per-stage timings so we can write an observability rollup into
  // pipeline_runs.metadata on completion.
  const runStartedAt = Date.now();
  const stageTimings: Record<string, number> = {};
  const mark = async <T>(label: string, fn: () => Promise<T>): Promise<T> => {
    const t0 = Date.now();
    try {
      return await fn();
    } finally {
      stageTimings[label] = Date.now() - t0;
    }
  };

  try {
    // ============================================
    // 1. Stage 1 — current-context outline
    // ============================================
    const stage1 = await mark('stage1_ms', () => runStage1({ userId, daysWindow }));

    // Resolve prior episode for continuity (chain episodes in a weak linked list)
    const { data: prior } = await supabaseAdmin
      .from(Tables.PODCAST_EPISODES)
      .select('id')
      .eq('user_id', userId)
      .eq('status', 'ready')
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    // Determine next episode number
    const { count: episodeCount } = await supabaseAdmin
      .from(Tables.PODCAST_EPISODES)
      .select('*', { count: 'exact', head: true })
      .eq('user_id', userId)
      .eq('status', 'ready');
    const episodeNumber = (episodeCount ?? 0) + 1;

    const sinceIso = new Date(Date.now() - daysWindow * 24 * 60 * 60 * 1000).toISOString();

    const { data: episodeRow, error: insertError } = await supabaseAdmin
      .from(Tables.PODCAST_EPISODES)
      .insert({
        user_id: userId,
        title: 'Generating...',
        script: '',
        generation_type: generationType,
        status: 'generating',
        insight_ids: stage1.insights.map((i) => i.id),
        goal_ids: stage1.goals.map((g) => g.id),
        episode_number: episodeNumber,
        covers_period_start: sinceIso,
        covers_period_end: new Date().toISOString(),
        previous_episode_id: prior?.id ?? null,
      })
      .select('id')
      .single();

    if (insertError || !episodeRow) {
      throw new Error(`Failed to create placeholder episode: ${insertError?.message}`);
    }
    episodeId = episodeRow.id as string;

    // ============================================
    // 2. Stage 2 — historical agent (tool-use loop)
    // ============================================
    const preferences = await getUserPreferences(userId);

    const stage2 = await mark('stage2_ms', () =>
      runStage2({
        userId,
        pipelineRunId: pipelineRun.id,
        currentContextOutline: stage1.outline,
        goals: stage1.goals,
        preferences,
        maxSteps: stage2MaxSteps,
      })
    );

    // ============================================
    // 3. Stage 3 — production-manager script
    // ============================================
    const stage3 = await mark('stage3_ms', () =>
      runStage3({
        userId,
        currentContextOutline: stage1.outline,
        historicalOutline: stage2.historicalOutline,
        preferences,
      })
    );

    // ============================================
    // 4. Stage 4 — TTS + summary + final row write
    // ============================================
    const stage4 = await mark('stage4_ms', () =>
      runStage4({
        userId,
        script: stage3.script,
        episodeId: episodeId!,
        previousEpisodeId: prior?.id ?? null,
        persona,
        skipTTS,
        stage2ToolCalls: stage2.toolCalls,
        stage2StopReason: stage2.stopReason,
      })
    );

    // ============================================
    // 5. Mark pipeline_runs completed + write observability rollup
    // ============================================
    const metadata = {
      kind: 'v2_podcast' as const,
      episode_id: episodeId,
      generation_type: generationType,
      days_window: daysWindow,
      total_ms: Date.now() - runStartedAt,
      stage_timings_ms: stageTimings,
      stage1: {
        active_threads: stage1.outline.active_threads.length,
        goals: stage1.goals.length,
        insights: stage1.insights.length,
      },
      stage2: {
        steps_used: stage2.stepsUsed,
        stop_reason: stage2.stopReason,
        tool_calls_count: stage2.toolCalls.length,
        // Compact ordered trace for quick eyeballing — full detail lives in
        // agent_tool_traces keyed by this pipeline_run_id.
        tool_calls: stage2.toolCalls.map((c) => ({
          step: c.stepIndex,
          tool: c.toolName,
          input: c.toolInput,
          items: c.toolOutputItemsCount ?? null,
          duration_ms: c.durationMs,
          error: c.errorMessage ?? null,
          output_preview: c.toolOutputSummary?.slice(0, 240) ?? null,
        })),
      },
      stage3: { script_chars: stage3.script.length },
      stage4: {
        skipped_tts: skipTTS,
        duration_sec: stage4.episode.duration_seconds ?? null,
      },
    };

    await supabaseAdmin
      .from(Tables.PIPELINE_RUNS)
      .update({
        status: 'completed',
        completed_at: new Date().toISOString(),
        insights_created: 0,
        observations_created: 0,
        error_message: null,
        metadata,
      })
      .eq('id', pipelineRun.id);

    console.log(
      `[v2:orchestrator] episode ready — "${stage4.title}" (${stage2.toolCalls.length} stage2 tool calls, ${stage2.stepsUsed} steps)`
    );

    return {
      episode: stage4.episode,
      pipelineRunId: pipelineRun.id,
      stepsUsedStage2: stage2.stepsUsed,
      toolCallsStage2: stage2.toolCalls.length,
    };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error('[v2:orchestrator] failed:', message);

    await supabaseAdmin
      .from(Tables.PIPELINE_RUNS)
      .update({
        status: 'failed',
        completed_at: new Date().toISOString(),
        error_message: message,
        metadata: {
          kind: 'v2_podcast' as const,
          failed_at_ms: Date.now() - runStartedAt,
          stage_timings_ms: stageTimings,
          episode_id: episodeId,
        },
      })
      .eq('id', pipelineRun.id);

    if (episodeId) {
      await supabaseAdmin
        .from(Tables.PODCAST_EPISODES)
        .update({
          status: 'failed',
          error_message: message,
        })
        .eq('id', episodeId);
    }

    throw err;
  }
}

async function createPipelineRun(userId: string): Promise<{ id: string }> {
  const { data, error } = await supabaseAdmin
    .from(Tables.PIPELINE_RUNS)
    .insert({
      user_id: userId,
      run_type: 'v2_podcast',
      status: 'running',
      raw_content_ids: [],
      observations_created: 0,
      insights_created: 0,
    })
    .select('id')
    .single();

  if (error || !data) {
    throw new Error(`Failed to create pipeline_runs row: ${error?.message}`);
  }
  return { id: data.id as string };
}
