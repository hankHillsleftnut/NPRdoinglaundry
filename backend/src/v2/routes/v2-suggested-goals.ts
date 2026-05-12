/**
 * v2 suggested_goals routes
 *
 *   GET  /v2/suggested-goals                — list pending suggestions for the user
 *   POST /v2/suggested-goals/:id/accept     — create a real goal from a suggestion
 *   POST /v2/suggested-goals/:id/dismiss    — mark a suggestion dismissed
 */

import { Router, Request, Response } from 'express';
import { supabaseAdmin, Tables } from '../../utils/supabase.js';
import { generateEmbedding } from '../../utils/openai.js';

export const v2SuggestedGoalsRouter = Router();

v2SuggestedGoalsRouter.get('/', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const status = (req.query.status as string | undefined) ?? 'pending';

    const { data, error } = await supabaseAdmin
      .from('suggested_goals')
      .select('*')
      .eq('user_id', user.id)
      .eq('status', status)
      .order('created_at', { ascending: false });

    if (error) throw new Error(error.message);

    res.json({ success: true, data: data ?? [] });
  } catch (err) {
    console.error('[v2:suggested-goals] list failed:', err);
    res.status(500).json({
      success: false,
      error: err instanceof Error ? err.message : 'Failed to list',
    });
  }
});

v2SuggestedGoalsRouter.post('/:id/accept', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const { id } = req.params;

    const { data: suggestion, error: fetchErr } = await supabaseAdmin
      .from('suggested_goals')
      .select('*')
      .eq('id', id)
      .eq('user_id', user.id)
      .single();
    if (fetchErr || !suggestion) {
      res.status(404).json({ success: false, error: 'Suggestion not found' });
      return;
    }
    if (suggestion.status !== 'pending') {
      res.status(409).json({ success: false, error: `Suggestion already ${suggestion.status}` });
      return;
    }

    // Optional override from body so the user can tweak title/description before accepting
    const title: string = (req.body?.title as string) ?? suggestion.title;
    const description: string = (req.body?.description as string) ?? suggestion.rationale;

    const embedding = await generateEmbedding(`${title}\n${description}`);

    const { data: goal, error: goalErr } = await supabaseAdmin
      .from(Tables.GOALS)
      .insert({
        user_id: user.id,
        title,
        description,
        is_active: true,
        embedding,
      })
      .select('*')
      .single();
    if (goalErr || !goal) {
      throw new Error(`Failed to create goal: ${goalErr?.message}`);
    }

    await supabaseAdmin
      .from('suggested_goals')
      .update({ status: 'accepted', accepted_goal_id: goal.id })
      .eq('id', id);

    res.json({ success: true, data: { goal, suggestionId: id } });
  } catch (err) {
    console.error('[v2:suggested-goals] accept failed:', err);
    res.status(500).json({
      success: false,
      error: err instanceof Error ? err.message : 'Failed to accept',
    });
  }
});

v2SuggestedGoalsRouter.post('/:id/dismiss', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const { id } = req.params;
    const { data, error } = await supabaseAdmin
      .from('suggested_goals')
      .update({ status: 'dismissed' })
      .eq('id', id)
      .eq('user_id', user.id)
      .eq('status', 'pending')
      .select('id')
      .maybeSingle();

    if (error) throw new Error(error.message);
    if (!data) {
      res.status(404).json({ success: false, error: 'Suggestion not found or not pending' });
      return;
    }

    res.json({ success: true, data: { id } });
  } catch (err) {
    console.error('[v2:suggested-goals] dismiss failed:', err);
    res.status(500).json({
      success: false,
      error: err instanceof Error ? err.message : 'Failed to dismiss',
    });
  }
});
