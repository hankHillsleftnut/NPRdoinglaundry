import { generateEmbedding, generateEmbeddings, jsonChatCompletion } from '../utils/openai.js';
import { supabaseAdmin, Tables } from '../utils/supabase.js';
import { getActiveGoalsWithEmbeddings, parseEmbedding } from './goals.js';
import type {
  DbObservation,
  DbInsight,
  InsightAction,
  IncrementalSynthesisResult,
} from '../types/index.js';

// ============================================
// Default lookback window: 30 days
// ============================================
const DEFAULT_DAYS_BACK = 30;

// ============================================
// Cosine similarity helper
// ============================================
function cosineSimilarity(a: number[], b: number[]): number {
  let dot = 0, normA = 0, normB = 0;
  for (let i = 0; i < a.length; i++) {
    dot += a[i]! * b[i]!;
    normA += a[i]! * a[i]!;
    normB += b[i]! * b[i]!;
  }
  return dot / (Math.sqrt(normA) * Math.sqrt(normB));
}

// ============================================
// Cluster observations by semantic similarity
// ============================================
interface ObservationCluster {
  observations: DbObservation[];
  centroidText: string;
}

function clusterObservations(
  observations: DbObservation[],
  similarityThreshold: number = 0.65,
  minClusterSize: number = 2
): ObservationCluster[] {
  // Parse embedding strings from Supabase into number arrays
  for (const obs of observations) {
    if (obs.embedding && !Array.isArray(obs.embedding)) {
      obs.embedding = parseEmbedding(obs.embedding);
    }
  }
  const withEmbeddings = observations.filter((o) => o.embedding && Array.isArray(o.embedding) && o.embedding.length > 0);

  if (withEmbeddings.length < minClusterSize) return [];

  const used = new Set<string>();
  const clusters: ObservationCluster[] = [];

  for (const obs of withEmbeddings) {
    if (used.has(obs.id)) continue;

    const cluster: DbObservation[] = [obs];
    used.add(obs.id);

    for (const candidate of withEmbeddings) {
      if (used.has(candidate.id)) continue;

      const sim = cosineSimilarity(obs.embedding!, candidate.embedding!);
      if (sim >= similarityThreshold) {
        cluster.push(candidate);
        used.add(candidate.id);
      }
    }

    if (cluster.length >= minClusterSize) {
      const centroidText = cluster
        .slice(0, 5)
        .map((o) => o.content)
        .join(' | ');
      clusters.push({ observations: cluster, centroidText });
    }
  }

  return clusters;
}

// ============================================
// Fetch existing insights for a goal
// ============================================
async function getExistingInsightsForGoal(
  userId: string,
  goalId: string
): Promise<DbInsight[]> {
  const { data, error } = await supabaseAdmin
    .from(Tables.INSIGHTS)
    .select('*')
    .eq('user_id', userId)
    .eq('goal_id', goalId)
    .order('created_at', { ascending: false });

  if (error) {
    console.error('Failed to fetch existing insights:', error);
    return [];
  }

  return (data || []) as DbInsight[];
}

// ============================================
// GPT-4 INCREMENTAL insight synthesis
// Aware of existing insights — updates or creates new
// ============================================
async function synthesizeInsightsIncrementally(
  clusters: ObservationCluster[],
  existingInsights: DbInsight[],
  goalTitle: string,
  goalDescription: string | null
): Promise<IncrementalSynthesisResult> {
  if (clusters.length === 0) {
    return { actions: [], processingNotes: 'No observation clusters to synthesize.' };
  }

  const goalText = goalDescription
    ? `"${goalTitle}" — ${goalDescription}`
    : `"${goalTitle}"`;

  // Format existing insights for context
  const existingInsightsText = existingInsights.length > 0
    ? existingInsights
        .map((ins) => `  - [${ins.id}] "${ins.title}": ${ins.content} (confidence: ${ins.confidence_score}, evidence: ${ins.evidence_summary})`)
        .join('\n')
    : '  (none yet)';

  const systemPrompt = `You are a CBT therapist synthesizing therapeutic insights from observations. You build a GROWING understanding of the user's cognitive patterns, evidence of capability, and progress challenging core beliefs.

THE USER'S GOAL: ${goalText}

EXISTING INSIGHTS (do NOT repeat these):
${existingInsightsText}

You will receive clusters of NEW observations. For each cluster, decide whether to UPDATE an existing insight or CREATE a new one.

**YOUR PRIMARY OBJECTIVES:**

1. **CHALLENGE COGNITIVE DISTORTIONS** — When negative self-talk appears, create insights that:
   - Name the distortion
   - Present counter-evidence
   - Reframe the thought in balanced, evidence-based language

2. **BUILD EVIDENCE LOGS** — Track patterns of capability the user might not see:
   - "User has now successfully handled conflict 4 times in 3 weeks — this is a capability, not luck"
   - "User completed projects despite anxiety in 6 of 7 instances — anxiety doesn't prevent action"

3. **IDENTIFY THOUGHT → FEELING → BEHAVIOR CHAINS** — Connect thoughts to emotions to actions:
   - "Thought: 'I'll embarrass myself' → Feeling: Anxiety → Behavior: Avoided team meeting"
   - This helps user see where intervention is possible

4. **TRACK PROGRESS ON CORE BELIEFS** — Is evidence accumulating that contradicts the user's negative self-concept?
   - Track evidence of competence, connection, resilience
   - Note when the user is dismissing or discounting positive evidence

**WHEN TO UPDATE vs CREATE:**

UPDATE an existing insight when:
- New observations add to an existing pattern (more evidence of a capability or distortion)
- The insight's conclusion remains the same but evidence strengthens
- You're tracking cumulative progress (e.g., "now 8 instances of X, up from 5")

CREATE a new insight when:
- A new cognitive distortion pattern emerges
- A new capability becomes visible
- A new thought → feeling → behavior chain is identified
- The user shows progress on a belief you haven't tracked before

**INSIGHT TYPES YOU SHOULD CREATE:**

1. **DISTORTION PATTERN**: "User demonstrates [distortion type] when [situation], leading to [consequence]"
2. **CAPABILITY EVIDENCE**: "User has demonstrated [capability] across [N instances], counter to belief that [core belief]"
3. **DISCOUNTING PATTERN**: "User systematically dismisses [type of evidence], maintaining negative self-concept"
4. **THOUGHT-BEHAVIOR LINK**: "When user thinks [thought], they feel [emotion] and respond by [behavior], which [consequence]"
5. **PROGRESS INDICATOR**: "User is showing [specific change] in [area], indicating growth"

**INSIGHT QUALITY STANDARDS:**
- Be SPECIFIC, not vague. "User struggles with confidence" is useless. "User dismisses every work accomplishment as 'not good enough,' maintaining belief in incompetence despite objective evidence of success" is actionable.
- When presenting counter-evidence, be FORCEFUL. Don't say "maybe user is capable." Say "User IS capable — here's the proof they're ignoring."
- Always connect insights back to the user's self-concept — how does this pattern maintain or challenge it?
- Include concrete examples from observations when possible

OUTPUT FORMAT: Return a JSON object:
{
  "actions": [
    {
      "type": "update_existing",
      "existing_insight_id": "uuid",
      "title": "Updated title (can evolve)",
      "content": "Updated therapeutic insight with new evidence (2-4 sentences, CBT-focused)",
      "evidence_summary": "MERGED evidence from old + new observations",
      "supporting_observation_ids": ["ALL observation ids"],
      "confidence_score": 0.0-1.0,
      "reasoning": "Why this updates existing insight"
    },
    {
      "type": "create_new",
      "title": "Short headline for new insight",
      "content": "New therapeutic insight (2-4 sentences, CBT-focused)",
      "evidence_summary": "Summary of supporting observations",
      "supporting_observation_ids": ["uuid1", "uuid2"],
      "confidence_score": 0.0-1.0,
      "reasoning": "Why this is genuinely new"
    }
  ],
  "processingNotes": "Overall patterns in cognitive distortions or capability evidence"
}

CRITICAL: Focus on insights that either (1) challenge negative beliefs with evidence, or (2) identify cognitive patterns that maintain low self-esteem. Avoid generic life coaching observations. If every cluster just reinforces existing insights with no new information, return ONLY update actions. If nothing is new or worth updating, return an empty actions array. Do NOT create redundant insights.`;

  // Format clusters for GPT
  const clustersText = clusters
    .map((cluster, i) => {
      const obsText = cluster.observations
        .map((o) => `  - [${o.id}] "${o.content}" (reason: ${o.reason_why}, date: ${o.observation_date})`)
        .join('\n');
      return `=== Cluster ${i + 1} (${cluster.observations.length} observations) ===\n${obsText}`;
    })
    .join('\n\n');

  const userMessage = `Synthesize CBT-informed insights from these observation clusters:\n\nGOAL: ${goalText}\n\n${clustersText}\n\nFocus on: capability evidence the user is missing, cognitive distortions maintaining low self-esteem, and thought→behavior chains.`;

  try {
    const result = await jsonChatCompletion<IncrementalSynthesisResult>(
      systemPrompt,
      userMessage,
      { temperature: 0.3, maxTokens: 4096 }
    );

    // Validate actions
    const validActions = (result.actions || []).filter((action) => {
      const baseValid =
        typeof action.title === 'string' &&
        action.title.length > 0 &&
        typeof action.content === 'string' &&
        action.content.length > 0 &&
        typeof action.evidence_summary === 'string' &&
        Array.isArray(action.supporting_observation_ids) &&
        typeof action.confidence_score === 'number' &&
        (action.type === 'create_new' || action.type === 'update_existing');

      if (!baseValid) return false;

      // For updates, must reference a valid existing insight
      if (action.type === 'update_existing') {
        if (!action.existing_insight_id) return false;
        const exists = existingInsights.some((ins) => ins.id === action.existing_insight_id);
        if (!exists) {
          console.warn(`GPT referenced non-existent insight ${action.existing_insight_id}, converting to create_new`);
          action.type = 'create_new';
          action.existing_insight_id = undefined;
        }
      }

      return true;
    });

    return { actions: validActions, processingNotes: result.processingNotes };
  } catch (error) {
    console.error('Incremental insight synthesis error:', error);
    return {
      actions: [],
      processingNotes: `Error: ${error instanceof Error ? error.message : 'Unknown'}`,
    };
  }
}

// ============================================
// Execute insight actions (updates + creates)
// ============================================
async function executeInsightActions(
  actions: InsightAction[],
  userId: string,
  goalId: string,
  timeRangeStart: string,
  timeRangeEnd: string
): Promise<{ createdIds: string[]; updatedIds: string[] }> {
  const createdIds: string[] = [];
  const updatedIds: string[] = [];

  for (const action of actions) {
    try {
      if (action.type === 'update_existing' && action.existing_insight_id) {
        // UPDATE an existing insight
        const { error } = await supabaseAdmin
          .from(Tables.INSIGHTS)
          .update({
            title: action.title,
            content: action.content,
            evidence_summary: action.evidence_summary,
            supporting_observation_ids: action.supporting_observation_ids,
            confidence_score: action.confidence_score,
            time_range_end: timeRangeEnd, // extend the time range
            metadata: { last_update_reasoning: action.reasoning },
          })
          .eq('id', action.existing_insight_id)
          .eq('user_id', userId);

        if (error) {
          console.error(`Failed to update insight ${action.existing_insight_id}:`, error);
        } else {
          updatedIds.push(action.existing_insight_id);
          // Regenerate embedding since content changed
          regenerateInsightEmbedding(action.existing_insight_id).catch((err) =>
            console.error('Failed to regenerate embedding:', err)
          );
        }
      } else {
        // CREATE a new insight
        const { data: inserted, error } = await supabaseAdmin
          .from(Tables.INSIGHTS)
          .insert({
            user_id: userId,
            goal_id: goalId,
            title: action.title,
            content: action.content,
            evidence_summary: action.evidence_summary,
            supporting_observation_ids: action.supporting_observation_ids,
            confidence_score: action.confidence_score,
            time_range_start: timeRangeStart,
            time_range_end: timeRangeEnd,
            metadata: { creation_reasoning: action.reasoning },
          })
          .select('id')
          .single();

        if (error) {
          console.error('Failed to insert new insight:', error);
        } else if (inserted) {
          createdIds.push(inserted.id);
        }
      }
    } catch (err) {
      console.error('Failed to execute insight action:', err);
    }
  }

  // Generate embeddings for new insights
  if (createdIds.length > 0) {
    generateInsightEmbeddings(createdIds).catch((err) =>
      console.error('Failed to generate insight embeddings:', err)
    );
  }

  return { createdIds, updatedIds };
}

// ============================================
// Main pipeline: generate insights for a user + goal
// ============================================

/**
 * Generate insights for a specific goal using INCREMENTAL synthesis.
 * - Fetches existing insights so GPT-4 knows what's already established
 * - Updates existing insights with new evidence when appropriate
 * - Only creates new insights for genuinely new patterns
 *
 * @param daysBack How many days of observations to consider (default 30)
 */
export async function generateInsightsForGoal(
  userId: string,
  goalId: string,
  goalTitle: string,
  goalDescription: string | null,
  daysBack: number = DEFAULT_DAYS_BACK
): Promise<{ createdIds: string[]; updatedIds: string[] }> {
  // 1. Fetch recent observations for this goal
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - daysBack);

  const { data: observations, error } = await supabaseAdmin
    .from(Tables.OBSERVATIONS)
    .select('*')
    .eq('user_id', userId)
    .eq('goal_id', goalId)
    .gte('observation_date', cutoff.toISOString())
    .order('observation_date', { ascending: false });

  if (error) {
    throw new Error(`Failed to fetch observations: ${error.message}`);
  }

  if (!observations || observations.length === 0) {
    return { createdIds: [], updatedIds: [] };
  }

  // 2. Fetch existing insights for this goal (so GPT knows what's established)
  const existingInsights = await getExistingInsightsForGoal(userId, goalId);

  // 3. Cluster observations by semantic similarity
  // For small observation sets, fall back to a single cluster so insights can still be generated
  let clusters = clusterObservations(observations as DbObservation[]);

  if (clusters.length === 0 && observations.length > 0) {
    // If clustering produced nothing (too few observations or missing embeddings),
    // treat all observations as a single cluster so we can still generate insights
    clusters = [{
      observations: observations as DbObservation[],
      centroidText: (observations as DbObservation[]).slice(0, 5).map((o) => o.content).join(' | '),
    }];
  }

  if (clusters.length === 0) {
    return { createdIds: [], updatedIds: [] };
  }

  // 4. Incremental synthesis — GPT-4 decides what to update vs create
  const result = await synthesizeInsightsIncrementally(
    clusters,
    existingInsights,
    goalTitle,
    goalDescription
  );

  if (result.actions.length === 0) {
    return { createdIds: [], updatedIds: [] };
  }

  // 5. Determine time range
  const allDates = observations.map((o) => new Date(o.observation_date).getTime());
  const timeRangeStart = new Date(Math.min(...allDates)).toISOString();
  const timeRangeEnd = new Date(Math.max(...allDates)).toISOString();

  // 6. Execute actions (updates + creates)
  const actionResult = await executeInsightActions(
    result.actions,
    userId,
    goalId,
    timeRangeStart,
    timeRangeEnd
  );

  return actionResult;
}

/**
 * Generate insights for ALL active goals of a user.
 */
export async function generateInsightsForAllGoals(
  userId: string,
  daysBack: number = DEFAULT_DAYS_BACK
): Promise<{
  totalCreated: number;
  totalUpdated: number;
  byGoal: Record<string, { created: number; updated: number }>;
}> {
  const goals = await getActiveGoalsWithEmbeddings(userId);

  if (goals.length === 0) {
    return { totalCreated: 0, totalUpdated: 0, byGoal: {} };
  }

  // Create pipeline run record
  const { data: pipelineRun } = await supabaseAdmin
    .from(Tables.PIPELINE_RUNS)
    .insert({
      user_id: userId,
      run_type: 'insight_generation',
      status: 'running',
    })
    .select('id')
    .single();

  let totalCreated = 0;
  let totalUpdated = 0;
  const byGoal: Record<string, { created: number; updated: number }> = {};

  try {
    for (const goal of goals) {
      const result = await generateInsightsForGoal(
        userId,
        goal.id,
        goal.title,
        goal.description,
        daysBack
      );
      byGoal[goal.id] = {
        created: result.createdIds.length,
        updated: result.updatedIds.length,
      };
      totalCreated += result.createdIds.length;
      totalUpdated += result.updatedIds.length;
    }

    if (pipelineRun) {
      await supabaseAdmin
        .from(Tables.PIPELINE_RUNS)
        .update({
          status: 'completed',
          insights_created: totalCreated,
          completed_at: new Date().toISOString(),
        })
        .eq('id', pipelineRun.id);
    }
  } catch (err) {
    if (pipelineRun) {
      await supabaseAdmin
        .from(Tables.PIPELINE_RUNS)
        .update({
          status: 'failed',
          insights_created: totalCreated,
          error_message: err instanceof Error ? err.message : 'Unknown error',
          completed_at: new Date().toISOString(),
        })
        .eq('id', pipelineRun.id);
    }
    throw err;
  }

  return { totalCreated, totalUpdated, byGoal };
}

// ============================================
// Embedding generation for insights
// ============================================
async function generateInsightEmbeddings(insightIds: string[]): Promise<void> {
  if (insightIds.length === 0) return;

  const { data: insights, error } = await supabaseAdmin
    .from(Tables.INSIGHTS)
    .select('id, title, content')
    .in('id', insightIds);

  if (error || !insights || insights.length === 0) return;

  const texts = insights.map((i) => `${i.title}: ${i.content}`);
  const embeddings = await generateEmbeddings(texts);

  for (let i = 0; i < insights.length; i++) {
    const insight = insights[i];
    const embedding = embeddings[i];
    if (insight && embedding) {
      await supabaseAdmin
        .from(Tables.INSIGHTS)
        .update({ embedding })
        .eq('id', insight.id);
    }
  }
}

async function regenerateInsightEmbedding(insightId: string): Promise<void> {
  const { data: insight, error } = await supabaseAdmin
    .from(Tables.INSIGHTS)
    .select('id, title, content')
    .eq('id', insightId)
    .single();

  if (error || !insight) return;

  const embedding = await generateEmbedding(`${insight.title}: ${insight.content}`);
  await supabaseAdmin
    .from(Tables.INSIGHTS)
    .update({ embedding })
    .eq('id', insightId);
}

// ============================================
// Query insights
// ============================================
export async function listInsights(
  userId: string,
  options?: {
    goalId?: string;
    limit?: number;
    offset?: number;
  }
): Promise<{ insights: DbInsight[]; total: number }> {
  let query = supabaseAdmin
    .from(Tables.INSIGHTS)
    .select('*', { count: 'exact' })
    .eq('user_id', userId)
    .order('created_at', { ascending: false });

  if (options?.goalId) query = query.eq('goal_id', options.goalId);
  if (options?.limit) query = query.limit(options.limit);
  if (options?.offset) query = query.range(options.offset, options.offset + (options.limit || 50) - 1);

  const { data, error, count } = await query;

  if (error) throw new Error(`Failed to list insights: ${error.message}`);

  return {
    insights: (data || []) as DbInsight[],
    total: count || 0,
  };
}

/**
 * Get a single insight with its supporting observations.
 */
export async function getInsightWithObservations(
  insightId: string,
  userId: string
): Promise<{ insight: DbInsight; observations: DbObservation[] } | null> {
  const { data: insight, error } = await supabaseAdmin
    .from(Tables.INSIGHTS)
    .select('*')
    .eq('id', insightId)
    .eq('user_id', userId)
    .single();

  if (error || !insight) return null;

  const typedInsight = insight as DbInsight;

  let observations: DbObservation[] = [];
  if (typedInsight.supporting_observation_ids.length > 0) {
    const { data: obs } = await supabaseAdmin
      .from(Tables.OBSERVATIONS)
      .select('*')
      .in('id', typedInsight.supporting_observation_ids);
    observations = (obs || []) as DbObservation[];
  }

  return { insight: typedInsight, observations };
}
