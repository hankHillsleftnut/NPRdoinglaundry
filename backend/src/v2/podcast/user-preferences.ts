/**
 * Small helper for reading and upserting the user_preferences row used by
 * Stage 2 and Stage 3 to shape the podcast. Kept thin so it can be reused from
 * the PATCH /v2/user-preferences route.
 */

import { supabaseAdmin } from '../../utils/supabase.js';

export interface UserPreferences {
  user_id: string;
  tone: Record<string, unknown>;
  trusted_voice_description: string | null;
  pacing: string | null;
  focus_areas: string[];
  avoid_topics: string[];
  last_podcast_feedback: string | null;
  last_feedback_at: string | null;
  updated_at: string;
}

export async function getUserPreferences(userId: string): Promise<UserPreferences | null> {
  const { data, error } = await supabaseAdmin
    .from('user_preferences')
    .select('*')
    .eq('user_id', userId)
    .maybeSingle();

  if (error) {
    console.warn('[v2:user-preferences] fetch failed:', error.message);
    return null;
  }
  return (data as UserPreferences) ?? null;
}

export interface UpdatePreferencesInput {
  tone?: Record<string, unknown>;
  trusted_voice_description?: string | null;
  pacing?: string | null;
  focus_areas?: string[];
  avoid_topics?: string[];
  last_podcast_feedback?: string | null;
}

export async function upsertUserPreferences(
  userId: string,
  patch: UpdatePreferencesInput
): Promise<UserPreferences> {
  const row: Record<string, unknown> = { user_id: userId };
  if (patch.tone !== undefined) row.tone = patch.tone;
  if (patch.trusted_voice_description !== undefined) row.trusted_voice_description = patch.trusted_voice_description;
  if (patch.pacing !== undefined) row.pacing = patch.pacing;
  if (patch.focus_areas !== undefined) row.focus_areas = patch.focus_areas;
  if (patch.avoid_topics !== undefined) row.avoid_topics = patch.avoid_topics;
  if (patch.last_podcast_feedback !== undefined) {
    row.last_podcast_feedback = patch.last_podcast_feedback;
    row.last_feedback_at = new Date().toISOString();
  }

  const { data, error } = await supabaseAdmin
    .from('user_preferences')
    .upsert(row, { onConflict: 'user_id' })
    .select('*')
    .single();

  if (error) {
    throw new Error(`upsert user_preferences failed: ${error.message}`);
  }
  return data as UserPreferences;
}
