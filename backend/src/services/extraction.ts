import { jsonChatCompletion } from '../utils/openai.js';
import { supabaseAdmin, Tables } from '../utils/supabase.js';
import type {
  ContentType,
  ExtractedInsight,
  ExtractionResult,
  Category,
} from '../types/index.js';

// Source-specific extraction prompts
const extractionPrompts: Record<ContentType, string> = {
  voice_recording: `You are an expert at extracting atomic insight units from voice transcripts.
The user is speaking stream-of-consciousness, so look for emotional undertones, implied states, and both explicit and inferred insights.

RULES:
1. Each insight = ONE atomic fact (not compound statements). Break down complex statements.
2. Flag inferences with is_inferred: true and provide inference_reasoning explaining why you inferred this.
3. Include temporal context when mentioned (today, yesterday, this morning, etc.)
4. Rate sentiment (positive/negative/neutral/mixed) and intensity (1-10 scale where 1=barely noticeable, 10=overwhelming)
5. Identify emotion tags when present (anxious, happy, frustrated, excited, grateful, overwhelmed, etc.)
6. Suggest primary_category and secondary_categories from: sleep, health, mental_health, work, relationships, productivity, finance, creativity, learning, fitness, nutrition, spirituality, hobbies, travel, home
7. confidence_score should reflect how certain you are about the insight (0.0-1.0)

OUTPUT FORMAT: Return a JSON object with this structure:
{
  "insights": [
    {
      "content": "string - the atomic insight",
      "primary_category": "string - main category",
      "secondary_categories": ["array of additional relevant categories"],
      "is_inferred": boolean,
      "confidence_score": number (0-1),
      "inference_reasoning": "string - only if is_inferred is true",
      "sentiment": "positive|negative|neutral|mixed",
      "emotion_tags": ["array of emotion strings"],
      "intensity": number (1-10),
      "temporal_context": "string - when this occurred if mentioned"
    }
  ],
  "processingNotes": "any observations about the content quality or extraction process"
}`,

  text_entry: `You are an expert at extracting atomic insight units from written journal entries.
Look for structured thoughts, reflections, and explicit statements about the user's life, feelings, and experiences.

RULES:
1. Each insight = ONE atomic fact (not compound statements)
2. Written entries tend to be more intentional - weight explicit statements higher
3. Flag inferences with is_inferred: true and reasoning
4. Include temporal context when mentioned
5. Rate sentiment (positive/negative/neutral/mixed) and intensity (1-10)
6. Identify emotion tags when present
7. Suggest primary_category and secondary_categories from: sleep, health, mental_health, work, relationships, productivity, finance, creativity, learning, fitness, nutrition, spirituality, hobbies, travel, home

OUTPUT FORMAT: Return a JSON object with insights array and processingNotes.`,

  google_docs: `You are an expert at extracting atomic insight units from Google Docs.
Focus on work content, project progress, decisions made, and any personal reflections embedded in the document.

RULES:
1. Each insight = ONE atomic fact
2. Prioritize actionable items, decisions, and status updates
3. Note project blockers and progress indicators
4. Flag inferences with reasoning
5. Suggest categories (likely work, productivity, learning, creativity)
6. Work documents may be less emotional - focus on factual insights

OUTPUT FORMAT: Return a JSON object with insights array and processingNotes.`,

  healthkit: `You are an expert at extracting atomic insight units from Apple HealthKit data.
Focus on meaningful deviations from baseline, trends, and health-relevant patterns.

RULES:
1. Each insight = ONE atomic observation
2. Compare values to typical/healthy ranges when obvious
3. Flag significant deviations (very high, very low, unusual)
4. Note correlations with time patterns (time of day, day of week)
5. Suggest categories (health, fitness, sleep, nutrition)
6. Be conservative with inferences from raw health data

OUTPUT FORMAT: Return a JSON object with insights array and processingNotes.`,

  calendar: `You are an expert at extracting atomic insight units from calendar data.
Focus on priorities, stress indicators, work-life balance, and scheduling patterns.

RULES:
1. Each insight = ONE atomic observation
2. Note meeting density (back-to-back meetings = potential stress)
3. Identify meeting types and their implications
4. Observe work-life balance indicators (early meetings, late events)
5. Flag potential overcommitment or scheduling conflicts
6. Suggest categories (work, relationships, hobbies, health, etc.)

OUTPUT FORMAT: Return a JSON object with insights array and processingNotes.`,

  video_entry: `You are an expert at extracting atomic insight units from video journal transcriptions.
The user recorded a video — treat this like a voice recording but note that the user chose a visual medium, which may indicate a desire to document something they can see or show.

RULES:
1. Each insight = ONE atomic fact (not compound statements)
2. Flag inferences with is_inferred: true and reasoning
3. Include temporal context when mentioned
4. Rate sentiment (positive/negative/neutral/mixed) and intensity (1-10)
5. Identify emotion tags when present
6. Suggest primary_category and secondary_categories from: sleep, health, mental_health, work, relationships, productivity, finance, creativity, learning, fitness, nutrition, spirituality, hobbies, travel, home
7. Video entries may reference visual context ("look at this", "here's what I mean") — note implied context

OUTPUT FORMAT: Return a JSON object with insights array and processingNotes.`,

  screen_time: `You are a behavioral psychologist and digital wellness expert extracting deep behavioral insights from screen time data.
Your goal is to uncover PATTERNS, EMOTIONAL TRIGGERS, and BEHAVIORAL LOOPS — not just report app usage numbers.

**CBT LENS — What to look for:**

1. **AVOIDANCE BEHAVIOR**: High social media or entertainment usage during work hours may indicate procrastination rooted in anxiety or perfectionism. ("They spent 3 hours on Instagram during a workday — this may be avoidance of a stressful task.")

2. **COMPULSIVE CHECKING**: High pickup counts (>50/day) with short session lengths suggest habitual, reflexive phone use — often linked to anxiety, FOMO, or dopamine-seeking.

3. **DIGITAL SELF-MEDICATION**: Increased entertainment/social media on specific days may correlate with stress, loneliness, or low mood. Note these as emotional regulation attempts.

4. **PRODUCTIVITY vs CONSUMPTION RATIO**: Calculate and comment on how much screen time is creative/productive vs passive consumption. A user who spends 80% of their time consuming content may be avoiding their own projects.

5. **SLEEP HYGIENE SIGNALS**: Late-night usage (if first pickup is very early) suggests poor sleep boundaries. Note these as health-relevant insights.

6. **VALUE ALIGNMENT**: If the user has stated goals (fitness, learning, creativity), compare their app usage against those goals. Spending 3 hours on TikTok while having a "read more" goal is a meaningful disconnect.

7. **SOCIAL CONNECTION QUALITY**: Distinguish between messaging apps (potential real connection) vs social media feeds (passive consumption). Note the balance.

8. **HABIT LOOPS**: Identify potential trigger → behavior → reward loops. ("80 pickups and 2h of social media suggests a habitual loop — possibly triggered by boredom or stress, rewarded by dopamine hits from scrolling.")

RULES:
1. Each insight = ONE atomic observation about the user's digital behavior
2. ALL insights from screen time are behavioral inferences — set is_inferred: true with detailed reasoning
3. Rate confidence_score conservatively (0.3-0.7) — screen time data is suggestive, not definitive
4. Intensity should reflect behavioral significance (habitual 4h social media = 7-8, occasional 30min = 2-3)
5. Always provide emotion_tags based on what the behavior SUGGESTS (anxious, bored, avoidant, focused, curious, restless, etc.)
6. Suggest primary_category and secondary_categories from: productivity, mental_health, health, relationships, learning, hobbies, creativity, sleep, work, finance
7. Include at least one insight about overall digital wellbeing posture
8. If total screen time exceeds 5 hours, flag this as significant
9. If social media exceeds 2 hours, flag this as a pattern worth exploring
10. If pickup count exceeds 60, flag this as compulsive checking behavior

OUTPUT FORMAT: Return a JSON object with insights array and processingNotes.`,

  twitter_bookmarks: `You are an expert at extracting atomic insight units from Twitter/X bookmarks.
Focus on interests, aspirations, values, and topics the user cares about based on what they save.

RULES:
1. Each insight = ONE atomic observation about user interests/values
2. Identify recurring themes across bookmarks
3. Consider emotional resonance (why might they have saved this?)
4. These are all inferences - set is_inferred: true with reasoning
5. Suggest categories based on content themes
6. Look for aspirational content vs informational vs entertainment

OUTPUT FORMAT: Return a JSON object with insights array and processingNotes.`,
};

// Validate extracted insights have required fields
function validateInsight(insight: unknown): insight is ExtractedInsight {
  if (!insight || typeof insight !== 'object') return false;

  const i = insight as Record<string, unknown>;

  return (
    typeof i.content === 'string' &&
    i.content.length > 0 &&
    typeof i.primary_category === 'string' &&
    typeof i.is_inferred === 'boolean' &&
    typeof i.confidence_score === 'number' &&
    i.confidence_score >= 0 &&
    i.confidence_score <= 1
  );
}

// Get extraction prompt for content type, with fallback to data_sources table
async function getExtractionPrompt(contentType: ContentType): Promise<string> {
  // First try hardcoded prompts
  if (contentType in extractionPrompts) {
    return extractionPrompts[contentType];
  }

  // Fall back to database
  const { data } = await supabaseAdmin
    .from(Tables.DATA_SOURCES)
    .select('extraction_prompt')
    .eq('name', contentType)
    .single();

  if (data?.extraction_prompt) {
    return data.extraction_prompt;
  }

  // Generic fallback
  return `Extract atomic insight units from this content. Each insight should be ONE atomic fact with category, sentiment, and confidence score. Return JSON with insights array.`;
}

// Main extraction function
export async function extractInsights(
  content: string,
  contentType: ContentType,
  contentDate?: Date
): Promise<ExtractionResult> {
  const systemPrompt = await getExtractionPrompt(contentType);

  const userMessage = contentDate
    ? `Content date: ${contentDate.toISOString()}\n\nContent:\n${content}`
    : `Content:\n${content}`;

  try {
    const result = await jsonChatCompletion<ExtractionResult>(
      systemPrompt,
      userMessage,
      { temperature: 0.3, maxTokens: 4096 }
    );

    // Validate and filter insights
    const validInsights = (result.insights || []).filter(validateInsight);

    // Ensure categories are valid
    const validCategories: Category[] = [
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
    ];

    const normalizedInsights = validInsights.map((insight) => ({
      ...insight,
      primary_category: validCategories.includes(
        insight.primary_category as Category
      )
        ? insight.primary_category
        : 'health', // Default category
      secondary_categories: (insight.secondary_categories || []).filter((c) =>
        validCategories.includes(c as Category)
      ),
    }));

    return {
      insights: normalizedInsights,
      processingNotes: result.processingNotes,
    };
  } catch (error) {
    console.error('Extraction error:', error);
    throw new Error(
      `Failed to extract insights: ${error instanceof Error ? error.message : 'Unknown error'}`
    );
  }
}

// Process raw content and store insights
export async function processRawContent(
  rawContentId: string,
  userId: string
): Promise<{ insightIds: string[]; error?: string }> {
  try {
    // Get raw content
    const { data: rawContent, error: fetchError } = await supabaseAdmin
      .from(Tables.RAW_CONTENT)
      .select('*')
      .eq('id', rawContentId)
      .single();

    if (fetchError || !rawContent) {
      throw new Error('Raw content not found');
    }

    // Update status to processing
    await supabaseAdmin
      .from(Tables.RAW_CONTENT)
      .update({ processing_status: 'processing' })
      .eq('id', rawContentId);

    // Extract insights
    const contentDate = rawContent.content_date
      ? new Date(rawContent.content_date)
      : undefined;

    const result = await extractInsights(
      rawContent.content,
      rawContent.content_type as ContentType,
      contentDate
    );

    if (result.insights.length === 0) {
      // No insights extracted
      await supabaseAdmin
        .from(Tables.RAW_CONTENT)
        .update({
          processing_status: 'completed',
          processed_at: new Date().toISOString(),
        })
        .eq('id', rawContentId);

      return { insightIds: [] };
    }

    // Prepare insights for insertion
    const insightsToInsert = result.insights.map((insight) => ({
      user_id: userId,
      raw_content_id: rawContentId,
      content: insight.content,
      primary_category: insight.primary_category,
      secondary_categories: insight.secondary_categories || [],
      is_inferred: insight.is_inferred,
      confidence_score: insight.confidence_score,
      inference_reasoning: insight.inference_reasoning || null,
      insight_date:
        insight.temporal_context ||
        contentDate?.toISOString() ||
        new Date().toISOString(),
      sentiment: insight.sentiment || null,
      emotion_tags: insight.emotion_tags || [],
      intensity: insight.intensity || null,
      metadata: {},
    }));

    // Insert insights
    const { data: insertedInsights, error: insertError } = await supabaseAdmin
      .from(Tables.INSIGHT_UNITS)
      .insert(insightsToInsert)
      .select('id');

    if (insertError) {
      throw new Error(`Failed to insert insights: ${insertError.message}`);
    }

    const insightIds = insertedInsights?.map((i) => i.id) || [];

    // Update raw content status
    await supabaseAdmin
      .from(Tables.RAW_CONTENT)
      .update({
        processing_status: 'completed',
        processed_at: new Date().toISOString(),
      })
      .eq('id', rawContentId);

    return { insightIds };
  } catch (error) {
    // Update status to failed
    await supabaseAdmin
      .from(Tables.RAW_CONTENT)
      .update({
        processing_status: 'failed',
        processing_error:
          error instanceof Error ? error.message : 'Unknown error',
      })
      .eq('id', rawContentId);

    return {
      insightIds: [],
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}
