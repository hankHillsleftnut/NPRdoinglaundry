/**
 * Cron job: Weekly Podcast Generation
 *
 * Generates a podcast episode for every user who has enough
 * recent data (insights + observations from the past 7 days).
 *
 * Scheduled: Sundays at 6 AM UTC (after pattern detection + pipeline).
 * Can also be run manually: npm run cron:podcasts
 */

import { supabaseAdmin, Tables } from '../utils/supabase.js';
import {
  generatePodcastEpisode,
  getLatestEpisode,
} from '../services/podcast-generation.js';

export async function runWeeklyPodcastGeneration(): Promise<void> {
  console.log('[PodcastCron] Starting weekly podcast generation...');

  // Find users who have insights updated in the last 7 days
  const since = new Date();
  since.setDate(since.getDate() - 7);
  const sinceStr = since.toISOString();

  const { data: recentInsights, error } = await supabaseAdmin
    .from(Tables.INSIGHTS)
    .select('user_id')
    .gte('updated_at', sinceStr);

  if (error) {
    console.error('[PodcastCron] Failed to fetch users with recent insights:', error);
    return;
  }

  // Deduplicate user IDs
  const userIds = [...new Set((recentInsights || []).map((i) => i.user_id))];

  if (userIds.length === 0) {
    console.log('[PodcastCron] No users with recent insights. Skipping.');
    return;
  }

  console.log(`[PodcastCron] Generating podcasts for ${userIds.length} user(s)...`);

  let successCount = 0;
  let failCount = 0;

  for (const userId of userIds) {
    try {
      console.log(`[PodcastCron] User ${userId}: generating episode...`);

      // Get previous episode for continuity
      const latestEp = await getLatestEpisode(userId);

      const episode = await generatePodcastEpisode({
        userId,
        daysSince: 7,
        previousEpisodeId: latestEp?.id,
        generationType: 'weekly',
      });

      console.log(
        `[PodcastCron] User ${userId}: episode "${episode.title}" ready (${episode.id}).`
      );
      successCount++;
    } catch (err) {
      console.error(`[PodcastCron] User ${userId} failed:`, err);
      failCount++;
      // Continue with next user
    }
  }

  console.log(
    `[PodcastCron] Weekly podcast generation complete. ${successCount} succeeded, ${failCount} failed.`
  );
}

// Allow direct execution: npm run cron:podcasts
if (process.argv[1]?.includes('weekly-podcast-generation')) {
  runWeeklyPodcastGeneration()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error('[PodcastCron] Fatal error:', err);
      process.exit(1);
    });
}
