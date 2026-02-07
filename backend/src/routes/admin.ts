import { Router, Request, Response, NextFunction } from 'express';
import { config } from '../utils/config.js';
import { supabaseAdmin, Tables } from '../utils/supabase.js';
import { createGoal, listGoals, extractGoalsFromText, extractAndSaveGoals } from '../services/goals.js';
import { processAllPendingContent, processContentForObservations, listObservations } from '../services/observations.js';
import { generateInsightsForAllGoals, listInsights, getInsightWithObservations } from '../services/insight-synthesis.js';

export const adminRouter = Router();

// ============================================
// Admin secret middleware
// ============================================
function adminAuth(req: Request, res: Response, next: NextFunction): void {
  const secret = req.query.secret as string || req.headers['x-admin-secret'] as string;
  if (!secret || secret !== config.admin.secret) {
    res.status(403).json({ success: false, error: 'Invalid admin secret' });
    return;
  }
  next();
}

adminRouter.use(adminAuth);

// ============================================
// Users
// ============================================

// GET /admin/users — list all users
adminRouter.get('/users', async (_req: Request, res: Response) => {
  try {
    const { data, error } = await supabaseAdmin
      .from(Tables.USERS)
      .select('id, email, apple_user_id, created_at')
      .order('created_at', { ascending: false });

    if (error) throw error;
    res.json({ success: true, data: data || [] });
  } catch (error) {
    res.status(500).json({ success: false, error: String(error) });
  }
});

// POST /admin/users — create a test user
adminRouter.post('/users', async (req: Request, res: Response) => {
  try {
    const { email, appleUserId } = req.body;
    const { data, error } = await supabaseAdmin
      .from(Tables.USERS)
      .insert({
        email: email || `test-${Date.now()}@retrospect.dev`,
        apple_user_id: appleUserId || `test_apple_${Date.now()}`,
      })
      .select('id, email, apple_user_id, created_at')
      .single();

    if (error) throw error;
    res.status(201).json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, error: String(error) });
  }
});

// ============================================
// Goals
// ============================================

// GET /admin/goals?userId= — list goals for a user
adminRouter.get('/goals', async (req: Request, res: Response) => {
  try {
    const userId = req.query.userId as string;
    if (!userId) {
      res.status(400).json({ success: false, error: 'userId is required' });
      return;
    }
    const goals = await listGoals(userId);
    res.json({ success: true, data: goals });
  } catch (error) {
    res.status(500).json({ success: false, error: String(error) });
  }
});

// POST /admin/goals — create a goal
adminRouter.post('/goals', async (req: Request, res: Response) => {
  try {
    const { userId, title, description } = req.body;
    if (!userId || !title) {
      res.status(400).json({ success: false, error: 'userId and title are required' });
      return;
    }
    const goal = await createGoal(userId, title, description);
    res.status(201).json({ success: true, data: goal });
  } catch (error) {
    res.status(500).json({ success: false, error: String(error) });
  }
});

// POST /admin/goals/extract — extract goals from text (preview only)
adminRouter.post('/goals/extract', async (req: Request, res: Response) => {
  try {
    const { text } = req.body;
    if (!text) {
      res.status(400).json({ success: false, error: 'text is required' });
      return;
    }
    const result = await extractGoalsFromText(text);
    res.json({ success: true, data: result });
  } catch (error) {
    res.status(500).json({ success: false, error: String(error) });
  }
});

// POST /admin/goals/extract-and-save — extract + save goals
adminRouter.post('/goals/extract-and-save', async (req: Request, res: Response) => {
  try {
    const { userId, text } = req.body;
    if (!userId || !text) {
      res.status(400).json({ success: false, error: 'userId and text are required' });
      return;
    }
    const result = await extractAndSaveGoals(userId, text);
    res.status(201).json({
      success: true,
      data: {
        extracted: result.extracted,
        saved: result.savedGoals,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, error: String(error) });
  }
});

// ============================================
// Content
// ============================================

// GET /admin/content?userId= — list raw content
adminRouter.get('/content', async (req: Request, res: Response) => {
  try {
    const userId = req.query.userId as string;
    if (!userId) {
      res.status(400).json({ success: false, error: 'userId is required' });
      return;
    }

    const limit = parseInt(req.query.limit as string) || 50;

    const { data, error, count } = await supabaseAdmin
      .from(Tables.RAW_CONTENT)
      .select('id, content_type, content, content_date, processing_status, created_at', { count: 'exact' })
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .limit(limit);

    if (error) throw error;
    res.json({ success: true, data: data || [], total: count || 0 });
  } catch (error) {
    res.status(500).json({ success: false, error: String(error) });
  }
});

// POST /admin/content — submit test content
adminRouter.post('/content', async (req: Request, res: Response) => {
  try {
    const { userId, contentType, content, contentDate } = req.body;
    if (!userId || !content) {
      res.status(400).json({ success: false, error: 'userId and content are required' });
      return;
    }

    const { data, error } = await supabaseAdmin
      .from(Tables.RAW_CONTENT)
      .insert({
        user_id: userId,
        content_type: contentType || 'journal_entry',
        content,
        content_date: contentDate || new Date().toISOString(),
        processing_status: 'pending',
        metadata: {},
      })
      .select('id, content_type, content_date, processing_status, created_at')
      .single();

    if (error) throw error;
    res.status(201).json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, error: String(error) });
  }
});

// ============================================
// Observations
// ============================================

// GET /admin/observations?userId=&goalId= — list observations
adminRouter.get('/observations', async (req: Request, res: Response) => {
  try {
    const userId = req.query.userId as string;
    if (!userId) {
      res.status(400).json({ success: false, error: 'userId is required' });
      return;
    }

    const result = await listObservations(userId, {
      goalId: req.query.goalId as string | undefined,
      limit: parseInt(req.query.limit as string) || 100,
      offset: parseInt(req.query.offset as string) || 0,
    });

    res.json({ success: true, data: result.observations, total: result.total });
  } catch (error) {
    res.status(500).json({ success: false, error: String(error) });
  }
});

// ============================================
// Insights
// ============================================

// GET /admin/insights?userId=&goalId= — list insights
adminRouter.get('/insights', async (req: Request, res: Response) => {
  try {
    const userId = req.query.userId as string;
    if (!userId) {
      res.status(400).json({ success: false, error: 'userId is required' });
      return;
    }

    const result = await listInsights(userId, {
      goalId: req.query.goalId as string | undefined,
      limit: parseInt(req.query.limit as string) || 100,
      offset: parseInt(req.query.offset as string) || 0,
    });

    res.json({ success: true, data: result.insights, total: result.total });
  } catch (error) {
    res.status(500).json({ success: false, error: String(error) });
  }
});

// GET /admin/insights/:id — get insight with observations
adminRouter.get('/insights/:id', async (req: Request, res: Response) => {
  try {
    const userId = req.query.userId as string;
    if (!userId) {
      res.status(400).json({ success: false, error: 'userId is required' });
      return;
    }

    const result = await getInsightWithObservations(req.params.id!, userId);
    if (!result) {
      res.status(404).json({ success: false, error: 'Insight not found' });
      return;
    }

    res.json({ success: true, data: result });
  } catch (error) {
    res.status(500).json({ success: false, error: String(error) });
  }
});

// ============================================
// Pipeline
// ============================================

// POST /admin/pipeline/observations — extract observations only
adminRouter.post('/pipeline/observations', async (req: Request, res: Response) => {
  try {
    const { userId } = req.body;
    if (!userId) {
      res.status(400).json({ success: false, error: 'userId is required' });
      return;
    }

    const result = await processAllPendingContent(userId);
    res.json({
      success: true,
      data: result,
      message: `Processed ${result.contentProcessed} content items, created ${result.totalObservations} observations.`,
    });
  } catch (error) {
    res.status(500).json({ success: false, error: String(error) });
  }
});

// POST /admin/pipeline/observations/:contentId — extract observations from specific content
adminRouter.post('/pipeline/observations/:contentId', async (req: Request, res: Response) => {
  try {
    const { userId } = req.body;
    if (!userId) {
      res.status(400).json({ success: false, error: 'userId is required' });
      return;
    }

    const result = await processContentForObservations(req.params.contentId!, userId);
    res.json({
      success: true,
      data: result,
      message: `Created ${result.observationIds.length} observations.`,
    });
  } catch (error) {
    res.status(500).json({ success: false, error: String(error) });
  }
});

// POST /admin/pipeline/insights — generate insights only
adminRouter.post('/pipeline/insights', async (req: Request, res: Response) => {
  try {
    const { userId, daysBack } = req.body;
    if (!userId) {
      res.status(400).json({ success: false, error: 'userId is required' });
      return;
    }

    const result = await generateInsightsForAllGoals(userId, daysBack || 30);
    res.json({
      success: true,
      data: result,
      message: `Created ${result.totalCreated} new insights, updated ${result.totalUpdated} existing.`,
    });
  } catch (error) {
    res.status(500).json({ success: false, error: String(error) });
  }
});

// POST /admin/pipeline/run — full pipeline (content → observations → insights)
adminRouter.post('/pipeline/run', async (req: Request, res: Response) => {
  try {
    const { userId, daysBack } = req.body;
    if (!userId) {
      res.status(400).json({ success: false, error: 'userId is required' });
      return;
    }

    // Step 1: Extract observations
    const obsResult = await processAllPendingContent(userId);

    // Step 2: Generate insights
    const insightResult = await generateInsightsForAllGoals(userId, daysBack || 30);

    res.json({
      success: true,
      data: {
        observations: obsResult,
        insights: insightResult,
      },
      message: `Pipeline complete. ${obsResult.totalObservations} observations, ${insightResult.totalCreated} new insights, ${insightResult.totalUpdated} updated.`,
    });
  } catch (error) {
    res.status(500).json({ success: false, error: String(error) });
  }
});

// GET /admin/pipeline/runs?userId= — pipeline run history
adminRouter.get('/pipeline/runs', async (req: Request, res: Response) => {
  try {
    const userId = req.query.userId as string;

    let query = supabaseAdmin
      .from(Tables.PIPELINE_RUNS)
      .select('*')
      .order('started_at', { ascending: false })
      .limit(50);

    if (userId) {
      query = query.eq('user_id', userId);
    }

    const { data, error } = await query;
    if (error) throw error;

    res.json({ success: true, data: data || [] });
  } catch (error) {
    res.status(500).json({ success: false, error: String(error) });
  }
});

// ============================================
// Stats
// ============================================

// GET /admin/stats — overall system stats
adminRouter.get('/stats', async (_req: Request, res: Response) => {
  try {
    const [users, content, goals, observations, insights, runs] = await Promise.all([
      supabaseAdmin.from(Tables.USERS).select('id', { count: 'exact', head: true }),
      supabaseAdmin.from(Tables.RAW_CONTENT).select('id', { count: 'exact', head: true }),
      supabaseAdmin.from(Tables.GOALS).select('id', { count: 'exact', head: true }),
      supabaseAdmin.from(Tables.OBSERVATIONS).select('id', { count: 'exact', head: true }),
      supabaseAdmin.from(Tables.INSIGHTS).select('id', { count: 'exact', head: true }),
      supabaseAdmin.from(Tables.PIPELINE_RUNS).select('id', { count: 'exact', head: true }),
    ]);

    res.json({
      success: true,
      data: {
        users: users.count || 0,
        rawContent: content.count || 0,
        goals: goals.count || 0,
        observations: observations.count || 0,
        insights: insights.count || 0,
        pipelineRuns: runs.count || 0,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, error: String(error) });
  }
});
