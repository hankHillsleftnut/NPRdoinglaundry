import { generateEmbedding, generateEmbeddings, jsonChatCompletion } from '../utils/openai.js';
import { supabaseAdmin, Tables } from '../utils/supabase.js';
import { config } from '../utils/config.js';
import type { ConnectionType, DbInsightUnit } from '../types/index.js';

// Connection analysis response type
interface ConnectionAnalysis {
  connections: Array<{
    target_insight_id: string;
    connection_type: ConnectionType;
    strength: number;
    reasoning: string;
    is_bidirectional: boolean;
  }>;
}

// Generate and store embedding for an insight
export async function generateInsightEmbedding(insightId: string): Promise<void> {
  const { data: insight, error } = await supabaseAdmin
    .from(Tables.INSIGHT_UNITS)
    .select('id, content, primary_category')
    .eq('id', insightId)
    .single();

  if (error || !insight) {
    throw new Error(`Insight not found: ${insightId}`);
  }

  // Create embedding text that includes category context
  const embeddingText = `[${insight.primary_category}] ${insight.content}`;
  const embedding = await generateEmbedding(embeddingText);

  // Store embedding
  await supabaseAdmin
    .from(Tables.INSIGHT_UNITS)
    .update({ embedding })
    .eq('id', insightId);
}

// Generate embeddings for multiple insights (batch)
export async function generateInsightEmbeddings(insightIds: string[]): Promise<void> {
  if (insightIds.length === 0) return;

  const { data: insights, error } = await supabaseAdmin
    .from(Tables.INSIGHT_UNITS)
    .select('id, content, primary_category')
    .in('id', insightIds);

  if (error || !insights || insights.length === 0) {
    throw new Error('No insights found for embedding generation');
  }

  const texts = insights.map((i) => `[${i.primary_category}] ${i.content}`);
  const embeddings = await generateEmbeddings(texts);

  // Update each insight with its embedding
  for (let i = 0; i < insights.length; i++) {
    const insight = insights[i];
    const embedding = embeddings[i];
    if (insight && embedding) {
      await supabaseAdmin
        .from(Tables.INSIGHT_UNITS)
        .update({ embedding })
        .eq('id', insight.id);
    }
  }
}

// Find similar insights using vector search
export async function findSimilarInsights(
  insightId: string,
  userId: string,
  threshold: number = config.patterns.similarityThreshold,
  limit: number = 20
): Promise<Array<{ id: string; content: string; similarity: number }>> {
  // Get the source insight's embedding
  const { data: sourceInsight, error: sourceError } = await supabaseAdmin
    .from(Tables.INSIGHT_UNITS)
    .select('embedding')
    .eq('id', insightId)
    .single();

  if (sourceError || !sourceInsight?.embedding) {
    throw new Error('Source insight has no embedding');
  }

  // Use the match_insights function
  const { data: matches, error: matchError } = await supabaseAdmin.rpc(
    'match_insights',
    {
      query_embedding: sourceInsight.embedding,
      match_threshold: threshold,
      match_count: limit,
      filter_user_id: userId,
      exclude_insight_id: insightId,
    }
  );

  if (matchError) {
    throw new Error(`Vector search failed: ${matchError.message}`);
  }

  return (matches || []).map((m: { id: string; content: string; similarity: number }) => ({
    id: m.id,
    content: m.content,
    similarity: m.similarity,
  }));
}

// Search insights semantically
export async function searchInsightsSemantic(
  query: string,
  userId: string,
  options?: {
    category?: string;
    startDate?: Date;
    endDate?: Date;
    limit?: number;
  }
): Promise<Array<{ id: string; content: string; category: string; date: string; similarity: number }>> {
  const queryEmbedding = await generateEmbedding(query);

  if (options?.startDate && options?.endDate) {
    // Use date-ranged search
    const { data: matches, error } = await supabaseAdmin.rpc(
      'search_insights_in_range',
      {
        query_embedding: queryEmbedding,
        p_user_id: userId,
        start_date: options.startDate.toISOString(),
        end_date: options.endDate.toISOString(),
        match_threshold: 0.5,
        match_count: options.limit || 20,
      }
    );

    if (error) throw new Error(`Search failed: ${error.message}`);

    return (matches || []).map((m: { id: string; content: string; primary_category: string; insight_date: string; similarity: number }) => ({
      id: m.id,
      content: m.content,
      category: m.primary_category,
      date: m.insight_date,
      similarity: m.similarity,
    }));
  }

  // Standard search
  const { data: matches, error } = await supabaseAdmin.rpc('match_insights', {
    query_embedding: queryEmbedding,
    match_threshold: 0.5,
    match_count: options?.limit || 20,
    filter_user_id: userId,
    filter_category: options?.category || null,
  });

  if (error) throw new Error(`Search failed: ${error.message}`);

  return (matches || []).map((m: { id: string; content: string; primary_category: string; insight_date: string; similarity: number }) => ({
    id: m.id,
    content: m.content,
    category: m.primary_category,
    date: m.insight_date,
    similarity: m.similarity,
  }));
}

// Analyze connection types between insights using GPT-4
async function analyzeConnections(
  sourceInsight: DbInsightUnit,
  similarInsights: Array<{ id: string; content: string; similarity: number }>
): Promise<ConnectionAnalysis> {
  if (similarInsights.length === 0) {
    return { connections: [] };
  }

  const systemPrompt = `You are a CBT therapist analyzing how insights connect to form larger patterns in self-esteem and cognition.

Given a source insight and related insights, determine connections that reveal:
1. How cognitive distortions reinforce each other
2. How capability evidence contradicts negative beliefs
3. How thought patterns lead to behavioral patterns
4. How discounting mechanisms prevent belief change

**CONNECTION TYPES:**

**1. reinforces_distortion** — This insight strengthens or maintains the other's negative pattern
   - Example: Source = "User catastrophizes about work", Target = "User avoids challenging projects"
   - The catastrophizing CAUSES the avoidance, which prevents evidence gathering, which maintains the catastrophizing

**2. contradicts_belief** — This insight provides evidence AGAINST the other's negative conclusion
   - Example: Source = "User believes 'I'm incompetent at leadership'", Target = "User successfully led team through crisis"
   - The capability evidence DIRECTLY contradicts the belief

**3. discounting_mechanism** — This insight explains HOW the user dismisses the other
   - Example: Source = "User received praise for presentation", Target = "User attributes success to luck, not skill"
   - The discounting mechanism prevents the praise from challenging the core belief

**4. thought_to_behavior** — Thought pattern directly causes behavioral pattern
   - Example: Source = "User thinks 'I'll say something stupid'", Target = "User stays silent in meetings"
   - Classic CBT chain — thought → emotion → behavior

**5. behavior_to_outcome** — Behavior creates outcome that confirms original thought
   - Example: Source = "User procrastinates due to perfectionism", Target = "User submits rushed work, confirming 'I'm not good enough'"
   - Self-fulfilling prophecy cycle

**6. capability_cluster** — Multiple insights demonstrating the same competency
   - Example: Source = "User resolved conflict with coworker", Target = "User set boundary with friend"
   - Pattern of capability in interpersonal situations

**ANALYSIS RULES:**
1. Strength (0.0-1.0) based on:
   - How DIRECT the connection is (thought → immediate behavior = high strength)
   - How CONSISTENT the pattern is (happens once = low, happens 5 times = high)
   - How THERAPEUTIC the connection is (does knowing this help the user?)

2. Prioritize connections that:
   - Reveal self-fulfilling prophecies (thought → behavior → outcome confirming thought)
   - Show capability the user is missing (evidence cluster contradicting belief)
   - Explain resistance to change (how discounting prevents belief update)

3. Note if bidirectional (both insights reinforce each other in a cycle)
4. Only include connections with therapeutic value — not just "both about work"

OUTPUT FORMAT: Return a JSON object:
{
  "connections": [
    {
      "target_insight_id": "uuid",
      "connection_type": "reinforces_distortion|contradicts_belief|discounting_mechanism|thought_to_behavior|behavior_to_outcome|capability_cluster",
      "strength": 0.0-1.0,
      "reasoning": "How this connection operates and its therapeutic significance",
      "is_bidirectional": boolean
    }
  ]
}

Only include connections with strength >= ${config.patterns.connectionStrengthThreshold} and clear therapeutic value.`;

  const candidatesText = similarInsights
    .map((i) => `- ID: ${i.id}\n  Content: "${i.content}"`)
    .join('\n\n');

  const userMessage = `Analyze connections with CBT lens:

SOURCE INSIGHT:
Category: ${sourceInsight.primary_category}
Content: "${sourceInsight.content}"
Date: ${sourceInsight.insight_date}
${sourceInsight.sentiment ? `Sentiment: ${sourceInsight.sentiment}` : ''}

CANDIDATE INSIGHTS TO ANALYZE:
${candidatesText}

Focus on: How do these insights form cycles of low self-esteem OR accumulate evidence to challenge negative beliefs?`;

  try {
    const result = await jsonChatCompletion<ConnectionAnalysis>(
      systemPrompt,
      userMessage,
      { temperature: 0.2 }
    );

    return result;
  } catch (error) {
    console.error('Connection analysis error:', error);
    return { connections: [] };
  }
}

// Find and create connections for an insight
export async function findAndCreateConnections(
  insightId: string,
  userId: string
): Promise<{ connectionCount: number }> {
  // Get the source insight
  const { data: sourceInsight, error: sourceError } = await supabaseAdmin
    .from(Tables.INSIGHT_UNITS)
    .select('*')
    .eq('id', insightId)
    .single();

  if (sourceError || !sourceInsight) {
    throw new Error('Source insight not found');
  }

  // Ensure embedding exists
  if (!sourceInsight.embedding) {
    await generateInsightEmbedding(insightId);
  }

  // Find similar insights
  const similarInsights = await findSimilarInsights(insightId, userId);

  if (similarInsights.length === 0) {
    return { connectionCount: 0 };
  }

  // Analyze connections
  const analysis = await analyzeConnections(
    sourceInsight as DbInsightUnit,
    similarInsights
  );

  if (analysis.connections.length === 0) {
    return { connectionCount: 0 };
  }

  // Create connections
  const connectionsToInsert = analysis.connections.map((conn) => ({
    source_insight_id: insightId,
    target_insight_id: conn.target_insight_id,
    connection_type: conn.connection_type,
    strength: conn.strength,
    reasoning: conn.reasoning,
    is_bidirectional: conn.is_bidirectional,
  }));

  const { error: insertError } = await supabaseAdmin
    .from(Tables.INSIGHT_CONNECTIONS)
    .upsert(connectionsToInsert, {
      onConflict: 'source_insight_id,target_insight_id,connection_type',
    });

  if (insertError) {
    console.error('Failed to insert connections:', insertError);
  }

  return { connectionCount: analysis.connections.length };
}

// Process connections for multiple insights (batch)
export async function processConnectionsBatch(
  insightIds: string[],
  userId: string
): Promise<{ totalConnections: number }> {
  let totalConnections = 0;

  // First, ensure all insights have embeddings
  const { data: insightsWithoutEmbeddings } = await supabaseAdmin
    .from(Tables.INSIGHT_UNITS)
    .select('id')
    .in('id', insightIds)
    .is('embedding', null);

  if (insightsWithoutEmbeddings && insightsWithoutEmbeddings.length > 0) {
    await generateInsightEmbeddings(
      insightsWithoutEmbeddings.map((i) => i.id)
    );
  }

  // Process connections for each insight
  for (const insightId of insightIds) {
    try {
      const result = await findAndCreateConnections(insightId, userId);
      totalConnections += result.connectionCount;
    } catch (error) {
      console.error(`Failed to process connections for ${insightId}:`, error);
    }
  }

  return { totalConnections };
}

// Get connections for an insight
export async function getInsightConnections(
  insightId: string,
  depth: number = 1
): Promise<Array<{
  sourceId: string;
  sourceContent: string;
  targetId: string;
  targetContent: string;
  connectionType: ConnectionType;
  strength: number;
  reasoning: string | null;
}>> {
  const { data, error } = await supabaseAdmin.rpc('get_insight_connections', {
    p_insight_id: insightId,
    p_depth: depth,
  });

  if (error) {
    throw new Error(`Failed to get connections: ${error.message}`);
  }

  return (data || []).map((c: {
    source_id: string;
    source_content: string;
    target_id: string;
    target_content: string;
    connection_type: ConnectionType;
    strength: number;
    reasoning: string | null;
  }) => ({
    sourceId: c.source_id,
    sourceContent: c.source_content,
    targetId: c.target_id,
    targetContent: c.target_content,
    connectionType: c.connection_type,
    strength: c.strength,
    reasoning: c.reasoning,
  }));
}
