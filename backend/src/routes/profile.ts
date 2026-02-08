/**
 * Profile Routes
 *
 * User profile and preferences (voice persona, etc.)
 */

import { Router, Request, Response } from 'express';
import { supabaseAdmin, Tables } from '../utils/supabase.js';
import { VOICE_PERSONAS } from '../services/elevenlabs.js';

export const profileRouter = Router();

/**
 * GET /profile
 * Get the current user's profile and preferences.
 */
profileRouter.get('/', async (req: Request, res: Response) => {
  try {
    const userId = req.user!.id;

    const { data, error } = await supabaseAdmin
      .from(Tables.USERS)
      .select('id, email, voice_persona, created_at')
      .eq('id', userId)
      .single();

    if (error || !data) {
      res.status(404).json({ success: false, error: 'User not found' });
      return;
    }

    res.json({
      success: true,
      data: {
        ...data,
        available_personas: Object.values(VOICE_PERSONAS).map((p) => ({
          id: p.id,
          displayName: p.displayName,
          description: p.description,
        })),
      },
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      error: err instanceof Error ? err.message : 'Failed to get profile',
    });
  }
});

/**
 * PATCH /profile/persona
 * Set the user's voice persona preference.
 */
profileRouter.patch('/persona', async (req: Request, res: Response) => {
  try {
    const userId = req.user!.id;
    const { persona } = req.body;

    if (!persona || !(persona in VOICE_PERSONAS)) {
      res.status(400).json({
        success: false,
        error: `Invalid persona. Must be one of: ${Object.keys(VOICE_PERSONAS).join(', ')}`,
      });
      return;
    }

    const { error } = await supabaseAdmin
      .from(Tables.USERS)
      .update({ voice_persona: persona })
      .eq('id', userId);

    if (error) {
      throw new Error(error.message);
    }

    const config = VOICE_PERSONAS[persona as keyof typeof VOICE_PERSONAS];
    res.json({
      success: true,
      data: {
        persona: config.id,
        displayName: config.displayName,
        description: config.description,
      },
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      error: err instanceof Error ? err.message : 'Failed to update persona',
    });
  }
});

/**
 * GET /profile/personas
 * List all available voice personas (no auth required for onboarding preview).
 */
profileRouter.get('/personas', async (_req: Request, res: Response) => {
  res.json({
    success: true,
    data: Object.values(VOICE_PERSONAS).map((p) => ({
      id: p.id,
      displayName: p.displayName,
      description: p.description,
    })),
  });
});
