/**
 * 3-Pass Podcast Generation Service
 *
 * Pass 1 — Outline (Claude Sonnet): Structure the episode from insights + goals
 * Pass 2 — Research (Perplexity Sonar Pro): Enrich each segment with web research
 * Pass 3 — Script (Claude Sonnet): Write the final conversational podcast script
 *
 * After the script is generated, ElevenLabs TTS converts it to audio.
 */

import { supabaseAdmin, Tables } from '../utils/supabase.js';
import { chatCompletion, jsonChatCompletion } from '../utils/openai.js';
import { batchResearch } from './perplexity.js';
import { textToSpeech, estimateDuration, getPersonaConfig, VOICE_PERSONAS, type VoicePersona } from './elevenlabs.js';
import type {
  DbInsight,
  DbGoal,
  DbObservation,
  PodcastOutline,
  PodcastSegment,
  ResearchCitation,
  DbPodcastEpisode,
} from '../types/index.js';

// ============================================
// PASS 1: Outline Generation (Claude)
// ============================================

const OUTLINE_SYSTEM_PROMPT = `You are a podcast producer for a deeply personal weekly reflection podcast called "Retrospect."

Your job is to create a structured outline for an 8–10 minute episode based on the user's goals, insights, and observations from the past week.

CRITICAL PERSPECTIVE RULE:
- The podcast host is a separate person speaking TO the listener. The host is like a mentor, a cool older friend, someone who genuinely knows the listener and cares.
- The host uses SECOND PERSON ("you") to address the listener. Example: "You've been making real progress on..." NOT "I've been making progress on..."
- The host says things like "I noticed you...", "Here's what stood out to me about your week...", "Let me be real with you..."
- The host is NOT the listener. The host is talking ABOUT the listener's life, TO the listener.

Other rules:
- Never sycophantic, never generic. Be honest and constructive.
- Ground everything in the user's actual data. Reference specific observations and insights.
- If progress on a goal has stalled, say so directly but kindly.
- Create a narrative arc: opening hook → goal updates → deep dive into 1-2 key insights → forward-looking reflection → close.
- Mark each segment with research queries where external information would genuinely add value (science, frameworks, expert perspectives).
- Target 8–10 minutes total (~1200–1500 spoken words).

Respond with valid JSON matching this structure:
{
  "theme": "One-sentence theme for this episode",
  "segments": [
    {
      "title": "Segment title",
      "type": "intro | goal_update | insight_deep_dive | research | reflection | outro",
      "insightIds": ["insight-uuid-1"],
      "goalIds": ["goal-uuid-1"],
      "talkingPoints": ["Point 1", "Point 2"],
      "researchQueries": ["optional research query"],
      "estimatedSeconds": 60
    }
  ],
  "estimatedMinutes": 9
}`;

interface OutlineInput {
  goals: DbGoal[];
  insights: DbInsight[];
  observations: DbObservation[];
  previousEpisodeSummary?: string;
}

async function generateOutline(input: OutlineInput): Promise<PodcastOutline> {
  const goalSummaries = input.goals.map(
    (g) => `- [${g.id}] "${g.title}"${g.description ? `: ${g.description}` : ''}`
  );

  const insightSummaries = input.insights.map(
    (ins) =>
      `- [${ins.id}] "${ins.title}": ${ins.content}\n  Evidence: ${ins.evidence_summary}\n  Confidence: ${ins.confidence_score}\n  Goal: ${ins.goal_id}`
  );

  const observationSummaries = input.observations.slice(0, 40).map(
    (obs) =>
      `- [${obs.id}] (goal: ${obs.goal_id}) ${obs.content}\n  Why relevant: ${obs.reason_why}`
  );

  let userMessage = `Here is the user's data for this week's episode:

## Active Goals
${goalSummaries.join('\n') || '(none)'}

## Recent Insights (synthesized from observations)
${insightSummaries.join('\n') || '(none)'}

## Recent Observations (raw data points)
${observationSummaries.join('\n') || '(none)'}`;

  if (input.previousEpisodeSummary) {
    userMessage += `\n\n## Previous Episode Summary\n${input.previousEpisodeSummary}`;
  }

  userMessage += `\n\nCreate a structured outline for this week's podcast episode. Make it personal, grounded, and honest.`;

  console.log('[Podcast] Pass 1: Generating outline...');
  const outline = await jsonChatCompletion<PodcastOutline>(
    OUTLINE_SYSTEM_PROMPT,
    userMessage,
    { temperature: 0.5, maxTokens: 4096 }
  );

  console.log(
    `[Podcast] Outline generated: "${outline.theme}" — ${outline.segments.length} segments, ~${outline.estimatedMinutes} min`
  );

  return outline;
}

// ============================================
// PASS 2: Research Enrichment (Perplexity)
// ============================================

interface ResearchResult {
  segmentResearch: Map<number, { answer: string; citations: ResearchCitation[] }[]>;
  allCitations: ResearchCitation[];
}

async function enrichWithResearch(outline: PodcastOutline): Promise<ResearchResult> {
  console.log('[Podcast] Pass 2: Research enrichment...');

  // Collect all research queries from all segments
  const queryMap: { segmentIndex: number; query: string }[] = [];
  for (let i = 0; i < outline.segments.length; i++) {
    const seg = outline.segments[i]!;
    for (const query of seg.researchQueries) {
      queryMap.push({ segmentIndex: i, query });
    }
  }

  if (queryMap.length === 0) {
    console.log('[Podcast] No research queries to process.');
    return { segmentResearch: new Map(), allCitations: [] };
  }

  console.log(`[Podcast] Researching ${queryMap.length} queries...`);

  const systemContext = `You are a research assistant for a personal reflection podcast. Provide concise, factual answers grounded in recent research, science, or expert perspectives. Focus on practical, actionable information. Keep answers to 2-3 paragraphs max. Cite specific studies, books, or experts when possible.`;

  const allQueries = queryMap.map((q) => q.query);
  const researchResults = await batchResearch(allQueries, systemContext);

  // Group results by segment
  const segmentResearch = new Map<number, { answer: string; citations: ResearchCitation[] }[]>();
  const allCitations: ResearchCitation[] = [];

  for (const { segmentIndex, query } of queryMap) {
    const result = researchResults.get(query) ?? { answer: '', citations: [] };
    const existing = segmentResearch.get(segmentIndex) ?? [];
    existing.push(result);
    segmentResearch.set(segmentIndex, existing);
    allCitations.push(...result.citations);
  }

  console.log(`[Podcast] Research complete: ${allCitations.length} citations gathered.`);

  return { segmentResearch, allCitations };
}

// ============================================
// PASS 3: Emotion-Annotated Script Generation (Claude)
// ============================================

/**
 * Persona-specific prompt addenda that shape HOW the voice writes.
 * These inject the tonal personality into the script itself.
 */
const PERSONA_PROMPT_STYLES: Record<VoicePersona, string> = {
  thoughtful_friend: `You are a warm, genuine friend talking TO the listener about their life. Your voice personality:
- Natural vocal warmth — your tone brightens when sharing good news about THEM, softens during their vulnerable moments.
- Use [gentle laugh] or [soft chuckle] when something about their week is genuinely funny or endearing — never forced.
- [warm tone] at the start of encouraging passages. [honest, caring tone] when delivering hard truths about their patterns.
- Conversational rhythm — you trail off with "..." when thinking, use em-dashes for mid-thought pivots.
- When celebrating THEIR win: [brightening, genuine excitement] — "You actually did it..."
- When addressing THEIR struggles: [softer, steady voice] — present but not pitying. "I know this one's been tough for you."
- Occasional "you know?" or "right?" to keep it feeling like a real conversation between two people.
- Remember: you are their friend commenting on their life. "I noticed you..." not "I noticed I..."`,

  wise_mentor: `You are a grounded, wise mentor speaking TO the listener about their journey. Your voice personality:
- Measured, deliberate delivery — let important ideas land with weight.
- Use [thoughtful pause] before key insights — give the listener space to absorb what you're telling them.
- [calm, grounded tone] is your baseline. [firm but kind] when being direct about their blind spots.
- When presenting research or frameworks: [engaged, curious tone] — "I found something that connects to what you've been going through..."
- Occasional [quiet intensity] when something really matters — "I need you to hear this..."
- Fewer laughs, but when you do: [warm, knowing smile in voice] — the laugh of someone who's seen things.
- Use "Here's what I want you to sit with..." and "Let me be straight with you..." as transitions.
- Remember: you are their mentor observing their life. Always "you" for their experiences, "I" only for your own commentary.`,

  energetic_host: `You are a dynamic, engaging podcast host talking TO the listener about their week. Your voice personality:
- Varied pacing is your signature — speed up when excited about their progress, slow down for emphasis.
- Use [excited, picking up pace] when diving into something fascinating about their patterns. [leaning in, conspiratorial] for "insider" moments.
- [genuine laugh] and [bright, amused tone] come naturally — you find their story truly interesting.
- When celebrating THEIR wins: [big energy, genuine pride] — "Dude, you crushed it this week..."
- When addressing THEIR tough stuff: [shifting to real talk, grounded] — you can switch gears authentically.
- [curious, fascinated tone] when presenting research — "So I looked into this because of what you said..."
- Use "Okay, so get this..." and "Here's where it gets really interesting..." as energy transitions.
- Remember: you are a host narrating THEIR story back to them. Always second person for their experiences.`,
};

const SCRIPT_SYSTEM_PROMPT_BASE = `You are the host of "Retrospect," a deeply personal weekly podcast. You are a separate person — a mentor, a cool older friend — who knows the listener well and speaks TO them about their life, goals, and growth.

CRITICAL PERSPECTIVE RULES:
- You are NOT the listener. You are a host/mentor talking TO the listener about THEIR life.
- ALWAYS use SECOND PERSON: "you", "your", "you've been..."
- NEVER use first person to describe the listener's experiences. WRONG: "I've been stressed about work." RIGHT: "You've been carrying a lot of stress about work."
- Your first person "I" refers only to yourself as the host: "I noticed something in your week...", "I want to be real with you...", "I found some research on this..."
- Think of yourself as someone who has read their journal, sees patterns they can't see, and cares enough to be honest.

EMOTION-ANNOTATED SCRIPT FORMAT:
Write an emotion-annotated script where inline brackets describe HOW the voice should feel. The TTS engine reads these to control tone, energy, and expressiveness.

Annotation rules:
- Place emotion cues in [square brackets] at natural transition points — before a sentence or clause, not mid-word.
- Use descriptive, natural language: [warm and reflective], [brightening with genuine excitement], [honest, direct tone], [gentle laugh], [soft chuckle], [quiet intensity].
- Let emotion SHIFT dynamically based on content:
  • Celebrating progress on a goal → [brightening] or [genuine excitement]
  • Addressing a stalled goal → [honest, caring tone] or [real talk, grounded]
  • Presenting research → [curious, engaged tone] or [fascinated]
  • Transitioning between topics → [shifting gears] or [taking a breath]
  • Key insight moment → [leaning in, meaningful] or [letting this land]
  • Closing/reflection → [warm, settling] or [reflective, looking ahead]
- Do NOT over-annotate. Place cues at ~every 2-4 sentences, not every line. Let the writing itself carry emotion between cues.
- Use "..." for trailing thoughts, "—" for mid-thought pivots. These create natural rhythm.

Writing style:
- Direct and specific — always reference their actual goals, observations, and insights by name.
- When something isn't going well, say so kindly but clearly. No toxic positivity. No sycophancy.
- Weave in research naturally as "interesting things I found" or "I came across this..." — never lecture.
- Use conversational language. Contractions. Short sentences when impactful.
- Create genuine moments of reflection. Rhetorical questions that make the listener think.
- End segments with small, actionable takeaways or questions for self-reflection.

Output:
- Write ONLY the spoken script with inline [emotion annotations].
- No [MUSIC] cues, no timestamps, no stage directions about actions.
- Target 1200–1500 words for ~8–10 minutes of speech.
- One continuous monologue, flowing naturally between segments.`;

interface ScriptInput {
  outline: PodcastOutline;
  goals: DbGoal[];
  insights: DbInsight[];
  observations: DbObservation[];
  segmentResearch: Map<number, { answer: string; citations: ResearchCitation[] }[]>;
  previousEpisodeSummary?: string;
  persona?: VoicePersona;
}

async function generateScript(input: ScriptInput): Promise<string> {
  const persona = input.persona ?? 'thoughtful_friend';
  const personaStyle = PERSONA_PROMPT_STYLES[persona];

  console.log(`[Podcast] Pass 3: Generating emotion-annotated script (persona: ${persona})...`);

  // Build the full system prompt with persona injection
  const systemPrompt = `${SCRIPT_SYSTEM_PROMPT_BASE}

VOICE PERSONA — ${VOICE_PERSONAS[persona].displayName.toUpperCase()}:
${personaStyle}`;

  let userMessage = `## Episode Outline
Theme: "${input.outline.theme}"

## Segments with Research
`;

  for (let i = 0; i < input.outline.segments.length; i++) {
    const seg = input.outline.segments[i]!;
    userMessage += `\n### Segment ${i + 1}: ${seg.title} (${seg.type}, ~${seg.estimatedSeconds}s)`;
    userMessage += `\nTalking points: ${seg.talkingPoints.join('; ')}`;

    // Segment-level emotion guidance based on type
    const emotionHint = getSegmentEmotionHint(seg.type);
    if (emotionHint) {
      userMessage += `\nEmotional direction: ${emotionHint}`;
    }

    // Add relevant insights
    const segInsights = input.insights.filter((ins) => seg.insightIds.includes(ins.id));
    if (segInsights.length > 0) {
      userMessage += `\nRelevant insights:`;
      for (const ins of segInsights) {
        userMessage += `\n  - "${ins.title}": ${ins.content}`;
      }
    }

    // Add relevant goals
    const segGoals = input.goals.filter((g) => seg.goalIds.includes(g.id));
    if (segGoals.length > 0) {
      userMessage += `\nRelevant goals: ${segGoals.map((g) => `"${g.title}"`).join(', ')}`;
    }

    // Add research findings
    const research = input.segmentResearch.get(i) ?? [];
    if (research.length > 0) {
      userMessage += `\nResearch findings:`;
      for (const r of research) {
        if (r.answer) {
          userMessage += `\n  ${r.answer.slice(0, 500)}`;
          if (r.citations.length > 0) {
            userMessage += `\n  Sources: ${r.citations.map((c) => c.source).join(', ')}`;
          }
        }
      }
    }
  }

  // Add raw context
  userMessage += `\n\n## User's Active Goals`;
  for (const g of input.goals) {
    userMessage += `\n- "${g.title}"${g.description ? `: ${g.description}` : ''}`;
  }

  userMessage += `\n\n## Recent Observations (raw moments from their life)`;
  for (const obs of input.observations.slice(0, 30)) {
    userMessage += `\n- ${obs.content}`;
  }

  if (input.previousEpisodeSummary) {
    userMessage += `\n\n## Previous Episode Summary\n${input.previousEpisodeSummary}`;
  }

  userMessage += `\n\nWrite the full emotion-annotated podcast script now. Make it personal, honest, grounded in their real data, and emotionally alive. Target 1200-1500 words.`;

  const script = await chatCompletion(systemPrompt, userMessage, {
    temperature: 0.7,
    maxTokens: 8192,
  });

  const wordCount = script.split(/\s+/).length;
  console.log(`[Podcast] Emotion-annotated script generated: ${wordCount} words.`);

  return script;
}

/**
 * Map segment types to emotional direction hints for the script writer.
 */
function getSegmentEmotionHint(segmentType: string): string | null {
  switch (segmentType) {
    case 'intro':
      return 'Open with warmth and familiarity. Set the tone for the episode.';
    case 'goal_update':
      return 'Shift tone based on progress — brightening for wins, honest and caring for stalled goals.';
    case 'insight_deep_dive':
      return 'Lean in with curiosity and meaning. This is the meat — make it land.';
    case 'research':
      return 'Shift to engaged curiosity. You find this genuinely fascinating and want to share it.';
    case 'reflection':
      return 'Settle into something warmer and more reflective. Give space for the listener to think.';
    case 'outro':
      return 'Warm close. Forward-looking energy. Leave them feeling seen and motivated.';
    default:
      return null;
  }
}

// ============================================
// ORCHESTRATOR: Full Pipeline
// ============================================

interface GeneratePodcastOptions {
  userId: string;
  daysSince?: number; // How many days of data to include (default: 7)
  previousEpisodeId?: string;
  generationType?: 'weekly' | 'on_demand' | 'milestone';
  skipTTS?: boolean; // Skip audio generation (for testing)
  persona?: VoicePersona; // Voice persona override (otherwise uses user preference)
}

export async function generatePodcastEpisode(
  options: GeneratePodcastOptions
): Promise<DbPodcastEpisode> {
  const {
    userId,
    daysSince = 7,
    previousEpisodeId,
    generationType = 'weekly',
    skipTTS = false,
    persona: personaOverride,
  } = options;

  console.log(`[Podcast] Starting generation for user ${userId} (${daysSince} days)...`);

  // Resolve persona: override > user preference > default
  let persona: VoicePersona = 'thoughtful_friend';
  if (personaOverride) {
    persona = personaOverride;
  } else {
    const { data: userData } = await supabaseAdmin
      .from(Tables.USERS)
      .select('voice_persona')
      .eq('id', userId)
      .single();
    if (userData?.voice_persona && userData.voice_persona in VOICE_PERSONAS) {
      persona = userData.voice_persona as VoicePersona;
    }
  }
  const personaConfig = getPersonaConfig(persona);
  console.log(`[Podcast] Using voice persona: ${personaConfig.displayName}`);

  // 1. Fetch user data
  const since = new Date();
  since.setDate(since.getDate() - daysSince);
  const sinceStr = since.toISOString();

  const [goalsResult, insightsResult, observationsResult] = await Promise.all([
    supabaseAdmin
      .from(Tables.GOALS)
      .select('*')
      .eq('user_id', userId)
      .eq('is_active', true),
    supabaseAdmin
      .from(Tables.INSIGHTS)
      .select('*')
      .eq('user_id', userId)
      .gte('updated_at', sinceStr)
      .order('updated_at', { ascending: false }),
    supabaseAdmin
      .from(Tables.OBSERVATIONS)
      .select('*')
      .eq('user_id', userId)
      .gte('created_at', sinceStr)
      .order('created_at', { ascending: false }),
  ]);

  const goals = (goalsResult.data ?? []) as DbGoal[];
  const insights = (insightsResult.data ?? []) as DbInsight[];
  const observations = (observationsResult.data ?? []) as DbObservation[];

  console.log(
    `[Podcast] Data: ${goals.length} goals, ${insights.length} insights, ${observations.length} observations`
  );

  if (insights.length === 0 && observations.length === 0) {
    throw new Error('Not enough data to generate a podcast episode.');
  }

  // Get previous episode summary if available
  let previousEpisodeSummary: string | undefined;
  if (previousEpisodeId) {
    const { data: prevEp } = await supabaseAdmin
      .from(Tables.PODCAST_EPISODES)
      .select('title, description, topics_covered')
      .eq('id', previousEpisodeId)
      .single();
    if (prevEp) {
      previousEpisodeSummary = `Title: "${prevEp.title}"\nDescription: ${prevEp.description}\nTopics: ${prevEp.topics_covered?.join(', ')}`;
    }
  }

  // Get next episode number
  const { count: episodeCount } = await supabaseAdmin
    .from(Tables.PODCAST_EPISODES)
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId)
    .eq('status', 'ready');
  const episodeNumber = (episodeCount ?? 0) + 1;

  // Create a placeholder episode record (status = 'generating')
  const { data: episodeRow, error: insertError } = await supabaseAdmin
    .from(Tables.PODCAST_EPISODES)
    .insert({
      user_id: userId,
      title: 'Generating...',
      script: '',
      generation_type: generationType,
      status: 'generating',
      insight_ids: insights.map((i) => i.id),
      goal_ids: goals.map((g) => g.id),
      episode_number: episodeNumber,
      covers_period_start: sinceStr,
      covers_period_end: new Date().toISOString(),
      previous_episode_id: previousEpisodeId ?? null,
    })
    .select()
    .single();

  if (insertError || !episodeRow) {
    throw new Error(`Failed to create episode record: ${insertError?.message}`);
  }

  const episodeId = episodeRow.id;

  try {
    // PASS 1: Outline
    const outline = await generateOutline({
      goals,
      insights,
      observations,
      previousEpisodeSummary,
    });

    // PASS 2: Research Enrichment
    const { segmentResearch, allCitations } = await enrichWithResearch(outline);

    // PASS 3: Emotion-Annotated Script
    const script = await generateScript({
      outline,
      goals,
      insights,
      observations,
      segmentResearch,
      previousEpisodeSummary,
      persona,
    });

    // Generate title and description from the script
    const titleDesc = await jsonChatCompletion<{ title: string; description: string; mood: string }>(
      'You generate podcast episode metadata. Respond with JSON: { "title": "...", "description": "...", "mood": "..." }. Title should be catchy and personal (3-6 words). Description is 1-2 sentences. Mood is one word (reflective, energized, contemplative, hopeful, honest, etc.).',
      `Episode theme: "${outline.theme}"\n\nScript preview: ${script.slice(0, 500)}`,
      { temperature: 0.6, maxTokens: 256 }
    );

    // TTS
    let audioUrl: string | null = null;
    let durationSeconds: number | null = null;

    if (!skipTTS) {
      try {
        console.log('[Podcast] Generating TTS audio...');
        const audioBuffer = await textToSpeech(script, { persona });
        durationSeconds = estimateDuration(script);

        // Upload to Supabase storage
        const audioPath = `podcasts/${userId}/${episodeId}.mp3`;
        const { error: uploadError } = await supabaseAdmin.storage
          .from('podcast-audio')
          .upload(audioPath, audioBuffer, {
            contentType: 'audio/mpeg',
            upsert: true,
          });

        if (uploadError) {
          console.error('[Podcast] Audio upload failed:', uploadError);
        } else {
          const { data: publicUrl } = supabaseAdmin.storage
            .from('podcast-audio')
            .getPublicUrl(audioPath);
          audioUrl = publicUrl.publicUrl;
          console.log(`[Podcast] Audio uploaded: ${audioUrl}`);
        }
      } catch (ttsErr) {
        console.error('[Podcast] TTS failed (episode saved without audio):', ttsErr);
      }
    } else {
      durationSeconds = estimateDuration(script);
    }

    // Extract topics from outline segments
    const topicsCovered = outline.segments
      .map((s) => s.title)
      .filter(Boolean);

    // Update the episode record with final data
    const { data: finalEpisode, error: updateError } = await supabaseAdmin
      .from(Tables.PODCAST_EPISODES)
      .update({
        title: titleDesc.title,
        description: titleDesc.description,
        script,
        audio_url: audioUrl,
        duration_seconds: durationSeconds,
        mood: titleDesc.mood,
        status: 'ready',
        research_citations: allCitations,
        outline: outline as unknown as Record<string, unknown>,
        topics_covered: topicsCovered,
        metadata: {
          word_count: script.split(/\s+/).length,
          research_queries_count: allCitations.length,
          generation_passes: 3,
          voice_persona: persona,
          voice_name: personaConfig.displayName,
        },
      })
      .eq('id', episodeId)
      .select()
      .single();

    if (updateError) {
      throw new Error(`Failed to update episode: ${updateError.message}`);
    }

    console.log(`[Podcast] Episode "${titleDesc.title}" ready (${episodeId}).`);
    return finalEpisode as DbPodcastEpisode;
  } catch (err) {
    // Mark episode as failed
    await supabaseAdmin
      .from(Tables.PODCAST_EPISODES)
      .update({
        status: 'failed',
        error_message: err instanceof Error ? err.message : String(err),
      })
      .eq('id', episodeId);

    throw err;
  }
}

/**
 * List podcast episodes for a user.
 */
export async function listPodcastEpisodes(
  userId: string,
  limit = 20,
  offset = 0
): Promise<{ episodes: DbPodcastEpisode[]; total: number }> {
  const { data, error, count } = await supabaseAdmin
    .from(Tables.PODCAST_EPISODES)
    .select('*', { count: 'exact' })
    .eq('user_id', userId)
    .eq('status', 'ready')
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1);

  if (error) throw new Error(`Failed to list episodes: ${error.message}`);

  return {
    episodes: (data ?? []) as DbPodcastEpisode[],
    total: count ?? 0,
  };
}

/**
 * Get a single podcast episode with full details.
 */
export async function getPodcastEpisode(
  episodeId: string,
  userId: string
): Promise<DbPodcastEpisode | null> {
  const { data, error } = await supabaseAdmin
    .from(Tables.PODCAST_EPISODES)
    .select('*')
    .eq('id', episodeId)
    .eq('user_id', userId)
    .single();

  if (error) return null;
  return data as DbPodcastEpisode;
}

/**
 * Get the most recent episode for a user (used for continuity between episodes).
 */
export async function getLatestEpisode(userId: string): Promise<DbPodcastEpisode | null> {
  const { data } = await supabaseAdmin
    .from(Tables.PODCAST_EPISODES)
    .select('*')
    .eq('user_id', userId)
    .eq('status', 'ready')
    .order('created_at', { ascending: false })
    .limit(1)
    .single();

  return (data as DbPodcastEpisode) ?? null;
}
