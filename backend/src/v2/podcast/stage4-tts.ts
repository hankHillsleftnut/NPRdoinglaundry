/**
 * Stage 4 — TTS + storage + continuity summary.
 *
 * Given the Stage 3 script:
 *   1. ElevenLabs v3 TTS (chunked by existing service) to MP3 buffer.
 *   2. Upload to Supabase Storage bucket `podcast-audio` at podcasts/{userId}/{episodeId}.mp3.
 *   3. Generate the 2-paragraph continuity summary (Claude).
 *   4. Embed the summary with OpenAI.
 *   5. Generate title / description / mood metadata (Claude JSON).
 *   6. Upsert the podcast_episodes row with all of the above.
 *
 * This closes the loop: future Stage 2 agents call search_previous_podcasts and
 * retrieve this summary for non-repetition and continuity callbacks.
 */

import { supabaseAdmin, Tables } from '../../utils/supabase.js';
import { chatCompletion, jsonChatCompletion, generateEmbedding } from '../../utils/openai.js';
import {
  textToSpeech,
  estimateDuration,
  getPersonaConfig,
  VOICE_PERSONAS,
  type VoicePersona,
} from '../../services/elevenlabs.js';
import { STAGE4_EPISODE_SUMMARY_SYSTEM, STAGE4_METADATA_SYSTEM } from './prompts.js';
import type { ToolTraceEvent } from '../agent-runtime/types.js';
import type { DbPodcastEpisode } from '../../types/index.js';

export interface Stage4Input {
  userId: string;
  script: string;
  episodeId: string;
  previousEpisodeId?: string | null;
  persona?: VoicePersona;
  skipTTS?: boolean;
  /** Extras persisted to metadata for debugging. */
  stage2ToolCalls?: ToolTraceEvent[];
  stage2StopReason?: string;
}

export interface Stage4Output {
  episode: DbPodcastEpisode;
  audioUrl: string | null;
  summary: string;
  title: string;
  description: string;
  mood: string;
}

export async function runStage4(input: Stage4Input): Promise<Stage4Output> {
  const persona = resolvePersona(input.persona);
  const personaConfig = getPersonaConfig(persona);

  console.log(
    `[v2:stage4] starting for episode=${input.episodeId} persona=${personaConfig.displayName} skipTTS=${!!input.skipTTS}`
  );

  // ============================================
  // 1. TTS (optional)
  // ============================================
  let audioUrl: string | null = null;
  let durationSeconds: number | null = null;

  if (!input.skipTTS) {
    console.log('[v2:stage4] generating TTS...');
    const audioBuffer = await textToSpeech(input.script, { persona });
    durationSeconds = estimateDuration(input.script);

    const audioPath = `podcasts/${input.userId}/${input.episodeId}.mp3`;
    const { error: uploadError } = await supabaseAdmin.storage
      .from('podcast-audio')
      .upload(audioPath, audioBuffer, {
        contentType: 'audio/mpeg',
        upsert: true,
      });

    if (uploadError) {
      throw new Error(`Stage 4 audio upload failed: ${uploadError.message}`);
    }

    const { data: publicUrl } = supabaseAdmin.storage
      .from('podcast-audio')
      .getPublicUrl(audioPath);
    audioUrl = publicUrl.publicUrl;
    console.log(`[v2:stage4] audio uploaded: ${audioBuffer.length} bytes -> ${audioUrl}`);
  } else {
    durationSeconds = estimateDuration(input.script);
  }

  // ============================================
  // 2. Summary (2 paragraphs) + embedding
  // ============================================
  console.log('[v2:stage4] generating continuity summary...');
  const summary = await chatCompletion(
    STAGE4_EPISODE_SUMMARY_SYSTEM,
    `Full episode script:\n\n${input.script}`,
    { temperature: 0.4, maxTokens: 700 }
  );

  let summaryEmbedding: number[] | null = null;
  try {
    summaryEmbedding = await generateEmbedding(summary);
  } catch (err) {
    console.warn('[v2:stage4] summary embedding failed (non-fatal):', err);
  }

  // ============================================
  // 3. Metadata (title / description / mood)
  // ============================================
  console.log('[v2:stage4] generating metadata...');
  const meta = await jsonChatCompletion<{ title: string; description: string; mood: string }>(
    STAGE4_METADATA_SYSTEM,
    `Episode script preview:\n\n${input.script.slice(0, 800)}\n\nSummary:\n${summary}`,
    { temperature: 0.5, maxTokens: 256 }
  );

  // ============================================
  // 4. Update episode row
  // ============================================
  const wordCount = input.script.split(/\s+/).filter(Boolean).length;

  const updatePayload: Record<string, unknown> = {
    title: meta.title,
    description: meta.description,
    mood: meta.mood,
    script: input.script,
    audio_url: audioUrl,
    duration_seconds: durationSeconds,
    summary,
    summary_embedding: summaryEmbedding,
    status: 'ready',
    previous_episode_id: input.previousEpisodeId ?? null,
    metadata: {
      pipeline_version: 'v2',
      word_count: wordCount,
      voice_persona: persona,
      voice_name: personaConfig.displayName,
      stage2_tool_calls: input.stage2ToolCalls?.length ?? 0,
      stage2_stop_reason: input.stage2StopReason ?? null,
    },
  };

  const { data, error } = await supabaseAdmin
    .from(Tables.PODCAST_EPISODES)
    .update(updatePayload)
    .eq('id', input.episodeId)
    .select('*')
    .single();

  if (error || !data) {
    throw new Error(`Stage 4 episode update failed: ${error?.message ?? 'no data returned'}`);
  }

  console.log(
    `[v2:stage4] episode ready — "${meta.title}" (${wordCount} words, ${durationSeconds}s estimated)`
  );

  return {
    episode: data as DbPodcastEpisode,
    audioUrl,
    summary,
    title: meta.title,
    description: meta.description,
    mood: meta.mood,
  };
}

function resolvePersona(override?: VoicePersona): VoicePersona {
  if (override && override in VOICE_PERSONAS) return override;
  return 'thoughtful_friend';
}
