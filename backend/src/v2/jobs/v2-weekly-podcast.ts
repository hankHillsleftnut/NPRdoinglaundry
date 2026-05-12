/**
 * Cron entry point — v2 weekly podcast.
 *
 * Scheduled by Render Cron (see backend/render.yaml service name
 * `v2-weekly-podcast`, Sunday 06:00 UTC). Also runnable manually:
 *   npm run cron:v2-weekly-podcast
 *
 * For every user with activity in the last N days, run the v2 orchestrator.
 * Failures are logged and do not stop the sweep.
 */

import { supabaseAdmin, Tables } from '../../utils/supabase.js';
import { runV2Podcast } from '../podcast/run-podcast.js';

const ACTIVITY_WINDOW_DAYS = 7;

export async function runV2WeeklyPodcastGeneration(): Promise<void> {
  console.log('[v2:cron] weekly podcast sweep starting');

  const since = new Date();
  since.setDate(since.getDate() - ACTIVITY_WINDOW_DAYS);
  const sinceIso = since.toISOString();

  const [insightsRes, observationsRes] = await Promise.all([
    supabaseAdmin.from(Tables.INSIGHTS).select('user_id').gte('updated_at', sinceIso),
    supabaseAdmin.from(Tables.OBSERVATIONS).select('user_id').gte('observation_date', sinceIso),
  ]);

  if (insightsRes.error) {
    console.error('[v2:cron] failed to fetch recent insights:', insightsRes.error);
  }
  if (observationsRes.error) {
    console.error('[v2:cron] failed to fetch recent observations:', observationsRes.error);
  }

  const userIds = new Set<string>();
  for (const row of insightsRes.data ?? []) userIds.add(row.user_id as string);
  for (const row of observationsRes.data ?? []) userIds.add(row.user_id as string);

  if (userIds.size === 0) {
    console.log('[v2:cron] no active users in the last 7 days — nothing to generate');
    return;
  }

  console.log(`[v2:cron] generating v2 episodes for ${userIds.size} users`);

  let ok = 0;
  let fail = 0;

  for (const userId of userIds) {
    try {
      const result = await runV2Podcast({
        userId,
        daysWindow: 14,
        generationType: 'weekly',
      });
      ok += 1;
      console.log(
        `[v2:cron] user=${userId} ✓ episode=${result.episode.id} (stage2 steps=${result.stepsUsedStage2}, tool calls=${result.toolCallsStage2})`
      );
    } catch (err) {
      fail += 1;
      console.error(
        `[v2:cron] user=${userId} ✗ ${err instanceof Error ? err.message : String(err)}`
      );
    }
  }

  console.log(`[v2:cron] sweep complete — ok=${ok} fail=${fail}`);
}

// Run immediately when invoked as a script (e.g. by Render Cron or
// `npm run cron:v2-weekly-podcast`). Matches the pattern used by the legacy
// jobs (see backend/src/jobs/weekly-podcast-generation.ts).
if (process.argv[1]?.includes('v2-weekly-podcast')) {
  runV2WeeklyPodcastGeneration()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error('[v2:cron] fatal:', err);
      process.exit(1);
    });
}
