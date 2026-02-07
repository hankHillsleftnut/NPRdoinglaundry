import { generateEmbedding, generateEmbeddings, jsonChatCompletion } from '../utils/openai.js';
import { supabaseAdmin, Tables } from '../utils/supabase.js';
import { config } from '../utils/config.js';
import { getActiveGoalsWithEmbeddings } from './goals.js';
import type {
  ObservationExtractionResult,
  DbObservation,
} from '../types/index.js';

// ============================================
// Cosine similarity (used for goal relevance)
// ============================================
function cosineSimilarity(a: number[], b: number[]): number {
  let dotProduct = 0;
  let normA = 0;
  let normB = 0;
  for (let i = 0; i < a.length; i++) {
    dotProduct += a[i]! * b[i]!;
    normA += a[i]! * a[i]!;
    normB += b[i]! * b[i]!;
  }
  return dotProduct / (Math.sqrt(normA) * Math.sqrt(normB));
}

// ============================================
// Chunk raw content into paragraphs / segments
// ============================================
function chunkContent(content: string, maxChunkLength: number = 1500): string[] {
  // Split on double newlines first (paragraph boundaries)
  const paragraphs = content.split(/\n\s*\n/).filter((p) => p.trim().length > 0);

  const chunks: string[] = [];
  let currentChunk = '';

  for (const paragraph of paragraphs) {
    if (currentChunk.length + paragraph.length > maxChunkLength && currentChunk.length > 0) {
      chunks.push(currentChunk.trim());
      currentChunk = paragraph;
    } else {
      currentChunk += (currentChunk ? '\n\n' : '') + paragraph;
    }
  }

  if (currentChunk.trim().length > 0) {
    chunks.push(currentChunk.trim());
  }

  // If content has no paragraph breaks, split by sentences
  if (chunks.length === 0 && content.trim().length > 0) {
    chunks.push(content.trim());
  }

  return chunks;
}

// ============================================
// Filter chunks by goal relevance
// ============================================
interface RelevantChunk {
  chunk: string;
  similarity: number;
}

async function filterChunksByGoal(
  chunks: string[],
  goalEmbedding: number[],
  threshold: number = 0.35
): Promise<RelevantChunk[]> {
  if (chunks.length === 0) return [];

  // Embed all chunks
  const chunkEmbeddings = await generateEmbeddings(chunks);

  const relevant: RelevantChunk[] = [];
  for (let i = 0; i < chunks.length; i++) {
    const embedding = chunkEmbeddings[i];
    if (!embedding) continue;

    const similarity = cosineSimilarity(embedding, goalEmbedding);
    if (similarity >= threshold) {
      relevant.push({ chunk: chunks[i]!, similarity });
    }
  }

  // Sort by relevance descending
  relevant.sort((a, b) => b.similarity - a.similarity);

  return relevant;
}

// ============================================
// GPT-4 observation extraction from relevant chunks
// ============================================
async function extractObservationsFromChunks(
  relevantChunks: RelevantChunk[],
  goalTitle: string,
  goalDescription: string | null
): Promise<ObservationExtractionResult> {
  if (relevantChunks.length === 0) {
    return { observations: [], processingNotes: 'No relevant chunks found for this goal.' };
  }

  const goalText = goalDescription
    ? `"${goalTitle}" — ${goalDescription}`
    : `"${goalTitle}"`;

  const systemPrompt = `You are an expert at extracting atomic observations from personal data that are relevant to a specific user goal.

THE USER'S GOAL: ${goalText}

Your job is to read the content below and extract ONLY facts that are relevant to this goal. Each observation should be:
- ONE atomic fact (not a compound statement)
- Directly relevant to the user's goal
- Paired with a short "reason_why" explaining how it connects to the goal

RULES:
1. Only extract facts relevant to the goal. Ignore unrelated content.
2. Each observation = ONE atomic, self-contained statement.
3. Be specific. "User exercised" is bad. "User ran 3 miles on Tuesday morning" is good.
4. The reason_why should be 1-2 sentences explaining the relevance to the goal.
5. confidence_score: how confident you are this is accurate (0.0-1.0).
6. If nothing in the content relates to the goal, return an empty observations array.

OUTPUT FORMAT: Return a JSON object:
{
  "observations": [
    {
      "content": "the atomic fact / observation",
      "reason_why": "why this is relevant to the goal",
      "confidence_score": 0.0-1.0
    }
  ],
  "processingNotes": "optional notes about the extraction"
}`;

  const chunksText = relevantChunks
    .map((rc, i) => `--- Chunk ${i + 1} (relevance: ${rc.similarity.toFixed(2)}) ---\n${rc.chunk}`)
    .join('\n\n');

  const userMessage = `Extract goal-relevant observations from this content:\n\n${chunksText}`;

  try {
    const result = await jsonChatCompletion<ObservationExtractionResult>(
      systemPrompt,
      userMessage,
      { temperature: 0.2, maxTokens: 4096 }
    );

    // Validate observations
    const valid = (result.observations || []).filter(
      (o) =>
        typeof o.content === 'string' &&
        o.content.length > 0 &&
        typeof o.reason_why === 'string' &&
        o.reason_why.length > 0 &&
        typeof o.confidence_score === 'number' &&
        o.confidence_score >= 0 &&
        o.confidence_score <= 1
    );

    return {
      observations: valid,
      processingNotes: result.processingNotes,
    };
  } catch (error) {
    console.error('Observation extraction error:', error);
    return { observations: [], processingNotes: `Error: ${error instanceof Error ? error.message : 'Unknown'}` };
  }
}

// ============================================
// Main pipeline: process raw content for a user
// ============================================

/**
 * Process a single raw content item against all active goals.
 * Returns the total number of observations created.
 */
export async function processContentForObservations(
  rawContentId: string,
  userId: string
): Promise<{ observationIds: string[]; byGoal: Record<string, number> }> {
  // 1. Fetch raw content
  const { data: rawContent, error: fetchError } = await supabaseAdmin
    .from(Tables.RAW_CONTENT)
    .select('*')
    .eq('id', rawContentId)
    .eq('user_id', userId)
    .single();

  if (fetchError || !rawContent) {
    throw new Error(`Raw content not found: ${rawContentId}`);
  }

  // 2. Get active goals with embeddings
  const goals = await getActiveGoalsWithEmbeddings(userId);

  if (goals.length === 0) {
    return { observationIds: [], byGoal: {} };
  }

  // 3. Chunk the content
  const chunks = chunkContent(rawContent.content);

  if (chunks.length === 0) {
    return { observationIds: [], byGoal: {} };
  }

  // 4. For each goal, filter chunks and extract observations
  const allObservationIds: string[] = [];
  const byGoal: Record<string, number> = {};

  for (const goal of goals) {
    // Filter chunks by goal relevance
    const relevantChunks = await filterChunksByGoal(chunks, goal.embedding);

    if (relevantChunks.length === 0) {
      byGoal[goal.id] = 0;
      continue;
    }

    // Extract observations
    const result = await extractObservationsFromChunks(
      relevantChunks,
      goal.title,
      goal.description
    );

    if (result.observations.length === 0) {
      byGoal[goal.id] = 0;
      continue;
    }

    // Determine observation date
    const observationDate =
      rawContent.content_date || rawContent.created_at || new Date().toISOString();

    // Insert observations
    const toInsert = result.observations.map((obs) => ({
      user_id: userId,
      goal_id: goal.id,
      raw_content_id: rawContentId,
      content: obs.content,
      reason_why: obs.reason_why,
      confidence_score: obs.confidence_score,
      observation_date: observationDate,
      metadata: {},
    }));

    const { data: inserted, error: insertError } = await supabaseAdmin
      .from(Tables.OBSERVATIONS)
      .insert(toInsert)
      .select('id');

    if (insertError) {
      console.error(`Failed to insert observations for goal ${goal.id}:`, insertError);
      byGoal[goal.id] = 0;
      continue;
    }

    const ids = (inserted || []).map((o) => o.id);
    allObservationIds.push(...ids);
    byGoal[goal.id] = ids.length;

    // Generate embeddings for the new observations (must complete before insight synthesis)
    try {
      await generateObservationEmbeddings(ids);
    } catch (err) {
      console.error('Failed to generate observation embeddings:', err);
    }
  }

  return { observationIds: allObservationIds, byGoal };
}

/**
 * Process all pending raw content for a user.
 * "Pending" = processing_status is 'completed' (insight_units extraction done)
 * but not yet processed for observations.
 * We track this via the pipeline_runs table.
 */
export async function processAllPendingContent(
  userId: string,
  forceReprocess: boolean = false
): Promise<{ totalObservations: number; contentProcessed: number; byGoal: Record<string, number> }> {
  let unprocessed: { id: string }[];

  if (forceReprocess) {
    // Force mode: reprocess ALL content regardless of pipeline run history
    // First, delete old observation_extraction pipeline runs so they don't block future runs
    await supabaseAdmin
      .from(Tables.PIPELINE_RUNS)
      .delete()
      .eq('user_id', userId)
      .eq('run_type', 'observation_extraction');

    const { data: rawContents, error } = await supabaseAdmin
      .from(Tables.RAW_CONTENT)
      .select('id')
      .eq('user_id', userId)
      .order('created_at', { ascending: true });

    if (error || !rawContents) {
      throw new Error(`Failed to fetch raw content: ${error?.message}`);
    }

    unprocessed = rawContents;
  } else {
    // Normal mode: only process content not yet in a completed pipeline run
    const { data: alreadyProcessed } = await supabaseAdmin
      .from(Tables.PIPELINE_RUNS)
      .select('raw_content_ids')
      .eq('user_id', userId)
      .eq('run_type', 'observation_extraction')
      .eq('status', 'completed');

    const processedIds = new Set(
      (alreadyProcessed || []).flatMap((r) => r.raw_content_ids || [])
    );

    const { data: rawContents, error } = await supabaseAdmin
      .from(Tables.RAW_CONTENT)
      .select('id')
      .eq('user_id', userId)
      .order('created_at', { ascending: true });

    if (error || !rawContents) {
      throw new Error(`Failed to fetch raw content: ${error?.message}`);
    }

    unprocessed = rawContents.filter((rc) => !processedIds.has(rc.id));
  }

  if (unprocessed.length === 0) {
    return { totalObservations: 0, contentProcessed: 0, byGoal: {} };
  }

  // Create pipeline run record
  const { data: pipelineRun } = await supabaseAdmin
    .from(Tables.PIPELINE_RUNS)
    .insert({
      user_id: userId,
      run_type: 'observation_extraction',
      status: 'running',
      raw_content_ids: unprocessed.map((rc) => rc.id),
    })
    .select('id')
    .single();

  let totalObservations = 0;
  const aggregatedByGoal: Record<string, number> = {};

  try {
    for (const rc of unprocessed) {
      const result = await processContentForObservations(rc.id, userId);
      totalObservations += result.observationIds.length;

      for (const [goalId, count] of Object.entries(result.byGoal)) {
        aggregatedByGoal[goalId] = (aggregatedByGoal[goalId] || 0) + count;
      }
    }

    // Mark pipeline run as completed
    if (pipelineRun) {
      await supabaseAdmin
        .from(Tables.PIPELINE_RUNS)
        .update({
          status: 'completed',
          observations_created: totalObservations,
          completed_at: new Date().toISOString(),
        })
        .eq('id', pipelineRun.id);
    }
  } catch (err) {
    // Mark pipeline run as failed
    if (pipelineRun) {
      await supabaseAdmin
        .from(Tables.PIPELINE_RUNS)
        .update({
          status: 'failed',
          observations_created: totalObservations,
          error_message: err instanceof Error ? err.message : 'Unknown error',
          completed_at: new Date().toISOString(),
        })
        .eq('id', pipelineRun.id);
    }
    throw err;
  }

  return {
    totalObservations,
    contentProcessed: unprocessed.length,
    byGoal: aggregatedByGoal,
  };
}

// ============================================
// Embedding generation for observations
// ============================================
export async function generateObservationEmbeddings(observationIds: string[]): Promise<void> {
  if (observationIds.length === 0) return;

  const { data: observations, error } = await supabaseAdmin
    .from(Tables.OBSERVATIONS)
    .select('id, content, reason_why')
    .in('id', observationIds);

  if (error || !observations || observations.length === 0) return;

  const texts = observations.map((o) => `${o.content} — ${o.reason_why}`);
  const embeddings = await generateEmbeddings(texts);

  for (let i = 0; i < observations.length; i++) {
    const obs = observations[i];
    const embedding = embeddings[i];
    if (obs && embedding) {
      await supabaseAdmin
        .from(Tables.OBSERVATIONS)
        .update({ embedding })
        .eq('id', obs.id);
    }
  }
}

// ============================================
// Query observations
// ============================================
export async function listObservations(
  userId: string,
  options?: {
    goalId?: string;
    limit?: number;
    offset?: number;
    startDate?: string;
    endDate?: string;
  }
): Promise<{ observations: DbObservation[]; total: number }> {
  let query = supabaseAdmin
    .from(Tables.OBSERVATIONS)
    .select('*', { count: 'exact' })
    .eq('user_id', userId)
    .order('observation_date', { ascending: false });

  if (options?.goalId) query = query.eq('goal_id', options.goalId);
  if (options?.startDate) query = query.gte('observation_date', options.startDate);
  if (options?.endDate) query = query.lte('observation_date', options.endDate);
  if (options?.limit) query = query.limit(options.limit);
  if (options?.offset) query = query.range(options.offset, options.offset + (options.limit || 50) - 1);

  const { data, error, count } = await query;

  if (error) throw new Error(`Failed to list observations: ${error.message}`);

  return {
    observations: (data || []) as DbObservation[],
    total: count || 0,
  };
}
