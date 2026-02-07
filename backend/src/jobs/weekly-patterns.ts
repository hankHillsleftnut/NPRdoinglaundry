import { supabaseAdmin, Tables } from '../utils/supabase.js';
import { detectWeeklyPatterns } from '../services/patterns.js';

// Run weekly pattern detection for all active users
export async function runWeeklyPatternDetection(): Promise<void> {
  console.log('Starting weekly pattern detection...');

  try {
    // Get all users who have insights in the last 30 days
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const { data: activeUsers, error: usersError } = await supabaseAdmin
      .from(Tables.INSIGHT_UNITS)
      .select('user_id')
      .gte('insight_date', thirtyDaysAgo.toISOString())
      .limit(1000);

    if (usersError) {
      throw new Error(`Failed to get active users: ${usersError.message}`);
    }

    // Get unique user IDs
    const uniqueUserIds = [...new Set((activeUsers || []).map((u) => u.user_id))];

    console.log(`Processing ${uniqueUserIds.length} active users for weekly analysis...`);

    let totalNewPatterns = 0;
    let processedUsers = 0;
    let failedUsers = 0;

    for (const userId of uniqueUserIds) {
      try {
        const result = await detectWeeklyPatterns(userId);
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

    console.log(`Weekly pattern detection complete:`);
    console.log(`  - Processed: ${processedUsers} users`);
    console.log(`  - Failed: ${failedUsers} users`);
    console.log(`  - New patterns: ${totalNewPatterns}`);
  } catch (error) {
    console.error('Weekly pattern detection failed:', error);
    throw error;
  }
}

// Allow running directly via CLI
if (process.argv[1]?.endsWith('weekly-patterns.ts') || process.argv[1]?.endsWith('weekly-patterns.js')) {
  runWeeklyPatternDetection()
    .then(() => {
      console.log('Weekly pattern detection job completed successfully');
      process.exit(0);
    })
    .catch((error) => {
      console.error('Weekly pattern detection job failed:', error);
      process.exit(1);
    });
}
