import { generateEmbedding, jsonChatCompletion } from '../utils/openai.js';
import { supabaseAdmin, Tables } from '../utils/supabase.js';
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

  return (data || []) as Array<{
    id: string;
    title: string;
    description: string | null;
    embedding: number[];
  }>;
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
  const systemPrompt = `You are an expert life coach and psychologist who listens deeply to what people say and extracts their true underlying goals.

The user will share their thoughts, desires, frustrations, or aspirations in natural, casual language. Your job is to identify the REAL goals behind what they're saying — not just the surface-level statements, but the nuanced, deeper intentions.

RULES:
1. Each goal should have a clear, specific TITLE (5-15 words) that captures the essence.
2. Each goal should have a detailed DESCRIPTION (1-3 sentences) that captures the NUANCE — the why behind the what, the emotional context, the underlying motivation.
3. Include a REASONING field explaining why you believe this is a goal the user holds.
4. Look for goals that are IMPLICIT, not just explicit. "I miss what I used to make" implies a goal about financial recovery. "I want to get into dating" might imply goals about confidence, social life, or finding a partner.
5. When multiple desires are connected (wanting money AND wanting to date), capture the CONNECTION in the description. Example: "Rebuild financial stability to support a more active social and dating life."
6. Do NOT invent goals the user didn't express. Only extract what's actually there, even if implicit.
7. Prefer fewer, more nuanced goals over many shallow ones.
8. If the text contains no goal-like statements, return an empty goals array.

OUTPUT FORMAT: Return a JSON object:
{
  "goals": [
    {
      "title": "short, specific goal title",
      "description": "nuanced description capturing the why, the emotion, the full context",
      "reasoning": "why you believe the user holds this goal based on what they said"
    }
  ],
  "processingNotes": "optional notes about the extraction"
}`;

  const userMessage = `Extract goals from this:\n\n${text}`;

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
