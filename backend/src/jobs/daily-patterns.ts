import { supabaseAdmin, Tables } from '../utils/supabase.js';
import { detectDailyPatterns } from '../services/patterns.js';

// Run daily pattern detection for all active users
export async function runDailyPatternDetection(): Promise<void> {
  console.log('Starting daily pattern detection...');

  try {
    // Get all users who have insights in the last 7 days
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    const { data: activeUsers, error: usersError } = await supabaseAdmin
      .from(Tables.INSIGHT_UNITS)
      .select('user_id')
      .gte('insight_date', sevenDaysAgo.toISOString())
      .limit(1000);

    if (usersError) {
      throw new Error(`Failed to get active users: ${usersError.message}`);
    }

    // Get unique user IDs
    const uniqueUserIds = [...new Set((activeUsers || []).map((u) => u.user_id))];

    console.log(`Processing ${uniqueUserIds.length} active users...`);

    let totalNewPatterns = 0;
    let processedUsers = 0;
    let failedUsers = 0;

    for (const userId of uniqueUserIds) {
      try {
        const result = await detectDailyPatterns(userId);
        totalNewPatterns += result.newPatterns;
        processedUsers++;

        if (result.newPatterns > 0) {
          console.log(`User ${userId}: ${result.newPatterns} new patterns detected`);
        }
      } catch (error) {
        console.error(`Failed to process user ${userId}:`, error);
        failedUsers++;
      }
    }

    console.log(`Daily pattern detection complete:`);
    console.log(`  - Processed: ${processedUsers} users`);
    console.log(`  - Failed: ${failedUsers} users`);
    console.log(`  - New patterns: ${totalNewPatterns}`);
  } catch (error) {
    console.error('Daily pattern detection failed:', error);
    throw error;
  }
}

// Allow running directly via CLI
if (process.argv[1]?.endsWith('daily-patterns.ts') || process.argv[1]?.endsWith('daily-patterns.js')) {
  runDailyPatternDetection()
    .then(() => {
      console.log('Daily pattern detection job completed successfully');
      process.exit(0);
    })
    .catch((error) => {
      console.error('Daily pattern detection job failed:', error);
      process.exit(1);
    });
}
