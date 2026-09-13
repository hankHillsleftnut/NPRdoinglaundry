import { z } from 'zod';

// ============================================
// Category Types
// ============================================
export const CategorySchema = z.enum([
  'sleep',
  'health',
  'mental_health',
  'work',
  'relationships',
  'productivity',
  'finance',
  'creativity',
  'learning',
  'fitness',
  'nutrition',
  'spirituality',
  'hobbies',
  'travel',
  'home',
]);

export type Category = z.infer<typeof CategorySchema>;

// ============================================
// Content Types
// ============================================
export const ContentTypeSchema = z.enum([
  'voice_recording',
  'voice_journal',
  'text_entry',
  'journal_entry',
  'video_entry',
  'google_docs',
  'healthkit',
  'calendar',
  'screen_time',
  'twitter_bookmarks',
  'onboarding_profile',
  // Native iOS sources
  'apple_music',
  'photos',
  'contacts',
  // OAuth/API integrations
  'gmail',
  'spotify',
  'youtube',
  'reddit',
  'x',
  'tiktok',
]);

export type ContentType = z.infer<typeof ContentTypeSchema>;

// ============================================
// Sentiment Types
// ============================================
export const SentimentSchema = z.enum(['positive', 'negative', 'neutral', 'mixed']);
export type Sentiment = z.infer<typeof SentimentSchema>;

// ============================================
// Connection Types
// ============================================
export const ConnectionTypeSchema = z.enum([
  'same_topic',
  'causal',
  'temporal',
  'supports',
  'contradicts',
]);

export type ConnectionType = z.infer<typeof ConnectionTypeSchema>;

// ============================================
// Pattern Types
// ============================================
export const PatternTypeSchema = z.enum([
  'correlation',
  'trend',
  'cycle',
  'anomaly',
  'habit',
]);

export type PatternType = z.infer<typeof PatternTypeSchema>;

// ============================================
// Processing Status
// ============================================
export const ProcessingStatusSchema = z.enum([
  'pending',
  'processing',
  'completed',
  'failed',
]);

export type ProcessingStatus = z.infer<typeof ProcessingStatusSchema>;

// ============================================
// Request/Response Schemas
// ============================================

// Content Upload
export const UploadContentSchema = z.object({
  contentType: ContentTypeSchema,
  content: z.string().min(1),
  contentDate: z.string().datetime().optional(),
  metadata: z.record(z.unknown()).optional(),
});

export type UploadContentRequest = z.infer<typeof UploadContentSchema>;

export const IntegrationSourceItemSchema = z.object({
  providerObjectType: z.string().min(1).max(200),
  providerObjectId: z.string().min(1).max(1000),
  payload: z.record(z.unknown()),
  canonicalType: z.string().min(1).max(200),
  canonicalText: z.string().min(1),
  normalizedData: z.record(z.unknown()).default({}),
  occurredAt: z.string().datetime().optional(),
  analysisEligible: z.boolean().default(true),
  providerCreatedAt: z.string().datetime().optional(),
  providerUpdatedAt: z.string().datetime().optional(),
  parserVersion: z.string().min(1).max(100),
  normalizerVersion: z.string().min(1).max(100),
  contentType: ContentTypeSchema,
  metadata: z.record(z.unknown()).default({}),
});

export const IngestIntegrationItemsSchema = z.object({
  idempotencyKey: z.string().min(8).max(500).optional(),
  runType: z.enum(['initial_backfill', 'incremental_sync', 'webhook_recovery', 'replay', 'export_import']),
  cursorBefore: z.record(z.unknown()).default({}),
  cursorAfter: z.record(z.unknown()).default({}),
  items: z.array(IntegrationSourceItemSchema).min(1).max(100),
});

export type IntegrationSourceItem = z.infer<typeof IntegrationSourceItemSchema>;
export type IngestIntegrationItemsRequest = z.infer<typeof IngestIntegrationItemsSchema>;

// Insight Response
export const InsightUnitSchema = z.object({
  id: z.string().uuid(),
  content: z.string(),
  primaryCategory: CategorySchema,
  secondaryCategories: z.array(CategorySchema).optional(),
  isInferred: z.boolean(),
  confidenceScore: z.number().min(0).max(1),
  inferenceReasoning: z.string().optional(),
  insightDate: z.string().datetime(),
  sentiment: SentimentSchema.optional(),
  emotionTags: z.array(z.string()).optional(),
  intensity: z.number().min(1).max(10).optional(),
  createdAt: z.string().datetime(),
});

export type InsightUnit = z.infer<typeof InsightUnitSchema>;

// Insight Connection
export const InsightConnectionSchema = z.object({
  id: z.string().uuid(),
  sourceInsightId: z.string().uuid(),
  targetInsightId: z.string().uuid(),
  connectionType: ConnectionTypeSchema,
  strength: z.number().min(0).max(1),
  reasoning: z.string().optional(),
});

export type InsightConnection = z.infer<typeof InsightConnectionSchema>;

// Pattern
export const PatternSchema = z.object({
  id: z.string().uuid(),
  title: z.string(),
  description: z.string(),
  patternType: PatternTypeSchema,
  categories: z.array(CategorySchema),
  supportingInsightIds: z.array(z.string().uuid()),
  confidenceScore: z.number().min(0).max(1),
  frequency: z.enum(['daily', 'weekly', 'monthly', 'occasional', 'one_time']).optional(),
  isActive: z.boolean(),
  userAcknowledged: z.boolean(),
  userFeedback: z.enum(['confirmed', 'rejected', 'unsure']).optional(),
  createdAt: z.string().datetime(),
});

export type Pattern = z.infer<typeof PatternSchema>;

// Search Request
export const SearchInsightsSchema = z.object({
  query: z.string().min(1),
  category: CategorySchema.optional(),
  startDate: z.string().datetime().optional(),
  endDate: z.string().datetime().optional(),
  limit: z.number().min(1).max(100).default(20),
});

export type SearchInsightsRequest = z.infer<typeof SearchInsightsSchema>;

// List Insights Query Params
export const ListInsightsQuerySchema = z.object({
  category: CategorySchema.optional(),
  startDate: z.string().datetime().optional(),
  endDate: z.string().datetime().optional(),
  isInferred: z.enum(['true', 'false']).optional(),
  sentiment: SentimentSchema.optional(),
  limit: z.coerce.number().min(1).max(100).default(50),
  offset: z.coerce.number().min(0).default(0),
});

export type ListInsightsQuery = z.infer<typeof ListInsightsQuerySchema>;

// Pattern Feedback
export const PatternFeedbackSchema = z.object({
  feedback: z.enum(['confirmed', 'rejected', 'unsure']),
  notes: z.string().optional(),
});

export type PatternFeedbackRequest = z.infer<typeof PatternFeedbackSchema>;

// ============================================
// GPT Extraction Types
// ============================================
export interface ExtractedInsight {
  content: string;
  primary_category: Category;
  secondary_categories?: Category[];
  is_inferred: boolean;
  confidence_score: number;
  inference_reasoning?: string;
  sentiment?: Sentiment;
  emotion_tags?: string[];
  intensity?: number;
  temporal_context?: string;
}

export interface ExtractionResult {
  insights: ExtractedInsight[];
  processingNotes?: string;
}

// ============================================
// Database Row Types (snake_case)
// ============================================
export interface DbInsightUnit {
  id: string;
  user_id: string;
  raw_content_id: string | null;
  content: string;
  primary_category: string;
  secondary_categories: string[];
  is_inferred: boolean;
  confidence_score: number;
  inference_reasoning: string | null;
  insight_date: string;
  sentiment: string | null;
  emotion_tags: string[];
  intensity: number | null;
  embedding: number[] | null;
  metadata: Record<string, unknown>;
  created_at: string;
  updated_at: string;
}

export interface DbInsightConnection {
  id: string;
  source_insight_id: string;
  target_insight_id: string;
  connection_type: string;
  strength: number;
  reasoning: string | null;
  is_bidirectional: boolean;
  created_at: string;
}

export interface DbPattern {
  id: string;
  user_id: string;
  title: string;
  description: string;
  pattern_type: string;
  categories: string[];
  supporting_insight_ids: string[];
  confidence_score: number;
  frequency: string | null;
  time_range_start: string | null;
  time_range_end: string | null;
  is_active: boolean;
  user_acknowledged: boolean;
  user_feedback: string | null;
  feedback_notes: string | null;
  metadata: Record<string, unknown>;
  created_at: string;
  updated_at: string;
  last_validated_at: string | null;
}

export interface DbRawContent {
  id: string;
  user_id: string;
  content_type: string;
  content: string;
  content_date: string | null;
  metadata: Record<string, unknown>;
  processing_status: string;
  processing_error: string | null;
  source_id: string | null;
  created_at: string;
  processed_at: string | null;
}

// ============================================
// Goal Types
// ============================================
export const CreateGoalSchema = z.object({
  title: z.string().min(1).max(500),
  description: z.string().max(2000).optional(),
});

export type CreateGoalRequest = z.infer<typeof CreateGoalSchema>;

export const UpdateGoalSchema = z.object({
  title: z.string().min(1).max(500).optional(),
  description: z.string().max(2000).optional(),
  isActive: z.boolean().optional(),
});

export type UpdateGoalRequest = z.infer<typeof UpdateGoalSchema>;

// Goal extraction from natural language
export const ExtractGoalsSchema = z.object({
  text: z.string().min(1).max(10000),
});

export type ExtractGoalsRequest = z.infer<typeof ExtractGoalsSchema>;

// What GPT returns when extracting goals from freeform text
export interface ExtractedGoalFromText {
  title: string;
  description: string;
  reasoning: string;  // why GPT thinks this is a goal
}

export interface GoalExtractionResult {
  goals: ExtractedGoalFromText[];
  processingNotes?: string;
}

// ============================================
// Observation / Insight Pipeline Types
// ============================================

export interface DbGoal {
  id: string;
  user_id: string;
  title: string;
  description: string | null;
  is_active: boolean;
  embedding: number[] | null;
  created_at: string;
  updated_at: string;
}

export interface DbObservation {
  id: string;
  user_id: string;
  goal_id: string;
  raw_content_id: string | null;
  content: string;
  reason_why: string;
  confidence_score: number;
  observation_date: string;
  embedding: number[] | null;
  metadata: Record<string, unknown>;
  created_at: string;
}

export interface DbInsight {
  id: string;
  user_id: string;
  goal_id: string;
  title: string;
  content: string;
  evidence_summary: string;
  supporting_observation_ids: string[];
  confidence_score: number;
  time_range_start: string | null;
  time_range_end: string | null;
  embedding: number[] | null;
  metadata: Record<string, unknown>;
  created_at: string;
  updated_at: string;
}

export interface DbPipelineRun {
  id: string;
  user_id: string;
  run_type: 'observation_extraction' | 'insight_generation' | 'full_pipeline';
  status: 'running' | 'completed' | 'failed';
  raw_content_ids: string[];
  observations_created: number;
  insights_created: number;
  error_message: string | null;
  started_at: string;
  completed_at: string | null;
}

// GPT extraction types for observations
export interface ExtractedObservation {
  content: string;
  reason_why: string;
  confidence_score: number;
}

export interface ObservationExtractionResult {
  observations: ExtractedObservation[];
  processingNotes?: string;
}

// GPT synthesis types for insights (incremental — aware of existing insights)
export interface InsightAction {
  type: 'create_new' | 'update_existing';
  existing_insight_id?: string;  // only for update_existing
  title: string;
  content: string;
  evidence_summary: string;
  supporting_observation_ids: string[];
  confidence_score: number;
  reasoning: string;  // why this is new vs why this updates an existing insight
}

export interface IncrementalSynthesisResult {
  actions: InsightAction[];
  processingNotes?: string;
}

// ============================================
// Podcast Types
// ============================================

export interface DbPodcastEpisode {
  id: string;
  user_id: string;
  title: string;
  description: string | null;
  script: string;
  audio_url: string | null;
  duration_seconds: number | null;
  mood: string | null;
  generation_type: 'weekly' | 'on_demand' | 'milestone';
  status: 'generating' | 'ready' | 'failed';
  insight_ids: string[];
  goal_ids: string[];
  research_citations: ResearchCitation[];
  outline: PodcastOutline;
  episode_number: number | null;
  covers_period_start: string | null;
  covers_period_end: string | null;
  previous_episode_id: string | null;
  topics_covered: string[];
  error_message: string | null;
  metadata: Record<string, unknown>;
  created_at: string;
  updated_at: string;
}

export interface ResearchCitation {
  query: string;
  source: string;
  snippet: string;
  url?: string;
}

export interface PodcastOutline {
  theme: string;
  segments: PodcastSegment[];
  estimatedMinutes: number;
}

export interface PodcastSegment {
  title: string;
  type: 'intro' | 'goal_update' | 'insight_deep_dive' | 'research' | 'reflection' | 'outro';
  insightIds: string[];
  goalIds: string[];
  talkingPoints: string[];
  researchQueries: string[];
  estimatedSeconds: number;
}

// ============================================
// Auth Types
// ============================================
export interface AuthUser {
  id: string;
  appleUserId: string;
  email?: string;
  /** 'test' accounts are excluded from aggregates and batch spend. See services/accounts.ts. */
  accountType?: 'real' | 'test';
}

export interface JWTPayload {
  userId: string;
  appleUserId: string;
  iat: number;
  exp: number;
}

// ============================================
// API Response Types
// ============================================
export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}

export interface PaginatedResponse<T> extends ApiResponse<T[]> {
  pagination: {
    total: number;
    limit: number;
    offset: number;
    hasMore: boolean;
  };
}

// ============================================
// Analytics Types
// ============================================
export interface AnalyticsSummary {
  totalInsights: number;
  insightsByCategory: Record<Category, number>;
  sentimentDistribution: Record<Sentiment | 'unknown', number>;
  averageIntensity: number | null;
  inferredRatio: number;
  totalPatterns: number;
  activePatterns: number;
  periodStart: string;
  periodEnd: string;
}
