export type VoicePersona = 'thoughtful_friend' | 'wise_mentor' | 'energetic_host';

type V3Stability = 0.0 | 0.5 | 1.0;

export interface PersonaConfig {
  id: VoicePersona;
  displayName: string;
  description: string;
  voiceId: string;
  stability: V3Stability;
}

export const VOICE_PERSONAS: Record<VoicePersona, PersonaConfig> = {
  thoughtful_friend: {
    id: 'thoughtful_friend',
    displayName: 'Thoughtful Friend',
    description: 'Warm and conversational, like catching up over coffee. Natural laughs, vocal warmth, genuine engagement.',
    voiceId: '21m00Tcm4TlvDq8ikWAM',
    stability: 0.0,
  },
  wise_mentor: {
    id: 'wise_mentor',
    displayName: 'Wise Mentor',
    description: 'Calm and grounded with gravitas. Lets insights land. Measured pacing with purposeful emphasis.',
    voiceId: 'pNInz6obpgDQGcFmaJgB',
    stability: 0.5,
  },
  energetic_host: {
    id: 'energetic_host',
    displayName: 'Energetic Host',
    description: 'Dynamic and engaging. Varied pacing, genuinely curious tone, celebrates wins audibly.',
    voiceId: 'ErXwobaYiN019PkySvjV',
    stability: 0.0,
  },
};

export function getPersonaConfig(persona?: string): PersonaConfig {
  if (persona && persona in VOICE_PERSONAS) {
    return VOICE_PERSONAS[persona as VoicePersona];
  }
  return VOICE_PERSONAS.thoughtful_friend;
}
