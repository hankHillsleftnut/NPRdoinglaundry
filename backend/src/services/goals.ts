import { generateEmbedding, jsonChatCompletion } from '../utils/openai.js';
import { supabaseAdmin, Tables } from '../utils/supabase.js';
import { runAgentIngest, getAgentOnboardingGoals } from './agent-client.js';
import { handOffToAgent } from './agent-handoff.js';
import type { DbGoal, GoalExtractionResult } from '../types/index.js';
import { findSameGoal, type ExistingGoal } from './goal-dedupe.js';
import { blocksRevival, lifecycleFor } from './goal-lifecycle.js';

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

  // The person may already have this goal (goal-dedupe.ts): reuse or revive it.
  const { data: existing } = await supabaseAdmin
    .from(Tables.GOALS)
    .select('*')
    .eq('user_id', userId);
  const same = findSameGoal((existing ?? []) as ExistingGoal[], embedding);
  if (same) {
    const goal = same.goal as unknown as DbGoal & { status?: string };
    if ((goal.status ?? 'active') === 'active' && goal.is_active !== false) return goal;
    const { data: revived, error: reviveError } = await supabaseAdmin
      .from(Tables.GOALS)
      .update({ status: 'active', is_active: true, merged_into: null, status_reason: 'stated again', status_at: new Date().toISOString() })
      .eq('id', goal.id)
      .select('*')
      .single();
    if (!reviveError && revived) return revived as DbGoal;
    // Revival failed (e.g. lifecycle columns not there yet): fall through to a new goal.
  }

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
  updates: { title?: string; description?: string; isActive?: boolean; revive?: boolean }
): Promise<DbGoal> {
  // A merged or expired goal is revived only on purpose, never by an app sync (audit G1).
  if (updates.isActive === true && !updates.revive) {
    const { data: current } = await supabaseAdmin.from(Tables.GOALS).select('status').eq('id', goalId).eq('user_id', userId).maybeSingle();
    if (blocksRevival((current as { status?: string } | null)?.status, true, false)) {
      updates = { ...updates, isActive: undefined };
    }
  }
  // Build the update payload
  const payload: Record<string, unknown> = {};
  if (updates.title !== undefined) payload.title = updates.title;
  if (updates.description !== undefined) payload.description = updates.description;
  if (updates.isActive !== undefined) Object.assign(payload, lifecycleFor(updates.isActive));

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

  // Nothing left to change (a blocked revival): return the goal as it is.
  if (Object.keys(payload).length === 0) {
    const { data: unchanged, error: readError } = await supabaseAdmin.from(Tables.GOALS).select('*').eq('id', goalId).eq('user_id', userId).single();
    if (readError || !unchanged) throw new Error(`Failed to update goal: ${readError?.message}`);
    return unchanged as DbGoal;
  }

  let { data, error } = await supabaseAdmin
    .from(Tables.GOALS)
    .update(payload)
    .eq('id', goalId)
    .eq('user_id', userId)
    .select('*')
    .single();

  // A database without the lifecycle columns (agent migration 139): keep the
  // old behaviour rather than fail the person's edit.
  if (error?.code === '42703' && 'status' in payload) {
    for (const k of ['status', 'status_reason', 'status_at', 'merged_into']) delete payload[k];
    ({ data, error } = await supabaseAdmin.from(Tables.GOALS).update(payload).eq('id', goalId).eq('user_id', userId).select('*').single());
  }

  if (error || !data) {
    throw new Error(`Failed to update goal: ${error?.message}`);
  }

  return data as DbGoal;
}


/**
 * Decline a goal the user pruned (unchecked on the onboarding checklist).
 * The goal stops being an observational lens, but the desire is kept as a pending
 * goal_candidate so the ingestion pipeline can re-surface it if behavior says it
 * still matters. Ingestion loads pending candidates on every run.
 */
export async function declineGoal(goalId: string, userId: string): Promise<DbGoal> {
  const goal = await getGoal(goalId, userId);
  if (!goal) {
    throw new Error('Goal not found');
  }

  const { data: updated, error } = await supabaseAdmin
    .from(Tables.GOALS)
    .update({ is_active: false })
    .eq('id', goalId)
    .eq('user_id', userId)
    .select('*')
    .single();

  if (error || !updated) {
    throw new Error(`Failed to decline goal: ${error?.message}`);
  }

  // Case/whitespace-insensitive match, consistent with the title normalization
  // used elsewhere for this same "is this the same goal" question — an exact
  // .eq() would miss "Get fit" vs "get fit" and insert a duplicate candidate.
  const { data: pendingCandidates } = await supabaseAdmin
    .from(Tables.GOAL_CANDIDATES)
    .select('id, title')
    .eq('user_id', userId)
    .eq('status', 'pending');

  const declinedTitleKey = goal.title.trim().toLowerCase();
  const openCandidate = (pendingCandidates ?? []).find(
    (candidate) => candidate.title.trim().toLowerCase() === declinedTitleKey
  );

  if (!openCandidate) {
    const { error: candidateError } = await supabaseAdmin
      .from(Tables.GOAL_CANDIDATES)
      .insert({
        user_id: userId,
        title: goal.title,
        description: goal.description,
        reasoning:
          'Surfaced during onboarding synthesis and not selected by the user. Kept as a candidate so later behavior can corroborate it or let it go.',
        confidence_score: 0.5,
        status: 'pending',
      });
    if (candidateError) {
      throw new Error(`Failed to record declined goal candidate: ${candidateError.message}`);
    }
  }

  return updated as DbGoal;
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

/** How long an identical submission still counts as the same synthesis attempt. */
const PROFILE_RETRY_WINDOW_MS = 6 * 60 * 60 * 1000;

/**
 * Synthesize onboarding goals from the FULL intelligence pipeline (not a one-shot
 * LLM call). Persists the onboarding answers as raw_content, runs the agent
 * ingestion + Cook 0 pipeline (identity_inferences -> goal_candidates ->
 * User Understanding Document active_goals), then surfaces those synthesized,
 * evidence-grounded goals and saves them to the goals table.
 *
 * Falls back to high-confidence goal_candidates if Cook 0 produced no active_goals.
 */
/**
 * Onboarding goals, from the answers themselves.
 *
 * The goals come from one call to the agent over the answers (seconds), each
 * resting on the person's own words. The answers are still stored and read in
 * full by the pipeline, in the background: the screen no longer waits minutes
 * for that, and no longer depends on Cook 0, which facts-only reading does not
 * run on new material.
 *
 * ONBOARDING_GOALS_MODE=pipeline restores the previous behaviour.
 */
export async function synthesizeOnboardingGoals(
  userId: string,
  answersText: string
): Promise<{ extracted: GoalExtractionResult; savedGoals: DbGoal[] }> {
  if (process.env.ONBOARDING_GOALS_MODE === 'pipeline') {
    return synthesizeOnboardingGoalsViaPipeline(userId, answersText);
  }

  const profileId = await storeOnboardingAnswers(userId, answersText);
  // Not awaited: the agent reads the answers in full and records the outcome itself.
  void handOffToAgent(runAgentIngest, { userId, rawContentIds: [profileId] });

  const { goals } = await getAgentOnboardingGoals(userId, answersText);
  const extractedGoals: GoalExtractionResult['goals'] = goals.map((g) => ({
    title: g.title,
    description: g.description,
    reasoning: g.reasoning,
  }));

  return {
    extracted: {
      goals: extractedGoals,
      processingNotes: `${extractedGoals.length} goal(s) you stated in onboarding, each resting on your own words.`,
    },
    savedGoals: await saveGoalsNotYetSaved(userId, extractedGoals),
  };
}

/**
 * Store this onboarding's answers. Redoing onboarding used to reuse the FIRST
 * profile ever stored, so new answers were never read. A retry with identical
 * answers reuses the row instead of duplicating it.
 */
async function storeOnboardingAnswers(userId: string, answersText: string): Promise<string> {
  const { data: latest } = await supabaseAdmin
    .from(Tables.RAW_CONTENT)
    .select('id, content')
    .eq('user_id', userId)
    .eq('content_type', 'onboarding_profile')
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (latest?.id && latest.content === answersText) return latest.id as string;

  const { data: inserted, error } = await supabaseAdmin
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
  if (error || !inserted) throw new Error(`Failed to store onboarding answers: ${error?.message}`);
  return inserted.id as string;
}

/** Save goals whose title isn't already saved, so a retry never duplicates. Never deletes. */
async function saveGoalsNotYetSaved(userId: string, goals: GoalExtractionResult['goals']): Promise<DbGoal[]> {
  const { data: existing } = await supabaseAdmin.from(Tables.GOALS).select('title').eq('user_id', userId);
  const titles = new Set((existing ?? []).map((g: any) => String(g.title).trim().toLowerCase()));
  const saved: DbGoal[] = [];
  for (const goal of goals) {
    const key = goal.title.trim().toLowerCase();
    if (titles.has(key)) continue;
    saved.push(await createGoal(userId, goal.title, goal.description));
    titles.add(key);
  }
  return saved;
}

/**
 * The previous path, kept so it can be switched back on
 * (ONBOARDING_GOALS_MODE=pipeline).
 *
 * Synthesize onboarding goals from the FULL intelligence pipeline (not a one-shot
 * LLM call). See git history for its original notes.
 */
export async function synthesizeOnboardingGoalsViaPipeline(
  userId: string,
  answersText: string
): Promise<{ extracted: GoalExtractionResult; savedGoals: DbGoal[] }> {
  // 1. Store THIS submission as its own onboarding_profile row (the agent reads from
  //    the DB). Reusing the newest existing row would analyze whatever the user said
  //    the last time they onboarded and silently discard what they just typed. The
  //    only row we reuse is a byte-identical recent one, which means the client hit
  //    its 480s timeout while this pipeline kept running and is now retrying the same
  //    answers; re-inserting there would double-analyze one submission.
  let profileId: string;
  const { data: recentProfile } = await supabaseAdmin
    .from(Tables.RAW_CONTENT)
    .select('id, content')
    .eq('user_id', userId)
    .eq('content_type', 'onboarding_profile')
    .gte('created_at', new Date(Date.now() - PROFILE_RETRY_WINDOW_MS).toISOString())
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (recentProfile?.id && recentProfile.content === answersText) {
    profileId = recentProfile.id as string;
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
  // No status write here: the agent records what really happened to the row
  // (completed, or pending with a retry scheduled). Stamping 'completed' over
  // that is the two-writers bug that stranded 2,024 rows (agent-handoff.ts).

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

  // The document's goal_id is the only identity the pipeline carries out: Cook 0 sees
  // active goals as `[id] "title"`, so it can name a row it already knows about.
  type SurfacedGoal = GoalExtractionResult['goals'][number] & { goalId: string | null };

  let surfaced: SurfacedGoal[] = activeGoals
    .filter((g) => g.title && g.title.trim().length > 0)
    .map((g) => ({
      title: g.title,
      description: g.what_its_really_about ?? '',
      reasoning: '', // active_goals carry the deeper read in description; no separate why for v1
      goalId: g.goal_id ?? null,
    }));

  // 4. Fallback: if Cook 0 produced no active_goals, surface top goal_candidates.
  if (surfaced.length === 0) {
    const { data: candidates } = await supabaseAdmin
      .from(Tables.GOAL_CANDIDATES)
      .select('title, description, reasoning, confidence_score')
      .eq('user_id', userId)
      .eq('status', 'pending')
      .order('confidence_score', { ascending: false })
      .limit(5);
    surfaced = (candidates ?? [])
      .filter((c) => c.title && String(c.title).trim().length > 0)
      .map((c) => ({
        title: c.title as string,
        description: (c.description as string) ?? '',
        reasoning: (c.reasoning as string) ?? '',
        goalId: null,
      }));
  }

  // 5. Resolve every surfaced goal to a goals row and return all of them, so the
  //    client holds a server id for each checklist item. Match on identity first, and
  //    on title only for a goal the document named without an id.
  //
  //    Reusing the existing row rather than skipping the goal is what keeps a client
  //    retry idempotent (the 480s client timeout vs this longer pipeline) without also
  //    hiding a goal from someone onboarding a second time. Whether a reused goal stays
  //    active is the checklist's call, not ours: the client reactivates what it keeps
  //    and declines what it prunes.
  const { data: existingGoals } = await supabaseAdmin
    .from(Tables.GOALS)
    .select('*')
    .eq('user_id', userId);

  const rows = (existingGoals ?? []) as DbGoal[];
  const rowsById = new Map(rows.map((row) => [row.id, row]));
  const rowsByTitle = new Map<string, DbGoal>();
  for (const row of rows) {
    const key = row.title.trim().toLowerCase();
    const claimed = rowsByTitle.get(key);
    if (!claimed || (!claimed.is_active && row.is_active)) {
      rowsByTitle.set(key, row);
    }
  }

  const savedGoals: DbGoal[] = [];
  for (const goal of surfaced) {
    const titleKey = goal.title.trim().toLowerCase();
    const existing = (goal.goalId ? rowsById.get(goal.goalId) : undefined) ?? rowsByTitle.get(titleKey);
    if (existing) {
      savedGoals.push(existing);
      continue;
    }
    const created = await createGoal(userId, goal.title, goal.description);
    savedGoals.push(created);
    rowsById.set(created.id, created);
    rowsByTitle.set(titleKey, created);
  }

  return {
    extracted: {
      goals: surfaced.map(({ title, description, reasoning }) => ({ title, description, reasoning })),
      processingNotes: `Synthesized ${surfaced.length} goal(s) from the ingestion + Cook 0 pipeline (document v${understanding?.version ?? '?'}).`,
    },
    savedGoals,
  };
}
