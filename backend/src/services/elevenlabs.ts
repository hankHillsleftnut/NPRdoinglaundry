/**
 * ElevenLabs TTS Service — Eleven v3
 *
 * Uses eleven_v3, the most expressive model with native audio tag support.
 *
 * v3 CRITICAL CONSTRAINTS (differs from v2):
 *   - Stability: MUST be exactly 0.0 (Creative), 0.5 (Natural), or 1.0 (Robust)
 *   - No SSML break tags — use audio tags, ellipses (…), and CAPS for expression
 *   - No previous_request_ids, previous_text, or next_text (v2-only)
 *   - 5,000 char limit per request (we use 4,800 as buffer)
 *   - Audio tags rendered natively: [laughs], [whispers], [sighs], [excited], etc.
 *   - Higher latency than v2 — perfect for pre-generated podcasts
 *
 * Official v3 audio tags (from ElevenLabs docs):
 *   Voice: [laughs], [laughs harder], [starts laughing], [wheezing],
 *          [whispers], [sighs], [exhales], [sarcastic], [curious],
 *          [excited], [crying], [snorts], [mischievously]
 *   Effects: [applause], [clapping]
 *   Special: [strong X accent], [sings]
 *   Compound: [frustrated sigh], [happy gasp], etc. (adjective + action)
 *
 * Voice Personas:
 *   1. Thoughtful Friend — Creative (0.0), warm, expressive
 *   2. Wise Mentor — Natural (0.5), grounded, balanced
 *   3. Energetic Host — Creative (0.0), dynamic, maximum expression
 */

import { config } from '../utils/config.js';

// ============================================
// VOICE PERSONAS (v3-compatible)
// ============================================

export type VoicePersona = 'thoughtful_friend' | 'wise_mentor' | 'energetic_host';

/**
 * v3 stability is discrete:
 *   0.0 = Creative (most expressive, responds best to audio tags, may hallucinate)
 *   0.5 = Natural (balanced, closest to original voice)
 *   1.0 = Robust (most stable, least responsive to tags, similar to v2)
 */
type V3Stability = 0.0 | 0.5 | 1.0;

export interface PersonaConfig {
  id: VoicePersona;
  displayName: string;
  description: string;
  voiceId: string;       // ElevenLabs voice ID
  stability: V3Stability; // v3 discrete stability setting
}

export const VOICE_PERSONAS: Record<VoicePersona, PersonaConfig> = {
  thoughtful_friend: {
    id: 'thoughtful_friend',
    displayName: 'Thoughtful Friend',
    description: 'Warm and conversational, like catching up over coffee. Natural laughs, vocal warmth, genuine engagement.',
    voiceId: '21m00Tcm4TlvDq8ikWAM', // Rachel — warm, conversational
    stability: 0.0, // Creative — maximum expressiveness for warmth and natural emotion
  },
  wise_mentor: {
    id: 'wise_mentor',
    displayName: 'Wise Mentor',
    description: 'Calm and grounded with gravitas. Lets insights land. Measured pacing with purposeful emphasis.',
    voiceId: 'pNInz6obpgDQGcFmaJgB', // Adam — calm, grounded
    stability: 0.5, // Natural — balanced delivery, grounded but still responsive to tags
  },
  energetic_host: {
    id: 'energetic_host',
    displayName: 'Energetic Host',
    description: 'Dynamic and engaging. Varied pacing, genuinely curious tone, celebrates wins audibly.',
    voiceId: 'ErXwobaYiN019PkySvjV', // Antoni — dynamic, engaging
    stability: 0.0, // Creative — maximum expressiveness for dynamic, varied delivery
  },
};

/**
 * Get the persona config for a given persona ID. Falls back to thoughtful_friend.
 */
export function getPersonaConfig(persona?: string): PersonaConfig {
  if (persona && persona in VOICE_PERSONAS) {
    return VOICE_PERSONAS[persona as VoicePersona];
  }
  return VOICE_PERSONAS.thoughtful_friend;
}

// ============================================
// TEXT CHUNKING
// ============================================

/**
 * Split text into chunks that fit within v3's 5,000 character limit.
 * Splits at sentence boundaries to maintain natural speech flow.
 * We use 4,800 chars as the max to leave buffer.
 */
function chunkText(text: string, maxChars: number): string[] {
  if (text.length <= maxChars) {
    return [text];
  }

  const chunks: string[] = [];
  let remaining = text;

  while (remaining.length > 0) {
    if (remaining.length <= maxChars) {
      chunks.push(remaining);
      break;
    }

    // Find the best split point: end of sentence within maxChars
    let splitAt = maxChars;

    // Try splitting at sentence endings (. ! ?) followed by space or newline
    const searchRegion = remaining.slice(0, maxChars);
    const sentenceEndPattern = /[.!?]\s/g;
    let lastSentenceEnd = -1;
    let match: RegExpExecArray | null;

    while ((match = sentenceEndPattern.exec(searchRegion)) !== null) {
      lastSentenceEnd = match.index + 1; // Include the punctuation
    }

    if (lastSentenceEnd > maxChars * 0.5) {
      // Found a good sentence boundary in the latter half
      splitAt = lastSentenceEnd;
    } else {
      // Fallback: split at last space
      const lastSpace = searchRegion.lastIndexOf(' ');
      if (lastSpace > maxChars * 0.3) {
        splitAt = lastSpace;
      }
    }

    chunks.push(remaining.slice(0, splitAt).trim());
    remaining = remaining.slice(splitAt).trim();
  }

  return chunks;
}

// ============================================
// TEXT-TO-SPEECH (v3)
// ============================================

interface TTSOptions {
  persona?: VoicePersona | string;
  voiceId?: string;   // Override persona's voice
  modelId?: string;
}

/**
 * Generate speech for a single chunk via the ElevenLabs v3 API.
 *
 * v3 voice_settings only uses `stability` (0.0 | 0.5 | 1.0).
 * Other v2 params (similarity_boost, style, use_speaker_boost) are NOT sent
 * to avoid potential validation errors with v3.
 */
async function generateChunk(
  text: string,
  voiceId: string,
  modelId: string,
  stability: V3Stability,
): Promise<Buffer> {
  const body: Record<string, unknown> = {
    text,
    model_id: modelId,
    voice_settings: {
      stability,
    },
  };

  // v3 is higher latency — allow up to 120s per chunk
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 120_000);

  let response: Response;
  try {
    response = await fetch(
      `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'xi-api-key': config.elevenlabs.apiKey,
          'Accept': 'audio/mpeg',
        },
        body: JSON.stringify(body),
        signal: controller.signal,
      }
    );
  } catch (err: unknown) {
    clearTimeout(timeout);
    if (err instanceof Error && err.name === 'AbortError') {
      throw new Error('ElevenLabs v3 request timed out after 120s');
    }
    throw err;
  }
  clearTimeout(timeout);

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`ElevenLabs API error (${response.status}): ${errorText}`);
  }

  const arrayBuffer = await response.arrayBuffer();
  return Buffer.from(arrayBuffer);
}

/**
 * Generate speech audio from a script using Eleven v3.
 *
 * For scripts under 4,800 chars: single API call.
 * For longer scripts: chunks the text at sentence boundaries, generates
 * each chunk independently, and concatenates the resulting MP3 buffers.
 *
 * v3 does NOT support request stitching (previous_request_ids / next_text).
 * Sentence-boundary splitting keeps transitions natural.
 *
 * Returns raw audio bytes (mp3 format).
 */
export async function textToSpeech(
  text: string,
  options: TTSOptions = {}
): Promise<Buffer> {
  if (!config.elevenlabs.apiKey) {
    throw new Error('ElevenLabs API key not configured');
  }

  const persona = getPersonaConfig(options.persona);
  const voiceId = options.voiceId ?? persona.voiceId;
  const modelId = options.modelId ?? config.elevenlabs.model;
  const maxChars = config.elevenlabs.maxCharsPerRequest;

  const chunks = chunkText(text, maxChars);

  console.log(`[ElevenLabs v3] Generating with persona "${persona.displayName}" (voice: ${voiceId}, model: ${modelId}, stability: ${persona.stability}, chunks: ${chunks.length}, total chars: ${text.length})`);

  if (chunks.length === 1) {
    const audio = await generateChunk(chunks[0]!, voiceId, modelId, persona.stability);
    console.log(`[ElevenLabs v3] Single-chunk generation complete (${audio.length} bytes).`);
    return audio;
  }

  // Multi-chunk: generate each independently and concatenate
  const audioBuffers: Buffer[] = [];

  for (let i = 0; i < chunks.length; i++) {
    const chunk = chunks[i]!;
    console.log(`[ElevenLabs v3] Generating chunk ${i + 1}/${chunks.length} (${chunk.length} chars)...`);

    const audio = await generateChunk(chunk, voiceId, modelId, persona.stability);
    audioBuffers.push(audio);

    console.log(`[ElevenLabs v3] Chunk ${i + 1} complete (${audio.length} bytes).`);
  }

  console.log(`[ElevenLabs v3] All ${chunks.length} chunks generated. Concatenating audio...`);
  return Buffer.concat(audioBuffers);
}

/**
 * Estimate the duration of speech for given text.
 * Strips audio tags before counting words.
 * ~150 words per minute for natural speech.
 */
export function estimateDuration(text: string): number {
  // Strip inline audio tags like [laughs], [excited], etc.
  const cleaned = text.replace(/\[.*?\]/g, '');
  const wordCount = cleaned.split(/\s+/).filter(Boolean).length;
  return Math.round((wordCount / 150) * 60); // seconds
}
