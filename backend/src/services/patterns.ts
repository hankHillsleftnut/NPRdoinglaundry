import { jsonChatCompletion } from '../utils/openai.js';
import { supabaseAdmin, Tables } from '../utils/supabase.js';
import { config } from '../utils/config.js';
import type { PatternType, Category, DbPattern, DbInsightUnit } from '../types/index.js';

// Pattern detection result type
interface DetectedPattern {
  title: string;
  description: string;
  pattern_type: PatternType;
  categories: Category[];
  supporting_insight_ids: string[];
  confidence_score: number;
  frequency?: 'daily' | 'weekly' | 'monthly' | 'occasional' | 'one_time';
}

interface PatternDetectionResult {
  patterns: DetectedPattern[];
  analysisNotes?: string;
}

// Get insights for a user within a date range
async function getInsightsInRange(
  userId: string,
  daysBack: number
): Promise<DbInsightUnit[]> {
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - daysBack);

  const { data, error } = await supabaseAdmin
    .from(Tables.INSIGHT_UNITS)
    .select('*')
    .eq('user_id', userId)
    .gte('insight_date', startDate.toISOString())
    .order('insight_date', { ascending: true });

  if (error) {
    throw new Error(`Failed to fetch insights: ${error.message}`);
  }

  return (data || []) as DbInsightUnit[];
}

// Format insights for GPT analysis
function formatInsightsForAnalysis(insights: DbInsightUnit[]): string {
  return insights
    .map((i) => {
      const date = new Date(i.insight_date).toLocaleDateString();
      const sentiment = i.sentiment ? ` [${i.sentiment}]` : '';
      const intensity = i.intensity ? ` (intensity: ${i.intensity}/10)` : '';
      return `- [${date}] [${i.primary_category}]${sentiment}${intensity}: "${i.content}"`;
    })
    .join('\n');
}

// Detect patterns using GPT-4
async function detectPatternsWithGPT(
  insights: DbInsightUnit[],
  analysisType: 'daily' | 'weekly'
): Promise<PatternDetectionResult> {
  if (insights.length < config.patterns.minInsightsForCorrelation) {
    return { patterns: [], analysisNotes: 'Insufficient insights for pattern detection' };
  }

  const timeframe = analysisType === 'daily' ? '7 days' : '30 days';
  const focusAreas =
    analysisType === 'daily'
      ? 'short-term correlations, immediate cause-effect relationships, and anomalies'
      : 'longer-term trends, cycles, habits, and multi-week patterns';

  const systemPrompt = `You are an expert at detecting meaningful patterns in personal insight data.
Analyze the following insights from the past ${timeframe} and identify ${focusAreas}.

PATTERN TYPES:
- correlation: Two or more factors that tend to occur together (e.g., "Poor sleep often follows stressful work days")
- trend: A directional change over time (e.g., "Anxiety levels decreasing over 2 weeks")
- cycle: A repeating pattern (e.g., "Energy dips every Sunday evening")
- anomaly: An unusual deviation from normal patterns (e.g., "Unusually high stress this week")
- habit: A consistent recurring behavior (e.g., "Exercises 3x per week consistently")

RULES:
1. Only report patterns with sufficient evidence (at least 3 supporting insights)
2. Be specific about the pattern - avoid vague observations
3. Include all supporting insight IDs (the ones in brackets at start of each line)
4. Set confidence_score based on strength of evidence (0.0-1.0)
5. Focus on actionable or meaningful patterns, not trivial observations
6. For correlations, note the direction (positive or inverse correlation)
7. For trends, note if improving or declining
8. Consider cross-category correlations (e.g., sleep affecting work)

OUTPUT FORMAT: Return a JSON object:
{
  "patterns": [
    {
      "title": "Brief pattern title",
      "description": "Detailed explanation of the pattern and its implications",
      "pattern_type": "correlation|trend|cycle|anomaly|habit",
      "categories": ["primary category", "related categories"],
      "supporting_insight_ids": ["uuid1", "uuid2", ...],
      "confidence_score": 0.0-1.0,
      "frequency": "daily|weekly|monthly|occasional|one_time"
    }
  ],
  "analysisNotes": "Any observations about data quality or limitations"
}

Only include patterns with confidence_score >= ${config.patterns.minConfidenceThreshold}.`;

  // Include insight IDs in the formatted data
  const formattedInsights = insights
    .map((i) => {
      const date = new Date(i.insight_date).toLocaleDateString();
      const sentiment = i.sentiment ? ` [${i.sentiment}]` : '';
      const intensity = i.intensity ? ` (intensity: ${i.intensity}/10)` : '';
      return `[${i.id}] [${date}] [${i.primary_category}]${sentiment}${intensity}: "${i.content}"`;
    })
    .join('\n');

  const userMessage = `INSIGHTS FROM THE PAST ${timeframe.toUpperCase()}:

${formattedInsights}

Total insights: ${insights.length}
Categories present: ${[...new Set(insights.map((i) => i.primary_category))].join(', ')}`;

  try {
    const result = await jsonChatCompletion<PatternDetectionResult>(
      systemPrompt,
      userMessage,
      { temperature: 0.3, maxTokens: 4096 }
    );

    // Filter to only valid patterns
    const validPatterns = (result.patterns || []).filter(
      (p) =>
        p.title &&
        p.description &&
        p.pattern_type &&
        p.supporting_insight_ids?.length >= 3 &&
        p.confidence_score >= config.patterns.minConfidenceThreshold
    );

    return {
      patterns: validPatterns,
      analysisNotes: result.analysisNotes,
    };
  } catch (error) {
    console.error('Pattern detection error:', error);
    return { patterns: [], analysisNotes: 'Pattern detection failed' };
  }
}

// Store detected patterns
async function storePatterns(
  userId: string,
  patterns: DetectedPattern[],
  timeRangeStart: Date,
  timeRangeEnd: Date
): Promise<string[]> {
  if (patterns.length === 0) return [];

  const patternsToInsert = patterns.map((p) => ({
    user_id: userId,
    title: p.title,
    description: p.description,
    pattern_type: p.pattern_type,
    categories: p.categories,
    supporting_insight_ids: p.supporting_insight_ids,
    confidence_score: p.confidence_score,
    frequency: p.frequency || null,
    time_range_start: timeRangeStart.toISOString(),
    time_range_end: timeRangeEnd.toISOString(),
    is_active: true,
    user_acknowledged: false,
    metadata: {},
  }));

  const { data, error } = await supabaseAdmin
    .from(Tables.PATTERNS)
    .insert(patternsToInsert)
    .select('id');

  if (error) {
    console.error('Failed to store patterns:', error);
    return [];
  }

  const patternIds = (data || []).map((p) => p.id);

  // Create pattern_insights junction records
  for (let i = 0; i < patterns.length; i++) {
    const pattern = patterns[i];
    const patternId = patternIds[i];

    if (pattern && patternId && pattern.supporting_insight_ids) {
      const junctionRecords = pattern.supporting_insight_ids.map(
        (insightId) => ({
          pattern_id: patternId,
          insight_id: insightId,
          relevance_score: 0.8, // Default relevance
        })
      );

      await supabaseAdmin
        .from(Tables.PATTERN_INSIGHTS)
        .insert(junctionRecords)
        .select();
    }
  }

  return patternIds;
}

// Validate existing patterns against recent data
async function validateExistingPatterns(userId: string): Promise<void> {
  const { data: activePatterns } = await supabaseAdmin
    .from(Tables.PATTERNS)
    .select('*')
    .eq('user_id', userId)
    .eq('is_active', true);

  if (!activePatterns || activePatterns.length === 0) return;

  for (const pattern of activePatterns as DbPattern[]) {
    // Check if supporting insights still exist and are recent
    const { data: supportingInsights } = await supabaseAdmin
      .from(Tables.INSIGHT_UNITS)
      .select('id')
      .in('id', pattern.supporting_insight_ids);

    const existingCount = supportingInsights?.length || 0;
    const originalCount = pattern.supporting_insight_ids.length;

    // Deactivate pattern if too many supporting insights are gone
    if (existingCount < originalCount * 0.5) {
      await supabaseAdmin
        .from(Tables.PATTERNS)
        .update({ is_active: false })
        .eq('id', pattern.id);
    } else {
      // Update last validated timestamp
      await supabaseAdmin
        .from(Tables.PATTERNS)
        .update({ last_validated_at: new Date().toISOString() })
        .eq('id', pattern.id);
    }
  }
}

// Main daily pattern detection
export async function detectDailyPatterns(userId: string): Promise<{
  newPatterns: number;
  analysisNotes?: string;
}> {
  const insights = await getInsightsInRange(userId, 7);

  const result = await detectPatternsWithGPT(insights, 'daily');

  const endDate = new Date();
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - 7);

  const patternIds = await storePatterns(
    userId,
    result.patterns,
    startDate,
    endDate
  );

  return {
    newPatterns: patternIds.length,
    analysisNotes: result.analysisNotes,
  };
}

// Main weekly pattern detection
export async function detectWeeklyPatterns(userId: string): Promise<{
  newPatterns: number;
  validatedPatterns: boolean;
  analysisNotes?: string;
}> {
  // First validate existing patterns
  await validateExistingPatterns(userId);

  const insights = await getInsightsInRange(userId, 30);

  const result = await detectPatternsWithGPT(insights, 'weekly');

  const endDate = new Date();
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - 30);

  const patternIds = await storePatterns(
    userId,
    result.patterns,
    startDate,
    endDate
  );

  return {
    newPatterns: patternIds.length,
    validatedPatterns: true,
    analysisNotes: result.analysisNotes,
  };
}

// Get patterns for a user
export async function getUserPatterns(
  userId: string,
  options?: {
    activeOnly?: boolean;
    patternType?: PatternType;
    limit?: number;
  }
): Promise<DbPattern[]> {
  let query = supabaseAdmin
    .from(Tables.PATTERNS)
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false });

  if (options?.activeOnly !== false) {
    query = query.eq('is_active', true);
  }

  if (options?.patternType) {
    query = query.eq('pattern_type', options.patternType);
  }

  if (options?.limit) {
    query = query.limit(options.limit);
  }

  const { data, error } = await query;

  if (error) {
    throw new Error(`Failed to fetch patterns: ${error.message}`);
  }

  return (data || []) as DbPattern[];
}

// Update pattern feedback
export async function updatePatternFeedback(
  patternId: string,
  userId: string,
  feedback: 'confirmed' | 'rejected' | 'unsure',
  notes?: string
): Promise<void> {
  const { error } = await supabaseAdmin
    .from(Tables.PATTERNS)
    .update({
      user_feedback: feedback,
      feedback_notes: notes || null,
      user_acknowledged: true,
      // Deactivate if rejected
      is_active: feedback !== 'rejected',
    })
    .eq('id', patternId)
    .eq('user_id', userId);

  if (error) {
    throw new Error(`Failed to update pattern feedback: ${error.message}`);
  }
}

// Get pattern with supporting insights
export async function getPatternWithInsights(
  patternId: string,
  userId: string
): Promise<{
  pattern: DbPattern;
  supportingInsights: DbInsightUnit[];
} | null> {
  const { data: pattern, error: patternError } = await supabaseAdmin
    .from(Tables.PATTERNS)
    .select('*')
    .eq('id', patternId)
    .eq('user_id', userId)
    .single();

  if (patternError || !pattern) {
    return null;
  }

  const { data: insights } = await supabaseAdmin
    .from(Tables.INSIGHT_UNITS)
    .select('*')
    .in('id', pattern.supporting_insight_ids);

  return {
    pattern: pattern as DbPattern,
    supportingInsights: (insights || []) as DbInsightUnit[],
  };
}
