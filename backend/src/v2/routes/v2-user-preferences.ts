/**
 * v2 user_preferences routes
 *
 *   GET   /v2/user-preferences  — fetch the current row (or null)
 *   PATCH /v2/user-preferences  — upsert subset of fields
 *
 * Preferences feed Stage 2 and Stage 3 of the podcast pipeline (tone, trusted
 * voice, pacing, focus areas, avoid topics, last feedback).
 */

import { Router, Request, Response } from 'express';
import { z } from 'zod';
import {
  getUserPreferences,
  upsertUserPreferences,
} from '../podcast/user-preferences.js';

export const v2UserPreferencesRouter = Router();

const PatchSchema = z.object({
  tone: z.record(z.unknown()).optional(),
  trusted_voice_description: z.string().nullable().optional(),
  pacing: z.string().nullable().optional(),
  focus_areas: z.array(z.string()).optional(),
  avoid_topics: z.array(z.string()).optional(),
  last_podcast_feedback: z.string().nullable().optional(),
});

v2UserPreferencesRouter.get('/', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const prefs = await getUserPreferences(user.id);
    res.json({ success: true, data: prefs });
  } catch (err) {
    console.error('[v2:user-preferences] get failed:', err);
    res.status(500).json({
      success: false,
      error: err instanceof Error ? err.message : 'Failed to fetch preferences',
    });
  }
});

v2UserPreferencesRouter.patch('/', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const parsed = PatchSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({
        success: false,
        error: 'Invalid body',
        details: parsed.error.errors,
      });
      return;
    }

    const prefs = await upsertUserPreferences(user.id, parsed.data);
    res.json({ success: true, data: prefs });
  } catch (err) {
    console.error('[v2:user-preferences] patch failed:', err);
    res.status(500).json({
      success: false,
      error: err instanceof Error ? err.message : 'Failed to update preferences',
    });
  }
});
