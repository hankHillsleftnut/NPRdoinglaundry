import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { config } from './config.js';

// Service role client for backend operations (bypasses RLS)
export const supabaseAdmin: SupabaseClient = createClient(
  config.supabase.url,
  config.supabase.serviceKey,
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  }
);

// Create a client for a specific user (respects RLS)
export function createUserClient(accessToken: string): SupabaseClient {
  return createClient(config.supabase.url, config.supabase.anonKey, {
    global: {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    },
  });
}

// Database table names
export const Tables = {
  USERS: 'users',
  DATA_SOURCES: 'data_sources',
  CATEGORIES: 'categories',
  RAW_CONTENT: 'raw_content',
  INSIGHT_UNITS: 'insight_units',
  INSIGHT_CONNECTIONS: 'insight_connections',
  PATTERNS: 'patterns',
  PATTERN_INSIGHTS: 'pattern_insights',
  PROCESSING_QUEUE: 'processing_queue',
  ANALYTICS_CACHE: 'analytics_cache',
  // Observations-to-Insights pipeline tables
  GOALS: 'goals',
  OBSERVATIONS: 'observations',
  INSIGHTS: 'insights',
  PIPELINE_RUNS: 'pipeline_runs',
  PODCAST_EPISODES: 'podcast_episodes',
} as const;

// Helper to handle Supabase errors
export function handleSupabaseError(error: unknown): never {
  if (error && typeof error === 'object' && 'message' in error) {
    throw new Error(`Database error: ${(error as { message: string }).message}`);
  }
  throw new Error('Unknown database error');
}
