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
import { captureException } from '../services/telemetry.js';

export interface PodcastRouteDeps {
  listPodcastEpisodes: typeof listPodcastEpisodes;
  getPodcastEpisode: typeof getPodcastEpisode;
  getLatestEpisode: typeof getLatestEpisode;
  generateAgentPodcast: typeof generateAgentPodcast;
  /** Where failure details go (Sentry); the client only ever gets a generic message. */
  report: (err: unknown, context: Record<string, unknown>) => void;
}

/** The podcast routes, with their dependencies passed in so failures are tested over HTTP. */
export function createPodcastsRouter(deps: PodcastRouteDeps): Router {
  const podcastsRouter = Router();

  /**
   * GET /podcasts
   * List podcast episodes for the authenticated user.
   */
  podcastsRouter.get('/', async (req: Request, res: Response) => {
    try {
      const userId = req.user!.id;
      const limit = parseInt(req.query.limit as string) || 20;
      const offset = parseInt(req.query.offset as string) || 0;

      const { episodes, total } = await deps.listPodcastEpisodes(userId, limit, offset);

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
      deps.report(err, { route: 'podcasts.list' });
      res.status(500).json({
        success: false,
        error: 'Failed to list episodes',
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
      const episode = await deps.getLatestEpisode(userId);

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
      deps.report(err, { route: 'podcasts.latest' });
      res.status(500).json({
        success: false,
        error: 'Failed to get latest episode',
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

      const episode = await deps.getPodcastEpisode(episodeId, userId);

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
      deps.report(err, { route: 'podcasts.get' });
      res.status(500).json({
        success: false,
        error: 'Failed to get episode',
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

      const agentResult = await deps.generateAgentPodcast({
        userId,
        daysBack: daysBack ?? daysSince ?? 14,
        skipTTS: skipTTS ?? false,
        persona,
      });

      if (!agentResult.episodeId) {
        throw new Error('Agent generated a podcast but did not return an episode id');
      }

      const episode = await deps.getPodcastEpisode(agentResult.episodeId, userId);
      if (!episode) {
        throw new Error(`Agent episode ${agentResult.episodeId} was not found after generation`);
      }

      res.json({ success: true, data: episode });
    } catch (err) {
      console.error('[Podcasts] Generate error:', err);
      deps.report(err, { route: 'podcasts.generate' });
      res.status(500).json({
        success: false,
        error: 'Failed to generate episode',
      });
    }
  });

  return podcastsRouter;
}

export const podcastsRouter = createPodcastsRouter({
  listPodcastEpisodes,
  getPodcastEpisode,
  getLatestEpisode,
  generateAgentPodcast,
  report: captureException,
});
