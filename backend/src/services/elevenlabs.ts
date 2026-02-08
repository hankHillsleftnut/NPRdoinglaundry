/**
 * ElevenLabs TTS Service — Eleven v3
 *
 * Uses eleven_v3, the most expressive model with native audio tag support.
 * v3 understands inline tags like [laughs], [sighs], [whispers], [excited],
 * [sad], [angry], etc. and renders them as natural vocal expressions.
 *
 * Key v3 details:
 *   - 5,000 char limit per request (we use 4,800 as buffer)
 *   - Scripts over 4,800 chars are chunked independently and concatenated
 *   - NOTE: v3 does NOT support previous_request_ids or next_text (v2-only)
 *   - voice_settings still supported (stability, similarity_boost, style)
 *   - Higher latency than v2 — not for real-time, perfect for pre-generated podcasts
 *
 * Voice Personas:
 *   1. Thoughtful Friend — warm, conversational, natural rhythm
 *   2. Wise Mentor — calm, grounded, measured delivery
 *   3. Energetic Host — dynamic pacing, genuinely curious
 */

import { config } from '../utils/config.js';

// ============================================
// VOICE PERSONAS
// ============================================

export type VoicePersona = 'thoughtful_friend' | 'wise_mentor' | 'energetic_host';

export interface PersonaConfig {
  id: VoicePersona;
  displayName: string;
  description: string;
  voiceId: string;        // ElevenLabs voice ID
  stability: number;      // 0–1: lower = more expressive, higher = more consistent
  similarityBoost: number; // 0–1: higher = closer to original voice
  style: number;          // 0–1: higher = more stylistic variation (expressiveness)
  speakerBoost: boolean;
}

export const VOICE_PERSONAS: Record<VoicePersona, PersonaConfig> = {
  thoughtful_friend: {
    id: 'thoughtful_friend',
    displayName: 'Thoughtful Friend',
    description: 'Warm and conversational, like catching up over coffee. Natural laughs, vocal warmth, genuine engagement.',
    voiceId: '21m00Tcm4TlvDq8ikWAM', // Rachel — warm, conversational
    stability: 0.35,       // Lower stability = more expressive variation
    similarityBoost: 0.70,
    style: 0.65,           // High style = more emotional range
    speakerBoost: true,
  },
  wise_mentor: {
    id: 'wise_mentor',
    displayName: 'Wise Mentor',
    description: 'Calm and grounded with gravitas. Lets insights land. Measured pacing with purposeful emphasis.',
    voiceId: 'pNInz6obpgDQGcFmaJgB', // Adam — calm, grounded
    stability: 0.50,       // Moderate stability for consistent gravitas
    similarityBoost: 0.80,
    style: 0.45,           // Moderate style — expressive but controlled
    speakerBoost: true,
  },
  energetic_host: {
    id: 'energetic_host',
    displayName: 'Energetic Host',
    description: 'Dynamic and engaging. Varied pacing, genuinely curious tone, celebrates wins audibly.',
    voiceId: 'ErXwobaYiN019PkySvjV', // Antoni — dynamic, engaging
    stability: 0.28,       // Low stability = maximum expressiveness
    similarityBoost: 0.65,
    style: 0.80,           // Very high style = full emotional range
    speakerBoost: true,
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
 * Split text into chunks that fit within v3's character limit.
 * Splits at sentence boundaries to maintain natural speech flow.
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
 * Generate speech for a single chunk via the ElevenLabs API.
 * v3 does NOT support previous_request_ids or next_text — each chunk is independent.
 */
async function generateChunk(
  text: string,
  voiceId: string,
  modelId: string,
  persona: PersonaConfig,
): Promise<Buffer> {
  const body: Record<string, unknown> = {
    text,
    model_id: modelId,
    voice_settings: {
      stability: persona.stability,
      similarity_boost: persona.similarityBoost,
      style: persona.style,
      use_speaker_boost: persona.speakerBoost,
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
 * Generate speech audio from an emotion-annotated script using Eleven v3.
 *
 * For scripts under 4,800 chars: single API call.
 * For longer scripts: chunks the text at sentence boundaries, generates
 * each chunk independently, and concatenates the resulting MP3 buffers.
 *
 * NOTE: v3 does not support request stitching (previous_request_ids / next_text).
 * We split at sentence boundaries to keep transitions natural.
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

  console.log(`[ElevenLabs v3] Generating with persona "${persona.displayName}" (voice: ${voiceId}, model: ${modelId}, chunks: ${chunks.length}, total chars: ${text.length})`);

  if (chunks.length === 1) {
    const audio = await generateChunk(chunks[0]!, voiceId, modelId, persona);
    console.log(`[ElevenLabs v3] Single-chunk generation complete (${audio.length} bytes).`);
    return audio;
  }

  // Multi-chunk: generate each independently and concatenate
  const audioBuffers: Buffer[] = [];

  for (let i = 0; i < chunks.length; i++) {
    const chunk = chunks[i]!;
    console.log(`[ElevenLabs v3] Generating chunk ${i + 1}/${chunks.length} (${chunk.length} chars)...`);

    const audio = await generateChunk(chunk, voiceId, modelId, persona);
    audioBuffers.push(audio);

    console.log(`[ElevenLabs v3] Chunk ${i + 1} complete (${audio.length} bytes).`);
  }

  console.log(`[ElevenLabs v3] All ${chunks.length} chunks generated. Concatenating audio...`);
  return Buffer.concat(audioBuffers);
}

/**
 * Estimate the duration of speech for given text.
 * Strips emotion annotations before counting words.
 * ~150 words per minute for natural speech.
 */
export function estimateDuration(text: string): number {
  // Strip inline annotations like [warm tone], [laughs], etc.
  const cleaned = text.replace(/\[.*?\]/g, '');
  const wordCount = cleaned.split(/\s+/).filter(Boolean).length;
  return Math.round((wordCount / 150) * 60); // seconds
}
