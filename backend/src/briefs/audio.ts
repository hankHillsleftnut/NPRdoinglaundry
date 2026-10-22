import type { SignedLink } from './map.js';

/**
 * Signed links to brief audio (BE1.3b, BEA.7): the file is a private object
 * in the agent's `brief-audio` bucket (agent migration 155); the app gets a
 * link that works for an hour from the response. The object is never checked
 * first (a `HEAD` per read would cost more than it saves): a missing file is
 * a player 4xx, which the app treats as text-only for the launch.
 */
export const BRIEF_AUDIO_BUCKET = 'brief-audio';
export const SIGNED_AUDIO_TTL_SECONDS = 3600;

/** Signs one object path; null when storage refused (logged by code, never thrown: the brief still reads). */
export type SignAudio = (path: string, nowMs: number) => Promise<SignedLink | null>;

/** The slice of supabase-js storage the signer uses. */
export interface SigningClient {
  storage: { from(bucket: string): { createSignedUrl(path: string, expiresIn: number): Promise<{ data: { signedUrl: string } | null; error: { message?: string; statusCode?: string | number } | null }> } };
}

export function supabaseSignAudio(client: SigningClient, log: (line: string) => void = (l) => console.warn(l)): SignAudio {
  return async (path, nowMs) => {
    const { data, error } = await client.storage.from(BRIEF_AUDIO_BUCKET).createSignedUrl(path, SIGNED_AUDIO_TTL_SECONDS);
    if (error || !data?.signedUrl) {
      log(`[briefs] audio link not signed (${error?.statusCode ?? 'no url'})`);
      return null;
    }
    return { url: data.signedUrl, expiresAt: new Date(nowMs + SIGNED_AUDIO_TTL_SECONDS * 1000).toISOString() };
  };
}
