import { Router, Request, Response } from 'express';
import { createGoal, updateGoal, deleteGoal, listGoals, getGoal, extractGoalsFromText, extractAndSaveGoals } from '../services/goals.js';
import { CreateGoalSchema, UpdateGoalSchema, ExtractGoalsSchema } from '../types/index.js';

export const goalsRouter = Router();

// POST /goals - Create a new goal
goalsRouter.post('/', async (req: Request, res: Response) => {
  try {
    const user = (req as any).user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const validationResult = CreateGoalSchema.safeParse(req.body);
    if (!validationResult.success) {
      res.status(400).json({
        success: false,
        error: 'Invalid request',
        details: validationResult.error.issues,
      });
      return;
    }

    const { title, description } = validationResult.data;
    const goal = await createGoal(user.id, title, description);

    res.status(201).json({
      success: true,
      data: goal,
    });
  } catch (error) {
    console.error('Create goal error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Failed to create goal',
    });
  }
});

// GET /goals - List all goals
goalsRouter.get('/', async (req: Request, res: Response) => {
  try {
    const user = (req as any).user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const activeOnly = req.query.activeOnly === 'true';
    const goals = await listGoals(user.id, activeOnly);

    res.json({
      success: true,
      data: goals,
    });
  } catch (error) {
    console.error('List goals error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Failed to list goals',
    });
  }
});

// GET /goals/:id - Get a single goal
goalsRouter.get('/:id', async (req: Request, res: Response) => {
  try {
    const user = (req as any).user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const goal = await getGoal(req.params.id!, user.id);
    if (!goal) {
      res.status(404).json({ success: false, error: 'Goal not found' });
      return;
    }

    res.json({ success: true, data: goal });
  } catch (error) {
    console.error('Get goal error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Failed to get goal',
    });
  }
});

// PATCH /goals/:id - Update a goal
goalsRouter.patch('/:id', async (req: Request, res: Response) => {
  try {
    const user = (req as any).user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const validationResult = UpdateGoalSchema.safeParse(req.body);
    if (!validationResult.success) {
      res.status(400).json({
        success: false,
        error: 'Invalid request',
        details: validationResult.error.issues,
      });
      return;
    }

    const goal = await updateGoal(req.params.id!, user.id, validationResult.data);

    res.json({ success: true, data: goal });
  } catch (error) {
    console.error('Update goal error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Failed to update goal',
    });
  }
});

// POST /goals/extract - Extract goals from natural language (returns suggestions, does NOT save)
goalsRouter.post('/extract', async (req: Request, res: Response) => {
  try {
    const user = (req as any).user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const validationResult = ExtractGoalsSchema.safeParse(req.body);
    if (!validationResult.success) {
      res.status(400).json({
        success: false,
        error: 'Invalid request — provide a "text" field with the user\'s words',
        details: validationResult.error.issues,
      });
      return;
    }

    const result = await extractGoalsFromText(validationResult.data.text);

    res.json({
      success: true,
      data: result.goals,
      message: `Extracted ${result.goals.length} goal(s). Review and confirm before saving.`,
      processingNotes: result.processingNotes,
    });
  } catch (error) {
    console.error('Goal extraction error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Failed to extract goals',
    });
  }
});

// POST /goals/extract-and-save - Extract goals from natural language AND save them immediately
// Used during onboarding when user has already agreed to proceed.
goalsRouter.post('/extract-and-save', async (req: Request, res: Response) => {
  try {
    const user = (req as any).user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const validationResult = ExtractGoalsSchema.safeParse(req.body);
    if (!validationResult.success) {
      res.status(400).json({
        success: false,
        error: 'Invalid request — provide a "text" field with the user\'s words',
        details: validationResult.error.issues,
      });
      return;
    }

    const result = await extractAndSaveGoals(user.id, validationResult.data.text);

    res.status(201).json({
      success: true,
      data: {
        extracted: result.extracted.goals,
        saved: result.savedGoals,
      },
      message: `Extracted and saved ${result.savedGoals.length} goal(s).`,
    });
  } catch (error) {
    console.error('Goal extract-and-save error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Failed to extract and save goals',
    });
  }
});

// DELETE /goals/:id - Delete a goal
goalsRouter.delete('/:id', async (req: Request, res: Response) => {
  try {
    const user = (req as any).user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    await deleteGoal(req.params.id!, user.id);

    res.json({ success: true, message: 'Goal deleted' });
  } catch (error) {
    console.error('Delete goal error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Failed to delete goal',
    });
  }
});
