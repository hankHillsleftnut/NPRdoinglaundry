/**
 * v2 admin / monitoring routes.
 *
 * Backs the MONITORING tab in the admin dashboard:
 *   - browse v2_ingestion + v2_podcast pipeline_runs
 *   - drill into a single run with its agent_tool_traces
 *   - inspect the in-memory system prompts the v2 stages use
 *   - kick a manual run (test harness) for ingestion or podcast generation
 *
 * Mounted at /admin/v2/* and protected by the same admin secret as the rest
 * of /admin/*.
 */

import { Router, Request, Response, NextFunction } from 'express';
import { config } from '../utils/config.js';
import { supabaseAdmin, Tables } from '../utils/supabase.js';
import { runV2Ingestion } from '../v2/ingestion/run-ingestion.js';
import { runV2Podcast } from '../v2/podcast/run-podcast.js';
import {
  INGESTION_SYSTEM,
  STAGE1_CURRENT_CONTEXT_SYSTEM,
  STAGE2_HISTORICAL_AGENT_SYSTEM,
  STAGE3_SCRIPT_SYSTEM,
  STAGE4_EPISODE_SUMMARY_SYSTEM,
  STAGE4_METADATA_SYSTEM,
  ENTRY_METADATA_SYSTEM,
  IMAGE_ANALYSIS_SYSTEM,
  ONBOARDING_REPLY_SYSTEM,
  ONBOARDING_GOALS_EXTRACT_SYSTEM,
} from '../v2/podcast/prompts.js';

export const v2AdminRouter = Router();

function adminAuth(req: Request, res: Response, next: NextFunction): void {
  const secret = (req.query.secret as string) || (req.headers['x-admin-secret'] as string);
  if (!secret || secret !== config.admin.secret) {
    res.status(403).json({ success: false, error: 'Invalid admin secret' });
    return;
  }
  next();
}

v2AdminRouter.use(adminAuth);

// ============================================
// GET /admin/v2/runs
// List v2 pipeline_runs (v2_ingestion + v2_podcast).
// Query params: limit, type, userId
// ============================================
v2AdminRouter.get('/runs', async (req: Request, res: Response) => {
  try {
    const limit = Math.min(parseInt((req.query.limit as string) ?? '50', 10) || 50, 200);
    const runType = req.query.type as string | undefined;
    const userId = req.query.userId as string | undefined;

    let query = supabaseAdmin
      .from(Tables.PIPELINE_RUNS)
      .select('*')
      .order('started_at', { ascending: false })
      .limit(limit);

    if (runType && (runType === 'v2_ingestion' || runType === 'v2_podcast')) {
      query = query.eq('run_type', runType);
    } else {
      query = query.in('run_type', ['v2_ingestion', 'v2_podcast']);
    }

    if (userId) query = query.eq('user_id', userId);

    const { data, error } = await query;
    if (error) throw error;

    res.json({ success: true, data: data ?? [] });
  } catch (err) {
    res.status(500).json({ success: false, error: String(err) });
  }
});

// ============================================
// GET /admin/v2/runs/:id
// Fetch a single pipeline_run plus its agent_tool_traces (in order).
// ============================================
v2AdminRouter.get('/runs/:id', async (req: Request, res: Response) => {
  try {
    const runId = req.params.id;
    const { data: run, error: runError } = await supabaseAdmin
      .from(Tables.PIPELINE_RUNS)
      .select('*')
      .eq('id', runId)
      .maybeSingle();
    if (runError) throw runError;
    if (!run) {
      res.status(404).json({ success: false, error: 'run not found' });
      return;
    }

    const { data: traces, error: tracesError } = await supabaseAdmin
      .from('agent_tool_traces')
      .select('*')
      .eq('pipeline_run_id', runId)
      .order('step_index', { ascending: true });
    if (tracesError) throw tracesError;

    // Pull the episode (if v2_podcast) so the dashboard can show title/script.
    let episode: unknown = null;
    if (run.run_type === 'v2_podcast') {
      const md = (run.metadata ?? {}) as { episode_id?: string };
      if (md.episode_id) {
        const { data: ep } = await supabaseAdmin
          .from(Tables.PODCAST_EPISODES)
          .select('*')
          .eq('id', md.episode_id)
          .maybeSingle();
        episode = ep ?? null;
      }
    }

    res.json({ success: true, data: { run, traces: traces ?? [], episode } });
  } catch (err) {
    res.status(500).json({ success: false, error: String(err) });
  }
});

// ============================================
// GET /admin/v2/prompts
// Read-only view of every system prompt the v2 stages use, straight from
// the in-memory constants. Hot-edit / override is a follow-up — for now this
// is enough to verify the prompt the agent actually saw on a given run.
// ============================================
v2AdminRouter.get('/prompts', async (_req: Request, res: Response) => {
  res.json({
    success: true,
    data: {
      ingestion: { name: 'INGESTION_SYSTEM', content: INGESTION_SYSTEM },
      stage1: { name: 'STAGE1_CURRENT_CONTEXT_SYSTEM', content: STAGE1_CURRENT_CONTEXT_SYSTEM },
      stage2: { name: 'STAGE2_HISTORICAL_AGENT_SYSTEM', content: STAGE2_HISTORICAL_AGENT_SYSTEM },
      stage3: { name: 'STAGE3_SCRIPT_SYSTEM', content: STAGE3_SCRIPT_SYSTEM },
      stage4_summary: { name: 'STAGE4_EPISODE_SUMMARY_SYSTEM', content: STAGE4_EPISODE_SUMMARY_SYSTEM },
      stage4_metadata: { name: 'STAGE4_METADATA_SYSTEM', content: STAGE4_METADATA_SYSTEM },
      entry_metadata: { name: 'ENTRY_METADATA_SYSTEM', content: ENTRY_METADATA_SYSTEM },
      image_analysis: { name: 'IMAGE_ANALYSIS_SYSTEM', content: IMAGE_ANALYSIS_SYSTEM },
      onboarding_reply: { name: 'ONBOARDING_REPLY_SYSTEM', content: ONBOARDING_REPLY_SYSTEM },
      onboarding_extract: {
        name: 'ONBOARDING_GOALS_EXTRACT_SYSTEM',
        content: ONBOARDING_GOALS_EXTRACT_SYSTEM,
      },
    },
  });
});

// ============================================
// POST /admin/v2/test/ingestion
// Test harness — run ingestion for a user. Optionally sweep just the recently
// uploaded raw_content rows.
// Body: { userId: string, sweepHours?: number, maxRawContent?: number }
// ============================================
v2AdminRouter.post('/test/ingestion', async (req: Request, res: Response) => {
  try {
    const { userId, sweepHours, maxRawContent } = req.body ?? {};
    if (!userId || typeof userId !== 'string') {
      res.status(400).json({ success: false, error: 'userId is required' });
      return;
    }

    const result = await runV2Ingestion({
      userId,
      sweepHours: typeof sweepHours === 'number' ? sweepHours : undefined,
      maxRawContent: typeof maxRawContent === 'number' ? maxRawContent : undefined,
    });

    res.json({ success: true, data: result });
  } catch (err) {
    res.status(500).json({ success: false, error: String(err) });
  }
});

// ============================================
// POST /admin/v2/test/podcast
// Test harness — run podcast generation. skipTTS defaults to true to save the
// ElevenLabs cost during testing; flip to false to render real audio.
// Body: { userId: string, daysWindow?: number, skipTTS?: boolean, persona?: string, maxSteps?: number }
// ============================================
v2AdminRouter.post('/test/podcast', async (req: Request, res: Response) => {
  try {
    const { userId, daysWindow, skipTTS = true, persona, maxSteps } = req.body ?? {};
    if (!userId || typeof userId !== 'string') {
      res.status(400).json({ success: false, error: 'userId is required' });
      return;
    }

    const result = await runV2Podcast({
      userId,
      daysWindow: typeof daysWindow === 'number' ? daysWindow : undefined,
      skipTTS: typeof skipTTS === 'boolean' ? skipTTS : true,
      persona: typeof persona === 'string' ? (persona as 'thoughtful_friend' | 'wise_mentor' | 'energetic_host') : undefined,
      stage2MaxSteps: typeof maxSteps === 'number' ? maxSteps : undefined,
      generationType: 'on_demand',
    });

    res.json({
      success: true,
      data: {
        pipelineRunId: result.pipelineRunId,
        episodeId: result.episode.id,
        title: result.episode.title,
        toolCallsStage2: result.toolCallsStage2,
        stepsUsedStage2: result.stepsUsedStage2,
      },
    });
  } catch (err) {
    res.status(500).json({ success: false, error: String(err) });
  }
});
