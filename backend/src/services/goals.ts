import { generateEmbedding, jsonChatCompletion } from '../utils/openai.js';
import { supabaseAdmin, Tables } from '../utils/supabase.js';
import { runAgentIngest } from './agent-client.js';
import type { DbGoal, GoalExtractionResult } from '../types/index.js';

/*
 * =========================================================================
 * TODO / FUTURE WORK: Automatic goal extraction from content
 * =========================================================================
 * Right now, goals are extracted in two ways:
 *   1. Manually — user types or speaks goals during onboarding or settings
 *   2. Via the /goals/extract endpoint — freeform text is analyzed by GPT-4
 *
 * FUTURE: We want the pipeline to automatically detect new goals from
 * incoming content (journal entries, voice notes, podcast transcripts).
 * The open question is: "When should we extract goals from content?"
 *
 * Possible approaches to explore later:
 *   - Run goal extraction on every new content upload and present
 *     suggestions to the user for approval
 *   - Periodically (weekly?) analyze recent content for goal-like
 *     statements and surface them
 *   - Use a confidence threshold — only suggest goals when GPT-4 is
 *     highly confident the user is expressing an intention, not just venting
 *   - Let the podcast itself ask the user about detected goals
 *
 * This decision is deferred. When we get to it, the extractGoalsFromText()
 * function below already does the hard part — we just need the trigger
 * logic and the user-facing confirmation flow.
 * =========================================================================
 */

/**
 * Create a new goal and generate its embedding.
 * The embedding is computed from "title: description" so that
 * raw-content chunks can be similarity-matched against it.
 */
export async function createGoal(
  userId: string,
  title: string,
  description?: string
): Promise<DbGoal> {
  // Generate embedding for the goal text
  const embeddingText = description
    ? `${title}: ${description}`
    : title;
  const embedding = await generateEmbedding(embeddingText);

  const { data, error } = await supabaseAdmin
    .from(Tables.GOALS)
    .insert({
      user_id: userId,
      title,
      description: description || null,
      embedding,
    })
    .select('*')
    .single();

  if (error || !data) {
    throw new Error(`Failed to create goal: ${error?.message}`);
  }

  return data as DbGoal;
}

/**
 * Update an existing goal. Re-generates the embedding if
 * the title or description changed.
 */
export async function updateGoal(
  goalId: string,
  userId: string,
  updates: { title?: string; description?: string; isActive?: boolean }
): Promise<DbGoal> {
  // Build the update payload
  const payload: Record<string, unknown> = {};
  if (updates.title !== undefined) payload.title = updates.title;
  if (updates.description !== undefined) payload.description = updates.description;
  if (updates.isActive !== undefined) payload.is_active = updates.isActive;

  // Re-generate embedding if text changed
  if (updates.title !== undefined || updates.description !== undefined) {
    // Fetch existing goal to merge fields
    const { data: existing } = await supabaseAdmin
      .from(Tables.GOALS)
      .select('title, description')
      .eq('id', goalId)
      .eq('user_id', userId)
      .single();

    const newTitle = updates.title ?? existing?.title ?? '';
    const newDesc = updates.description ?? existing?.description ?? '';
    const embeddingText = newDesc ? `${newTitle}: ${newDesc}` : newTitle;
    payload.embedding = await generateEmbedding(embeddingText);
  }

  const { data, error } = await supabaseAdmin
    .from(Tables.GOALS)
    .update(payload)
    .eq('id', goalId)
    .eq('user_id', userId)
    .select('*')
    .single();

  if (error || !data) {
    throw new Error(`Failed to update goal: ${error?.message}`);
  }

  return data as DbGoal;
}

/**
 * Delete a goal (cascades to observations and insights).
 */
export async function deleteGoal(goalId: string, userId: string): Promise<void> {
  const { error } = await supabaseAdmin
    .from(Tables.GOALS)
    .delete()
    .eq('id', goalId)
    .eq('user_id', userId);

  if (error) {
    throw new Error(`Failed to delete goal: ${error.message}`);
  }
}

/**
 * List all goals for a user (optionally filter by active status).
 */
export async function listGoals(
  userId: string,
  activeOnly: boolean = false
): Promise<DbGoal[]> {
  let query = supabaseAdmin
    .from(Tables.GOALS)
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false });

  if (activeOnly) {
    query = query.eq('is_active', true);
  }

  const { data, error } = await query;

  if (error) {
    throw new Error(`Failed to list goals: ${error.message}`);
  }

  return (data || []) as DbGoal[];
}

/**
 * Get a single goal by ID.
 */
export async function getGoal(goalId: string, userId: string): Promise<DbGoal | null> {
  const { data, error } = await supabaseAdmin
    .from(Tables.GOALS)
    .select('*')
    .eq('id', goalId)
    .eq('user_id', userId)
    .single();

  if (error) return null;
  return data as DbGoal;
}

/**
 * Parse a vector value from Supabase.
 * PostgreSQL vector columns are returned as strings like "[-0.024,0.008,...]"
 * by the Supabase JS client. This converts them to number[].
 */
export function parseEmbedding(value: unknown): number[] | null {
  if (!value) return null;
  if (Array.isArray(value)) return value as number[];
  if (typeof value === 'string') {
    try {
      const parsed = JSON.parse(value);
      if (Array.isArray(parsed)) return parsed as number[];
    } catch {
      return null;
    }
  }
  return null;
}

/**
 * Get all active goals with their embeddings (for pipeline use).
 */
export async function getActiveGoalsWithEmbeddings(
  userId: string
): Promise<Array<{ id: string; title: string; description: string | null; embedding: number[] }>> {
  const { data, error } = await supabaseAdmin
    .from(Tables.GOALS)
    .select('id, title, description, embedding')
    .eq('user_id', userId)
    .eq('is_active', true)
    .not('embedding', 'is', null);

  if (error) {
    throw new Error(`Failed to get goals: ${error.message}`);
  }

  // Parse embedding strings into number arrays (Supabase returns vector as string)
  return (data || [])
    .map((g: any) => ({
      id: g.id,
      title: g.title,
      description: g.description,
      embedding: parseEmbedding(g.embedding),
    }))
    .filter((g): g is { id: string; title: string; description: string | null; embedding: number[] } =>
      g.embedding !== null && g.embedding.length > 0
    );
}

/**
 * Extract goals from freeform natural language.
 *
 * The user speaks or types casually — "I kinda want to make more money,
 * I miss what I used to make, I want to get into dating" — and GPT-4
 * extracts structured, nuanced goals from that.
 *
 * This is used during onboarding and manual goal creation. It does NOT
 * save the goals — it returns them for the caller (or user) to review
 * and confirm before saving.
 */
export async function extractGoalsFromText(
  text: string
): Promise<GoalExtractionResult> {
  const systemPrompt = `You are a CBT-trained therapist and life coach who extracts goals while identifying the underlying beliefs about self-worth that shape how people express their aspirations.

The user will share their thoughts, desires, frustrations, or aspirations in natural language. Your job is to:

1. **Extract the STATED goals** — what they explicitly want to achieve
2. **Identify the UNDERLYING SELF-ESTEEM CONTEXT** — how do they talk about themselves? What does their language reveal about their self-concept?
3. **Detect CORE BELIEFS** — what fundamental beliefs about themselves are driving these goals?

CORE BELIEF CATEGORIES TO IDENTIFY:
- "I'm not good enough" (inadequacy)
- "I'm unlovable" (worthlessness in relationships)
- "I'm a failure" (incompetence)
- "I don't matter" (insignificance)
- "I'm weak" (helplessness)
- "I'm bad" (defectiveness)

SELF-ESTEEM INDICATORS IN LANGUAGE:
- **Confident framing**: "I want to build X" vs **Low self-esteem framing**: "I want to stop being so bad at X"
- **Growth mindset**: "I'm learning to..." vs **Fixed mindset**: "I'll never be able to..."
- **Self-compassion**: "I'm working on..." vs **Self-criticism**: "I need to fix how useless I am at..."
- **Evidence of capability**: "I did X before, now I want Y" vs **Discounting past wins**: "I got lucky with X, but I'm really bad at..."

FOR EACH GOAL YOU EXTRACT:

1. **TITLE** (5-15 words): Clear, specific, framed in GROWTH language (what they're building, not just what they're escaping)

2. **DESCRIPTION** (2-4 sentences):
   - The nuanced goal with emotional context
   - How it connects to their self-esteem (are they trying to prove worth? escape shame? build genuine capability?)
   - Any cognitive distortions visible in how they frame it

3. **REASONING**: Why you believe this goal reveals what it does about their self-concept, including the underlying belief driving it and whether the goal is framed in low, moderate, or healthy self-esteem language. If the goal is framed negatively, include a growth-oriented reframe.

RULES:
- Look for IMPLICIT goals, not just explicit. "I want to date again" might imply "rebuild confidence in my desirability" or "prove I'm lovable after the breakup"
- When goals are framed negatively ("stop being so X"), note the self-criticism and offer a growth-oriented reframe in the reasoning
- If someone lists accomplishments before stating a goal, note if they're building on strengths (healthy) or dismissing them as flukes (low self-esteem)
- Prefer fewer, deeper goals over many shallow ones
- If text contains NO goal-like statements, return empty goals array

OUTPUT FORMAT: Return a JSON object:
{
  "goals": [
    {
      "title": "Clear, growth-oriented goal title",
      "description": "Nuanced description with emotional and self-esteem context",
      "reasoning": "Why this reveals what it does about their self-concept, underlying belief, self-esteem level, and growth reframe if needed"
    }
  ],
  "processingNotes": "Overall self-esteem patterns in how they talk about their goals"
}`;

  const userMessage = `Extract goals from this, paying close attention to self-esteem patterns in the language:\n\n${text}`;

  try {
    const result = await jsonChatCompletion<GoalExtractionResult>(
      systemPrompt,
      userMessage,
      { temperature: 0.3, maxTokens: 2048 }
    );

    // Validate
    const valid = (result.goals || []).filter(
      (g) =>
        typeof g.title === 'string' &&
        g.title.length > 0 &&
        typeof g.description === 'string' &&
        g.description.length > 0 &&
        typeof g.reasoning === 'string'
    );

    return { goals: valid, processingNotes: result.processingNotes };
  } catch (error) {
    console.error('Goal extraction error:', error);
    throw new Error(
      `Failed to extract goals: ${error instanceof Error ? error.message : 'Unknown error'}`
    );
  }
}

/**
 * Extract goals from text AND save them all in one step.
 * Convenience function for onboarding flows where the user
 * has already confirmed they want to proceed.
 */
export async function extractAndSaveGoals(
  userId: string,
  text: string
): Promise<{ extracted: GoalExtractionResult; savedGoals: DbGoal[] }> {
  const extracted = await extractGoalsFromText(text);

  const savedGoals: DbGoal[] = [];
  for (const goal of extracted.goals) {
    const saved = await createGoal(userId, goal.title, goal.description);
    savedGoals.push(saved);
  }

  return { extracted, savedGoals };
}

/**
 * Synthesize onboarding goals from the FULL intelligence pipeline (not a one-shot
 * LLM call). Persists the onboarding answers as raw_content, runs the agent
 * ingestion + Cook 0 pipeline (identity_inferences -> goal_candidates ->
 * User Understanding Document active_goals), then surfaces those synthesized,
 * evidence-grounded goals and saves them to the goals table.
 *
 * Falls back to high-confidence goal_candidates if Cook 0 produced no active_goals.
 */
export async function synthesizeOnboardingGoals(
  userId: string,
  answersText: string
): Promise<{ extracted: GoalExtractionResult; savedGoals: DbGoal[] }> {
  // 1. Ensure an onboarding_profile raw_content row exists (the agent reads from DB).
  let profileId: string | null = null;
  const { data: existingProfile } = await supabaseAdmin
    .from(Tables.RAW_CONTENT)
    .select('id')
    .eq('user_id', userId)
    .eq('content_type', 'onboarding_profile')
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (existingProfile?.id) {
    profileId = existingProfile.id as string;
  } else {
    const { data: inserted, error: insErr } = await supabaseAdmin
      .from(Tables.RAW_CONTENT)
      .insert({
        user_id: userId,
        content_type: 'onboarding_profile',
        content: answersText,
        content_date: new Date().toISOString(),
        metadata: {},
        processing_status: 'pending',
      })
      .select('id')
      .single();
    if (insErr || !inserted) {
      throw new Error(`Failed to store onboarding profile: ${insErr?.message}`);
    }
    profileId = inserted.id as string;
  }

  // 2. Run the full pipeline (ingestion agent + Cook 0) synchronously on the profile.
  await runAgentIngest({
    userId,
    rawContentIds: [profileId],
    notes: 'onboarding goal synthesis',
  });
  await supabaseAdmin
    .from(Tables.RAW_CONTENT)
    .update({ processing_status: 'completed', processed_at: new Date().toISOString() })
    .eq('id', profileId);

  // 3. Read the synthesized active_goals from the latest User Understanding Document.
  const { data: understanding } = await supabaseAdmin
    .from(Tables.USER_UNDERSTANDING)
    .select('document, version')
    .eq('user_id', userId)
    .order('version', { ascending: false })
    .limit(1)
    .maybeSingle();

  type ActiveGoal = { goal_id: string | null; title: string; what_its_really_about: string };
  const activeGoals: ActiveGoal[] =
    (understanding?.document?.active_goals as ActiveGoal[] | undefined) ?? [];

  let extractedGoals: GoalExtractionResult['goals'] = activeGoals
    .filter((g) => g.title && g.title.trim().length > 0)
    .map((g) => ({
      title: g.title,
      description: g.what_its_really_about ?? '',
      reasoning: '', // active_goals carry the deeper read in description; no separate why for v1
    }));

  // 4. Fallback: if Cook 0 produced no active_goals, surface top goal_candidates.
  if (extractedGoals.length === 0) {
    const { data: candidates } = await supabaseAdmin
      .from(Tables.GOAL_CANDIDATES)
      .select('title, description, reasoning, confidence_score')
      .eq('user_id', userId)
      .eq('status', 'pending')
      .order('confidence_score', { ascending: false })
      .limit(5);
    extractedGoals = (candidates ?? [])
      .filter((c) => c.title && String(c.title).trim().length > 0)
      .map((c) => ({
        title: c.title as string,
        description: (c.description as string) ?? '',
        reasoning: (c.reasoning as string) ?? '',
      }));
  }

  // 5. Persist the synthesized goals to the goals table (first-class, embedded).
  const savedGoals: DbGoal[] = [];
  for (const goal of extractedGoals) {
    const saved = await createGoal(userId, goal.title, goal.description);
    savedGoals.push(saved);
  }

  return {
    extracted: {
      goals: extractedGoals,
      processingNotes: `Synthesized ${extractedGoals.length} goal(s) from the ingestion + Cook 0 pipeline (document v${understanding?.version ?? '?'}).`,
    },
    savedGoals,
  };
}
