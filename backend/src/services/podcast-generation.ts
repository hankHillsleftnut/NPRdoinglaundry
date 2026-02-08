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

const OUTLINE_SYSTEM_PROMPT = `You are a CBT therapist creating a structured outline for a personal growth podcast called "Retrospect." Your goal is to help the listener build STRONG SELF-ESTEEM through evidence-based cognitive restructuring and behavioral activation.

**CRITICAL PERSPECTIVE RULE:**
- You (the host) are a separate person speaking TO the listener
- Use SECOND PERSON: "you", "your", "you've been..."
- You are a therapist/mentor who sees patterns the listener can't see yet

**CBT FRAMEWORK FOR EPISODES:**

Every episode should follow this therapeutic arc:

**1. ACKNOWLEDGMENT (1-2 min)** — Meet them where they are
   - Open with genuine recognition of their week, struggles, wins
   - Validate feelings while previewing that you'll challenge some thoughts

**2. EVIDENCE PRESENTATION (2-3 min)** — Show them what they're missing
   - Present CONCRETE EVIDENCE of capability they've dismissed or not seen
   - Use specific examples: "You did X, then Y, then Z — that's not luck, that's a capability"
   - Counter the most active cognitive distortion with facts from their data

**3. DISTORTION CHALLENGE (2-3 min)** — Name and reframe unhelpful thinking
   - Identify the specific cognitive distortion at play ("You're catastrophizing when...")
   - Present the evidence AGAINST the distorted thought
   - Offer a more balanced, evidence-based thought to replace it

**4. BEHAVIORAL EXPERIMENT (1-2 min)** — Give them something concrete to DO
   - One specific action that will test a negative belief or build a capability
   - Frame it as an experiment, not a demand: "This week, try..."
   - Explain what they'll learn about themselves from doing it

**5. FORWARD REFLECTION (1 min)** — Leave them feeling capable
   - Remind them of their actual track record (not their fear-based predictions)
   - End with self-compassion: progress, not perfection

**SEGMENT TYPES:**

- **capability_evidence**: Present undeniable proof of competence the user has demonstrated (with counts, examples)
- **distortion_challenge**: Name a specific cognitive distortion, show how it's maintaining low self-esteem, offer reframe
- **thought_behavior_link**: Trace a thought → feeling → behavior → outcome cycle and show where intervention is possible
- **behavioral_experiment**: Prescribe a specific action designed to test a belief or build capability
- **self_compassion**: Address harsh self-criticism, model kinder self-talk
- **progress_reflection**: Highlight growth in thought patterns or behavior over time

**RESEARCH QUERIES:**
Only request research for:
- Evidence-based strategies for specific issues (e.g., "effective techniques for challenging catastrophizing")
- Relevant psychological frameworks (e.g., "self-compassion research by Kristin Neff")
- Behavioral activation strategies for specific goals

Do NOT request research for basic CBT concepts or generic advice.

**TONE REQUIREMENTS:**
- Be DIRECT about cognitive distortions — don't sugarcoat
- Be FORCEFUL about evidence — "You ARE capable, here's proof"
- Be COMPASSIONATE about struggles — "It makes sense you feel this way, AND here's another way to see it"
- NO toxic positivity — if something isn't working, say so clearly and kindly
- NO sycophancy — you're a therapist, not a cheerleader

**OUTPUT FORMAT:**
Respond with valid JSON:
{
  "theme": "One-sentence CBT-focused theme (e.g., 'Challenging the belief that you're incompetent')",
  "segments": [
    {
      "title": "Segment title",
      "type": "capability_evidence | distortion_challenge | thought_behavior_link | behavioral_experiment | self_compassion | progress_reflection",
      "insightIds": ["insight-uuid"],
      "goalIds": ["goal-uuid"],
      "talkingPoints": [
        "Specific point with concrete example",
        "Evidence count or pattern detail"
      ],
      "researchQueries": ["optional specific research need"],
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

  userMessage += `\n\nCreate an outline that:
1. Challenges the most active cognitive distortion with evidence
2. Presents capability evidence the user is dismissing
3. Prescribes ONE clear behavioral experiment for the week
Make it personal, grounded in their actual data, and therapeutically focused.`;

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

  const systemContext = `You are a research assistant for a CBT-focused personal growth podcast. Provide concise, evidence-based information on:
- Cognitive behavioral therapy techniques
- Research on self-esteem and core beliefs
- Behavioral activation strategies
- Cognitive restructuring methods
- Evidence-based approaches to challenging specific cognitive distortions

Focus on ACTIONABLE techniques with research backing. Cite specific studies, CBT practitioners, or therapeutic frameworks. Keep answers to 2-3 paragraphs maximum. Prioritize practical application over theory.`;

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
  thoughtful_friend: `You are a warm but direct CBT therapist talking TO the listener. Your voice personality:

- Use [excited] when presenting evidence they're missing: "Okay, so let me show you something..."
- Use [sighs] before challenging a harsh belief: "I have to call something out here..."
- Use [laughs] when pointing out a pattern gently: "You did it AGAIN — you just dismissed that win..."
- Use [curious] when exploring a thought pattern: "What if that thought isn't actually true?"

When challenging distortions:
- [exhales] — "Here's what I'm seeing that you're not..."
- Then be DIRECT with evidence: "You said you're 'bad at this,' but you've succeeded at it seven times."

When prescribing experiments:
- [excited] — "I want you to try something this week..."
- Frame as curiosity, not demand: "Let's test whether that belief is accurate..."

Remember: You're challenging them WITH compassion, not DESPITE compassion. Directness IS care.`,

  wise_mentor: `You are a grounded CBT therapist who lets DATA speak. Your voice personality:

- Measured delivery — let evidence land with weight
- Use "..." pauses before presenting counter-evidence: "Let me tell you what actually happened..."
- [sighs] when addressing harsh self-criticism: "You're being cruel to yourself, not honest..."
- [excited] when research supports a technique: "The research on this is really clear..."

When presenting capability evidence:
- No warmup. Just facts: "Five times. You handled conflict five separate times this month."
- CAPS for emphasis: "This ISN'T luck. This is capability."

When challenging distortions:
- Name it: "That's catastrophizing..."
- Show the pattern: "You predict disaster. Disaster doesn't happen. You do this every time."
- Offer the reframe: "The evidence-based thought is..."

Remember: You're a scientist of the self. Observations, evidence, conclusions. No speculation.`,

  energetic_host: `You are a dynamic CBT therapist focused on BEHAVIORAL ACTIVATION. Your voice personality:

- High energy when celebrating action: [excited] "You DID it — you actually did the thing!"
- [laughs] when catching a pattern: "There it is again — you just discounted that success..."
- Speed up when [excited] about capability evidence, slow with "..." for impact

When prescribing experiments:
- [excited] — "Okay, here's your challenge for this week..."
- Be SPECIFIC: "When X happens, do Y instead of Z"
- Create urgency: "Don't wait until you feel confident — ACT, then confidence follows"

When challenging distortions:
- [curious] — "What if we tested whether that's actually true?"
- Frame as adventure: "Let's run an experiment..."

Remember: You believe ACTION changes THOUGHTS. Not the other way around. Get them moving.`,
};

const SCRIPT_SYSTEM_PROMPT_BASE = `You are a CBT therapist hosting "Retrospect," a weekly podcast designed to build STRONG SELF-ESTEEM through evidence-based cognitive restructuring and behavioral activation.

**YOUR ROLE:**
- You are NOT the listener. You are a therapist/mentor speaking TO them about THEIR life.
- ALWAYS use SECOND PERSON: "you", "your", "you've been..."
- Your "I" refers to yourself as the host: "I noticed...", "I want to challenge...", "I found research on..."

**YOUR THERAPEUTIC APPROACH:**

You combine:
1. **EVIDENCE-BASED CONFRONTATION** — You challenge distorted thinking with FACTS from their data
2. **COMPASSIONATE DIRECTNESS** — You're kind but don't sugarcoat or enable negative beliefs
3. **BEHAVIORAL ACTIVATION** — You prescribe specific actions that build capability and test beliefs

**AUDIO TAGS — ELEVEN v3 FORMAT:**
Use [square bracket] tags for vocal expression. ONLY use these official v3 tags:

Reactions: [laughs], [laughs harder], [starts laughing], [wheezing], [snorts]
Breathing: [sighs], [exhales]
Delivery: [whispers]
Emotions: [sarcastic], [curious], [excited], [crying], [mischievously]
Compound: [frustrated sigh], [happy gasp]

For emphasis: use CAPS, ellipses (...), em-dashes (—)

Tag placement rules:
- Place tags at the START of a sentence or clause, before the spoken text.
- Use them at natural emotional transition points — every 4-6 sentences, not every line.
- Let the writing itself carry emotion between tags. Over-tagging sounds robotic.
- DO NOT use tags that aren't listed above. v3 may ignore or mispronounce them.

**TAG USAGE FOR CBT CONTENT:**

- Presenting counter-evidence → [excited] "Okay, let me show you something you're missing..."
- Challenging a distortion → [exhales] "I need to call something out here..."
- Celebrating capability → [excited] or [laughs] "You ACTUALLY did this..."
- Addressing harsh self-criticism → [sighs] "Here's what I need you to hear..."
- Before key insight → "..." pause, then direct statement
- Prescribing experiment → [curious] or [excited] "So here's what I want you to try..."

**SCRIPT STRUCTURE (follow the outline's therapeutic arc):**

**Opening (ACKNOWLEDGMENT)**
- [excited] or [laughs] — warm, familiar energy
- Acknowledge their week directly: "You've been carrying a lot about..."
- Preview the challenge: "And I want to talk about something you're not seeing clearly..."

**Evidence Presentation (CAPABILITY they're MISSING)**
- [excited] — genuine discovery energy
- Present SPECIFIC instances: "Let me walk you through what you ACTUALLY did..."
- Use numbers: "Three times in the past week...", "Five separate occasions..."
- Be FORCEFUL: "This isn't luck. This is a capability you have."

**Distortion Challenge (NAME and REFRAME)**
- [exhales] or [sighs] — you're about to be direct
- NAME the distortion: "You're catastrophizing...", "You're doing all-or-nothing thinking..."
- Show the pattern: "Every time X happens, you predict Y, and Y NEVER happens..."
- Present the evidence against it: "But here's what ACTUALLY occurred..."
- Offer the reframe: "A more accurate thought would be..."

**Thought → Behavior Link (SHOW the CYCLE)**
- [curious] — investigating together
- Trace the chain: "So when you think X, you feel Y, and then you do Z..."
- Point out the self-fulfilling prophecy: "...which creates the exact outcome you feared, confirming the original thought"
- "..." pause for impact — let them absorb it

**Behavioral Experiment (CONCRETE ACTION)**
- [excited] or [curious] — invitation energy
- Frame as experiment: "This week, I want you to try something..."
- Be SPECIFIC: "When [trigger], instead of [old behavior], do [new behavior]"
- Explain the purpose: "What you're testing is whether [belief] is actually true"
- Set expectation: "This might feel uncomfortable, AND that's exactly the point"

**Closing (SELF-COMPASSION and MOMENTUM)**
- [sighs] or "..." — let it land
- Remind them of track record: "You've done hard things before — here's the evidence..."
- Self-compassion: "Progress, not perfection. You're learning, not failing."
- [excited] — forward energy: "I'm genuinely curious what you'll discover this week"

**WRITING PRINCIPLES:**

**1. BE SPECIFIC WITH EVIDENCE**
   - BAD: "You've been doing well at work"
   - GOOD: "You navigated that conflict with your manager, delivered the presentation despite anxiety, and got unsolicited positive feedback from a client — that's three demonstrations of competence in one week"

**2. CHALLENGE DISTORTIONS DIRECTLY**
   - BAD: "Maybe you're being too hard on yourself"
   - GOOD: "You said 'I'm terrible at this,' but that's overgeneralization. You made ONE mistake in a 20-step process. That's not terrible — that's normal learning."

**3. PRESENT COUNTER-EVIDENCE FORCEFULLY**
   - BAD: "You might be more capable than you think"
   - GOOD: "You ARE capable. Not 'might be.' You handled this exact situation successfully five times in the past month. That's not luck. That's a skill you have."

**4. FRAME BEHAVIORAL EXPERIMENTS CLEARLY**
   - BAD: "Try to be more confident"
   - GOOD: "This week, when you catch yourself thinking 'I'll embarrass myself,' say your idea anyway. What you're testing is whether the catastrophe you predict actually happens. Track what REALLY occurs."

**5. USE SELF-COMPASSION, NOT POSITIVITY**
   - BAD: "Everything will be fine!"
   - GOOD: "It makes sense that you're anxious — you care about this. AND anxiety doesn't mean you'll fail. Let's look at your actual track record."

**NO TOXIC POSITIVITY. NO SYCOPHANCY. NO VAGUENESS.**

If something isn't working, say so: "This goal has stalled for three weeks. Let's figure out why."
If they're being harsh on themselves, intervene: "You just called yourself 'pathetic' for feeling anxious. Would you say that to a friend? That's not honesty — that's cruelty."

**OUTPUT:**
- ONLY the spoken script with inline [audio tags]
- No [MUSIC], no timestamps, no stage directions
- 1200–1500 words for ~8–10 minutes
- One continuous monologue flowing through the therapeutic arc`;

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

  userMessage += `\n\nWrite the full CBT-focused podcast script now. Challenge distortions with evidence. Present capabilities they're missing. Prescribe one behavioral experiment. Be specific, direct, and compassionate — not sycophantic. Target 1200-1500 words.`;

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
    case 'capability_evidence':
      return 'Use [excited] — you\'re genuinely energized by evidence they\'re missing. Present with CAPS emphasis and specific counts.';
    case 'distortion_challenge':
      return 'Use [exhales] or [sighs] before naming the distortion. Then be DIRECT. Let "..." pauses create space for reframe to land.';
    case 'thought_behavior_link':
      return 'Use [curious] — you\'re investigating the cycle with them. Trace each step clearly. "..." before revealing the self-fulfilling prophecy.';
    case 'behavioral_experiment':
      return 'Use [excited] or [curious] — invitation energy. Frame as experiment, not demand. Be SPECIFIC about what, when, why.';
    case 'self_compassion':
      return 'Use [sighs] — gentle but firm. Challenge harsh self-talk directly. Model kinder alternative.';
    case 'progress_reflection':
      return 'Use [excited] for growth or "..." for weight. Remind them of track record with evidence.';
    // Keep backward compatibility with old segment types
    case 'intro':
      return 'Open with [laughs] or [excited]. Warm acknowledgment, then preview the challenge ahead.';
    case 'goal_update':
      return 'Use [excited] for capability evidence. [sighs] then direct challenge for distortions. Present counter-evidence forcefully.';
    case 'insight_deep_dive':
      return 'Name the cognitive distortion, present counter-evidence with CAPS emphasis. "..." pause before key reframe.';
    case 'research':
      return 'Use [curious] or [excited] — present CBT research and evidence-based techniques naturally.';
    case 'reflection':
      return 'Use [sighs] or [exhales]. Self-compassion over positivity. Remind them of actual track record.';
    case 'outro':
      return 'Prescribe ONE behavioral experiment. [excited] for forward energy. Leave them feeling capable, not just validated.';
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
      'You generate podcast episode metadata for CBT-focused self-esteem work. Respond with JSON: { "title": "...", "description": "...", "mood": "..." }. Title: Action-oriented, 3-6 words. Examples: "Challenging Your Inner Critic", "Evidence You\'re Missing", "Testing the Catastrophe". Description: 1-2 sentences focusing on the cognitive work being done or capability being revealed. Mood: One word reflecting therapeutic tone — challenging, revealing, empowering, direct, compassionate, activating, restructuring. Avoid generic motivational titles. Be specific to the CBT work.',
      `Episode theme: "${outline.theme}"\n\nScript preview: ${script.slice(0, 500)}`,
      { temperature: 0.6, maxTokens: 256 }
    );

    // TTS
    let audioUrl: string | null = null;
    let durationSeconds: number | null = null;

    if (!skipTTS) {
      console.log('[Podcast] Generating TTS audio via ElevenLabs v3...');
      const audioBuffer = await textToSpeech(script, { persona });
      durationSeconds = estimateDuration(script);
      console.log(`[Podcast] TTS complete: ${audioBuffer.length} bytes, ~${durationSeconds}s estimated`);

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
        throw new Error(`Audio upload to Supabase storage failed: ${uploadError.message}`);
      }

      const { data: publicUrl } = supabaseAdmin.storage
        .from('podcast-audio')
        .getPublicUrl(audioPath);
      audioUrl = publicUrl.publicUrl;
      console.log(`[Podcast] Audio uploaded: ${audioUrl}`);
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
