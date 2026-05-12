/**
 * v2 podcast routes
 *
 *   POST /v2/podcasts/generate    — run the v2 orchestrator (on-demand)
 *   GET  /v2/podcasts/:id         — fetch a v2 episode
 *   GET  /v2/podcasts             — list v2 episodes for the user
 */

import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { supabaseAdmin, Tables } from '../../utils/supabase.js';
import { runV2Podcast } from '../podcast/run-podcast.js';
import type { VoicePersona } from '../../services/elevenlabs.js';

export const v2PodcastsRouter = Router();

const GenerateBodySchema = z.object({
  daysWindow: z.number().int().min(1).max(90).optional(),
  persona: z.enum(['thoughtful_friend', 'wise_mentor', 'energetic_host']).optional(),
  skipTTS: z.boolean().optional(),
  stage2MaxSteps: z.number().int().min(1).max(20).optional(),
  generationType: z.enum(['weekly', 'on_demand', 'milestone']).optional(),
});

v2PodcastsRouter.post('/generate', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const parsed = GenerateBodySchema.safeParse(req.body ?? {});
    if (!parsed.success) {
      res.status(400).json({
        success: false,
        error: 'Invalid body',
        details: parsed.error.errors,
      });
      return;
    }

    const result = await runV2Podcast({
      userId: user.id,
      daysWindow: parsed.data.daysWindow,
      persona: parsed.data.persona as VoicePersona | undefined,
      skipTTS: parsed.data.skipTTS,
      stage2MaxSteps: parsed.data.stage2MaxSteps,
      generationType: parsed.data.generationType ?? 'on_demand',
    });

    res.json({
      success: true,
      data: {
        episode: result.episode,
        pipelineRunId: result.pipelineRunId,
        stage2: {
          stepsUsed: result.stepsUsedStage2,
          toolCalls: result.toolCallsStage2,
        },
      },
    });
  } catch (err) {
    console.error('[v2:podcasts] generate failed:', err);
    res.status(500).json({
      success: false,
      error: err instanceof Error ? err.message : 'Podcast generation failed',
    });
  }
});

v2PodcastsRouter.get('/:id', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const { id } = req.params;
    const { data, error } = await supabaseAdmin
      .from(Tables.PODCAST_EPISODES)
      .select('*')
      .eq('id', id)
      .eq('user_id', user.id)
      .single();

    if (error || !data) {
      res.status(404).json({ success: false, error: 'Episode not found' });
      return;
    }

    res.json({ success: true, data });
  } catch (err) {
    console.error('[v2:podcasts] get failed:', err);
    res.status(500).json({
      success: false,
      error: err instanceof Error ? err.message : 'Failed to load episode',
    });
  }
});

v2PodcastsRouter.get('/', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const limit = Math.min(Number(req.query.limit ?? 20), 100);
    const offset = Number(req.query.offset ?? 0);

    const { data, error, count } = await supabaseAdmin
      .from(Tables.PODCAST_EPISODES)
      .select('*', { count: 'exact' })
      .eq('user_id', user.id)
      .eq('status', 'ready')
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) throw new Error(error.message);

    res.json({
      success: true,
      data: data ?? [],
      pagination: {
        total: count ?? 0,
        limit,
        offset,
        hasMore: (count ?? 0) > offset + limit,
      },
    });
  } catch (err) {
    console.error('[v2:podcasts] list failed:', err);
    res.status(500).json({
      success: false,
      error: err instanceof Error ? err.message : 'Failed to list episodes',
    });
  }
});
