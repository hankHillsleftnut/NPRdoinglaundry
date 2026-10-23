import type { Router } from 'express';
import { z } from 'zod';
import type { DoorFactory } from '../doors/door.js';
import { DoorError } from '../doors/errors.js';
import type { BriefStore } from '../briefs/store.js';
import type { PodcastStore } from './store.js';
import { beforeFor, decodeCursor, libraryResponse, mergePage } from './map.js';
import { episodeResponse } from './episode-map.js';

/**
 * The podcasts tab (BE3.x.lib; contract 03 §2, Paper PC-1):
 *   GET /v2/podcasts?cursor=&limit=   { hero, upcoming, items, nextCursor }
 * Reads `podcast_episodes` and `daily_briefs` from the shared database; the
 * brain is never called, so the tab keeps working when the brain is down.
 * The log line carries counts only (items listed, unknown episode kinds),
 * never a title, an excerpt or the cursor.
 *
 * One episode (BE3.x.ep; contract 03 §3, Paper PC-2):
 *   GET /v2/episodes/:id   { episode }   legacy shape: lines from the script, audio signed for 1 h
 * Only the caller's own `ready` episode; anything else (another person's id,
 * a missing id, a row still being made or failed) is `not_found`, so an id
 * never tells whether it exists. The log carries the line count, never a word.
 */
export interface PodcastDoorDeps {
  podcasts: PodcastStore;
  briefs: Pick<BriefStore, 'listBeforeCreated'>;
}

const LibraryQuery = z.object({
  cursor: z.string().min(1).max(300).optional(),
  limit: z.coerce.number().int().min(1).max(50).optional(),
}).strict();

const EpisodeById = z.object({ id: z.string().uuid() }).strict();

export const LIBRARY_DEFAULT_LIMIT = 20;

export function mountPodcastDoors(router: Router, door: DoorFactory, deps: PodcastDoorDeps): void {
  router.get('/podcasts', door({
    name: 'podcasts.library',
    bucket: 'read',
    request: LibraryQuery,
    call: async (ctx, q) => {
      const cursor = q.cursor === undefined ? null : decodeCursor(q.cursor);
      if (q.cursor !== undefined && cursor === null) throw new DoorError('invalid_request');
      const limit = q.limit ?? LIBRARY_DEFAULT_LIMIT;
      // One more than a page from each source tells whether anything is left; one more
      // episode again because the hero is taken out of the list.
      const [episodes, briefs] = await Promise.all([
        deps.podcasts.library(ctx.userId, cursor ? beforeFor('episode', cursor) : null, limit + 2),
        deps.briefs.listBeforeCreated(ctx.userId, cursor ? beforeFor('brief', cursor) : null, limit + 1),
      ]);
      // The hero is the newest ready episode: the first row of a first page, else asked for.
      const hero = cursor === null ? (episodes[0] ?? null) : ((await deps.podcasts.library(ctx.userId, null, 1))[0] ?? null);
      const { page, nextCursor } = mergePage(episodes.filter((e) => e.id !== hero?.id), briefs, limit);
      return libraryResponse(cursor === null ? hero : null, page, nextCursor, cursor === null);
    },
    map: (r) => r.library,
    logCounts: (r) => ({
      events: r.library.items.length + (r.library.hero ? 1 : 0),
      ...(r.unknownKinds ? { nulledFields: r.unknownKinds } : {}),
    }),
  }));

  router.get('/episodes/:id', door({
    name: 'episodes.get',
    bucket: 'read',
    request: EpisodeById,
    call: async (ctx, req) => {
      // A store without the method fails closed (`internal`, reported), never a quiet 404.
      if (!deps.podcasts.episode) throw new Error('episodes are not configured');
      const found = await deps.podcasts.episode(ctx.userId, req.id, ctx.now);
      if (!found) throw new DoorError('not_found');
      return episodeResponse(found.row, found.audio);
    },
    map: (r) => ({ episode: r.episode }),
    logCounts: (r) => ({
      events: r.episode.lines.length,
      ...(r.unknown ? { nulledFields: 1 } : {}),
    }),
  }));
}
