/**
 * ElevenLabs TTS Service
 *
 * Converts emotion-annotated podcast scripts to expressive audio using
 * ElevenLabs eleven_multilingual_v2 (highest quality, most expressive).
 *
 * Voice Personas:
 *   1. Thoughtful Friend — warm, conversational, natural rhythm
 *   2. Wise Mentor — calm, grounded, measured delivery
 *   3. Energetic Host — dynamic pacing, genuinely curious
 *
 * The script is expected to contain inline emotion annotations like:
 *   [warm, reflective tone] ... [brightening] ... [gentle laugh] ...
 * ElevenLabs v2 interprets these natively alongside ellipses, em-dashes, etc.
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
// TEXT-TO-SPEECH
// ============================================

interface TTSOptions {
  persona?: VoicePersona | string;
  voiceId?: string;   // Override persona's voice
  modelId?: string;
}

/**
 * Generate speech audio from an emotion-annotated script.
 * Uses the persona's voice settings for optimal expressiveness.
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

  console.log(`[ElevenLabs] Generating with persona "${persona.displayName}" (voice: ${voiceId}, style: ${persona.style})`);

  const response = await fetch(
    `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'xi-api-key': config.elevenlabs.apiKey,
        'Accept': 'audio/mpeg',
      },
      body: JSON.stringify({
        text,
        model_id: modelId,
        voice_settings: {
          stability: persona.stability,
          similarity_boost: persona.similarityBoost,
          style: persona.style,
          use_speaker_boost: persona.speakerBoost,
        },
      }),
    }
  );

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`ElevenLabs API error (${response.status}): ${errorText}`);
  }

  const arrayBuffer = await response.arrayBuffer();
  return Buffer.from(arrayBuffer);
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
