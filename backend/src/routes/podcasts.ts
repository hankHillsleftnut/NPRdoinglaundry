/**
 * Podcast Routes
 *
 * Endpoints for listing, retrieving, and (admin) triggering podcast generation.
 */

import { Router, Request, Response } from 'express';
import {
  listPodcastEpisodes,
  getPodcastEpisode,
  getLatestEpisode,
} from '../services/podcast-db.js';
import { generateAgentPodcast } from '../services/agent-client.js';

export const podcastsRouter = Router();

/**
 * GET /podcasts
 * List podcast episodes for the authenticated user.
 */
podcastsRouter.get('/', async (req: Request, res: Response) => {
  try {
    const userId = req.user!.id;
    const limit = parseInt(req.query.limit as string) || 20;
    const offset = parseInt(req.query.offset as string) || 0;

    const { episodes, total } = await listPodcastEpisodes(userId, limit, offset);

    res.json({
      success: true,
      data: episodes,
      pagination: {
        total,
        limit,
        offset,
        hasMore: offset + limit < total,
      },
    });
  } catch (err) {
    console.error('[Podcasts] List error:', err);
    res.status(500).json({
      success: false,
      error: err instanceof Error ? err.message : 'Failed to list episodes',
    });
  }
});

/**
 * GET /podcasts/latest
 * Get the most recent podcast episode.
 */
podcastsRouter.get('/latest', async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user!.id;
    const episode = await getLatestEpisode(userId);

    if (!episode) {
      res.status(404).json({
        success: false,
        error: 'No podcast episodes found',
      });
      return;
    }

    res.json({ success: true, data: episode });
  } catch (err) {
    console.error('[Podcasts] Latest error:', err);
    res.status(500).json({
      success: false,
      error: err instanceof Error ? err.message : 'Failed to get latest episode',
    });
  }
});

/**
 * GET /podcasts/:id
 * Get a specific podcast episode by ID.
 */
podcastsRouter.get('/:id', async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user!.id;
    const episodeId = req.params.id!;

    const episode = await getPodcastEpisode(episodeId, userId);

    if (!episode) {
      res.status(404).json({
        success: false,
        error: 'Episode not found',
      });
      return;
    }

    res.json({ success: true, data: episode });
  } catch (err) {
    console.error('[Podcasts] Get error:', err);
    res.status(500).json({
      success: false,
      error: err instanceof Error ? err.message : 'Failed to get episode',
    });
  }
});

/**
 * POST /podcasts/generate
 * Trigger on-demand podcast generation for the authenticated user.
 */
podcastsRouter.post('/generate', async (req: Request, res: Response) => {
  try {
    const userId = req.user!.id;
    const { daysSince, daysBack, skipTTS, persona } = req.body ?? {};

    const agentResult = await generateAgentPodcast({
      userId,
      daysBack: daysBack ?? daysSince ?? 14,
      skipTTS: skipTTS ?? false,
      persona,
    });

    if (!agentResult.episodeId) {
      throw new Error('Agent generated a podcast but did not return an episode id');
    }

    const episode = await getPodcastEpisode(agentResult.episodeId, userId);
    if (!episode) {
      throw new Error(`Agent episode ${agentResult.episodeId} was not found after generation`);
    }

    res.json({ success: true, data: episode });
  } catch (err) {
    console.error('[Podcasts] Generate error:', err);
    res.status(500).json({
      success: false,
      error: err instanceof Error ? err.message : 'Failed to generate episode',
    });
  }
});
