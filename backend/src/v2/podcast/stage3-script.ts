/**
 * Stage 3 — production-manager script generator.
 *
 * Single Claude call (no tools). Input: Stage 1 current-context outline, Stage 2
 * historical outline, and user_preferences. Output: the FULL spoken script with
 * inline ElevenLabs v3 audio tags. This is the "production manager" step — it
 * may drop outline items, reorder them, consolidate, and enforces the
 * almost-but-not-quite heuristic + non-repetition rules.
 */

import { chatCompletion } from '../../utils/openai.js';
import { STAGE3_SCRIPT_SYSTEM } from './prompts.js';
import type { CurrentContextOutline } from './stage1-current-context.js';
import type { UserPreferences } from './user-preferences.js';

export interface Stage3Input {
  userId: string;
  currentContextOutline: CurrentContextOutline;
  historicalOutline: string;
  preferences: UserPreferences | null;
  targetWordCount?: { min: number; max: number };
}

export interface Stage3Output {
  script: string;
  wordCount: number;
}

export async function runStage3(input: Stage3Input): Promise<Stage3Output> {
  const { min = 1200, max = 1500 } = input.targetWordCount ?? {};

  const userMessage = buildUserMessage(input, min, max);

  console.log(
    `[v2:stage3] generating script for user=${input.userId} (target ${min}-${max} words)`
  );

  const script = await chatCompletion(STAGE3_SCRIPT_SYSTEM, userMessage, {
    temperature: 0.75,
    maxTokens: 8192,
  });

  const cleaned = stripAccidentalFences(script);
  const wordCount = cleaned.split(/\s+/).filter(Boolean).length;

  console.log(`[v2:stage3] script generated — ${wordCount} words`);

  return { script: cleaned, wordCount };
}

function buildUserMessage(input: Stage3Input, min: number, max: number): string {
  const prefs = input.preferences;
  const prefJson = prefs
    ? JSON.stringify(
        {
          tone: prefs.tone,
          trusted_voice_description: prefs.trusted_voice_description,
          pacing: prefs.pacing,
          focus_areas: prefs.focus_areas,
          avoid_topics: prefs.avoid_topics,
          last_podcast_feedback: prefs.last_podcast_feedback,
        },
        null,
        2
      )
    : '{}';

  return `## CURRENT-CONTEXT OUTLINE (Stage 1 — last ~2 weeks)
${JSON.stringify(input.currentContextOutline, null, 2)}

## HISTORICAL OUTLINE (Stage 2 — older threads, callbacks, setup for realization)
${input.historicalOutline}

## USER PREFERENCES
${prefJson}

Write the full episode script now.

You are the production manager — drop, reorder, and consolidate as needed. Honor the non-repetition notes from the historical outline. Lead the first ~150 words with a specific "I see you" detail. Stop one beat short of every realization: lay the pieces, then step back. Target ${min}–${max} words. Plain text, no headings, no timestamps, inline ElevenLabs v3 audio tags only.`;
}

function stripAccidentalFences(text: string): string {
  let t = text.trim();
  if (t.startsWith('```')) {
    const firstNewline = t.indexOf('\n');
    if (firstNewline > -1) t = t.slice(firstNewline + 1);
  }
  if (t.endsWith('```')) {
    t = t.slice(0, -3);
  }
  return t.trim();
}
