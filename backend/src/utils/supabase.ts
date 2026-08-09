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
  // Agent-owned tables (read here to surface synthesized goals)
  USER_UNDERSTANDING: 'user_understanding',
  GOAL_CANDIDATES: 'goal_candidates',
  // Durable integrations and exact source provenance
  INTEGRATION_CONNECTIONS: 'integration_connections',
  INTEGRATION_SYNC_STATES: 'integration_sync_states',
  INTEGRATION_JOBS: 'integration_jobs',
  INTEGRATION_IMPORTS: 'integration_imports',
  SOURCE_ASSETS: 'source_assets',
  INTEGRATION_AUDIT_EVENTS: 'integration_audit_events',
  INTEGRATION_OAUTH_STATES: 'integration_oauth_states',
  INTEGRATION_SYNC_RUNS: 'integration_sync_runs',
  SOURCE_PAYLOADS: 'source_payloads',
  SOURCE_ITEMS: 'source_items',
  SOURCE_ITEM_RELATIONS: 'source_item_relations',
  ANALYSIS_UNITS: 'analysis_units',
  EVIDENCE_LINKS: 'evidence_links',
  INTEGRATION_TEST_RUNS: 'integration_test_runs',
  ASSERTIONS: 'assertions',
  ASSERTION_EVIDENCE: 'assertion_evidence',
  ASSERTION_RELATIONS: 'assertion_relations',
  ENTITIES: 'entities',
  ENTITY_RESOLUTION_CANDIDATES: 'entity_resolution_candidates',
  IDENTITY_INFERENCES: 'identity_inferences',
} as const;

// Helper to handle Supabase errors
export function handleSupabaseError(error: unknown): never {
  if (error && typeof error === 'object' && 'message' in error) {
    throw new Error(`Database error: ${(error as { message: string }).message}`);
  }
  throw new Error('Unknown database error');
}
