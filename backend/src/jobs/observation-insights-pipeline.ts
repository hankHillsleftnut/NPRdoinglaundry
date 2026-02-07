/**
 * Cron job: Observations → Insights Pipeline
 *
 * Runs for every user who has active goals and recent content.
 * 1. Extracts observations from any unprocessed raw content.
 * 2. Generates insights from recent observations.
 *
 * Scheduled: Daily at 5 AM UTC (after the existing pattern detection jobs).
 * Can also be run manually: npm run cron:pipeline
 */

import { supabaseAdmin, Tables } from '../utils/supabase.js';
import { processAllPendingContent } from '../services/observations.js';
import { generateInsightsForAllGoals } from '../services/insight-synthesis.js';

export async function runObservationInsightsPipeline(): Promise<void> {
  console.log('[Pipeline] Starting observations → insights pipeline...');

  // Find users who have at least one active goal
  const { data: usersWithGoals, error } = await supabaseAdmin
    .from(Tables.GOALS)
    .select('user_id')
    .eq('is_active', true);

  if (error) {
    console.error('[Pipeline] Failed to fetch users with goals:', error);
    return;
  }

  // Deduplicate user IDs
  const userIds = [...new Set((usersWithGoals || []).map((g) => g.user_id))];

  if (userIds.length === 0) {
    console.log('[Pipeline] No users with active goals. Skipping.');
    return;
  }

  console.log(`[Pipeline] Processing ${userIds.length} user(s)...`);

  for (const userId of userIds) {
    try {
      console.log(`[Pipeline] User ${userId}: extracting observations...`);
      const obsResult = await processAllPendingContent(userId);
      console.log(
        `[Pipeline] User ${userId}: ${obsResult.totalObservations} observations from ${obsResult.contentProcessed} content items.`
      );

      console.log(`[Pipeline] User ${userId}: generating insights (30-day window)...`);
      const insightResult = await generateInsightsForAllGoals(userId, 30);
      console.log(
        `[Pipeline] User ${userId}: ${insightResult.totalCreated} created, ${insightResult.totalUpdated} updated.`
      );
    } catch (err) {
      console.error(`[Pipeline] User ${userId} failed:`, err);
      // Continue with next user
    }
  }

  console.log('[Pipeline] Observations → insights pipeline complete.');
}

// Allow direct execution: npm run cron:pipeline
if (process.argv[1]?.includes('observation-insights-pipeline')) {
  runObservationInsightsPipeline()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error('[Pipeline] Fatal error:', err);
      process.exit(1);
    });
}
