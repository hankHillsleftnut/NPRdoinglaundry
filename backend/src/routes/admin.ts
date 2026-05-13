import { Router, Request, Response, NextFunction } from 'express';
import { config } from '../utils/config.js';
import { supabaseAdmin, Tables } from '../utils/supabase.js';
import { createGoal, listGoals, extractGoalsFromText, extractAndSaveGoals } from '../services/goals.js';
import { processAllPendingContent, processContentForObservations, listObservations } from '../services/observations.js';
import { generateInsightsForAllGoals, listInsights, getInsightWithObservations } from '../services/insight-synthesis.js';
import { generatePodcastEpisode, listPodcastEpisodes, getLatestEpisode } from '../services/podcast-generation.js';

export const adminRouter = Router();

// ============================================
// Error formatting
// ============================================
// Supabase PostgrestError and many thrown values are plain objects; `String(obj)`
// returns `"[object Object]"`, which is what was leaking to the dashboard. Pull
// the most useful field out instead, and fall back to a JSON dump.
function errorMessage(err: unknown): string {
  if (err == null) return 'Unknown error';
  if (typeof err === 'string') return err;
  if (err instanceof Error) return err.message || err.name || 'Error';
  if (typeof err === 'object') {
    const e = err as Record<string, unknown>;
    const parts = [e.message, e.details, e.hint, e.code]
      .filter((v): v is string => typeof v === 'string' && v.length > 0);
    if (parts.length > 0) return parts.join(' | ');
    try {
      return JSON.stringify(err);
    } catch {
      return Object.prototype.toString.call(err);
    }
  }
  return String(err);
}

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
adminRouter.get('/users', async (req: Request, res: Response) => {
  try {
    const { data, error } = await supabaseAdmin
      .from(Tables.USERS)
      .select('id, email, apple_user_id, created_at')
      .order('created_at', { ascending: false });

    if (error) throw error;
    res.json({ success: true, data: data || [] });
  } catch (error) {
    console.error('[admin]', req.method, req.path, error);
    res.status(500).json({ success: false, error: errorMessage(error) });
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
    console.error('[admin]', req.method, req.path, error);
    res.status(500).json({ success: false, error: errorMessage(error) });
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
    console.error('[admin]', req.method, req.path, error);
    res.status(500).json({ success: false, error: errorMessage(error) });
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
    console.error('[admin]', req.method, req.path, error);
    res.status(500).json({ success: false, error: errorMessage(error) });
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
    console.error('[admin]', req.method, req.path, error);
    res.status(500).json({ success: false, error: errorMessage(error) });
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
    console.error('[admin]', req.method, req.path, error);
    res.status(500).json({ success: false, error: errorMessage(error) });
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
    console.error('[admin]', req.method, req.path, error);
    res.status(500).json({ success: false, error: errorMessage(error) });
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
    console.error('[admin]', req.method, req.path, error);
    res.status(500).json({ success: false, error: errorMessage(error) });
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
    console.error('[admin]', req.method, req.path, error);
    res.status(500).json({ success: false, error: errorMessage(error) });
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
    console.error('[admin]', req.method, req.path, error);
    res.status(500).json({ success: false, error: errorMessage(error) });
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
    console.error('[admin]', req.method, req.path, error);
    res.status(500).json({ success: false, error: errorMessage(error) });
  }
});

// ============================================
// Pipeline
// ============================================

// POST /admin/pipeline/observations — extract observations only
adminRouter.post('/pipeline/observations', async (req: Request, res: Response) => {
  try {
    const { userId, forceReprocess } = req.body;
    if (!userId) {
      res.status(400).json({ success: false, error: 'userId is required' });
      return;
    }

    const result = await processAllPendingContent(userId, forceReprocess === true);
    res.json({
      success: true,
      data: result,
      message: `Processed ${result.contentProcessed} content items, created ${result.totalObservations} observations.`,
    });
  } catch (error) {
    console.error('[admin]', req.method, req.path, error);
    res.status(500).json({ success: false, error: errorMessage(error) });
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
    console.error('[admin]', req.method, req.path, error);
    res.status(500).json({ success: false, error: errorMessage(error) });
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
    console.error('[admin]', req.method, req.path, error);
    res.status(500).json({ success: false, error: errorMessage(error) });
  }
});

// POST /admin/pipeline/run — full pipeline (content → observations → insights)
adminRouter.post('/pipeline/run', async (req: Request, res: Response) => {
  try {
    const { userId, daysBack, forceReprocess } = req.body;
    if (!userId) {
      res.status(400).json({ success: false, error: 'userId is required' });
      return;
    }

    // Step 1: Extract observations
    const obsResult = await processAllPendingContent(userId, forceReprocess === true);

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
    console.error('[admin]', req.method, req.path, error);
    res.status(500).json({ success: false, error: errorMessage(error) });
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
    console.error('[admin]', req.method, req.path, error);
    res.status(500).json({ success: false, error: errorMessage(error) });
  }
});

// ============================================
// Diagnostics — trace pipeline step by step
// ============================================

adminRouter.post('/diagnose', async (req: Request, res: Response) => {
  const { userId } = req.body;
  if (!userId) {
    res.status(400).json({ success: false, error: 'userId is required' });
    return;
  }

  const steps: Array<{ step: string; status: string; detail: string; data?: unknown }> = [];

  try {
    // Step 1: Check user exists
    const { data: user, error: userErr } = await supabaseAdmin
      .from(Tables.USERS)
      .select('id, email')
      .eq('id', userId)
      .single();
    if (userErr || !user) {
      steps.push({ step: 'User lookup', status: 'FAIL', detail: `User not found: ${userErr?.message || 'no data'}` });
      res.json({ success: true, data: { steps } });
      return;
    }
    steps.push({ step: 'User lookup', status: 'OK', detail: `Found: ${user.email}` });

    // Step 2: Check goals
    const { data: allGoals, error: goalsErr } = await supabaseAdmin
      .from(Tables.GOALS)
      .select('id, title, is_active, embedding')
      .eq('user_id', userId);
    if (goalsErr) {
      steps.push({ step: 'Goals query', status: 'FAIL', detail: goalsErr.message });
      res.json({ success: true, data: { steps } });
      return;
    }
    const totalGoals = (allGoals || []).length;
    const activeGoals = (allGoals || []).filter((g: any) => g.is_active);
    const goalsWithEmbedding = activeGoals.filter((g: any) => g.embedding != null);
    const embeddingTypes = activeGoals.map((g: any) => ({
      title: g.title,
      is_active: g.is_active,
      has_embedding: g.embedding != null,
      embedding_type: typeof g.embedding,
      embedding_is_array: Array.isArray(g.embedding),
      embedding_length: Array.isArray(g.embedding) ? g.embedding.length : (typeof g.embedding === 'string' ? g.embedding.length : 0),
      embedding_preview: Array.isArray(g.embedding) ? `[${g.embedding.slice(0, 3).join(', ')}...]` : (typeof g.embedding === 'string' ? g.embedding.slice(0, 80) + '...' : String(g.embedding)),
    }));
    steps.push({
      step: 'Goals check',
      status: goalsWithEmbedding.length > 0 ? 'OK' : 'FAIL',
      detail: `Total: ${totalGoals}, Active: ${activeGoals.length}, With embedding: ${goalsWithEmbedding.length}`,
      data: embeddingTypes,
    });

    // Step 3: Check raw content
    const { data: rawContent, error: rcErr } = await supabaseAdmin
      .from(Tables.RAW_CONTENT)
      .select('id, content_type, processing_status, created_at')
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .limit(10);
    if (rcErr) {
      steps.push({ step: 'Raw content query', status: 'FAIL', detail: rcErr.message });
    } else {
      steps.push({
        step: 'Raw content',
        status: (rawContent || []).length > 0 ? 'OK' : 'WARN',
        detail: `Found ${(rawContent || []).length} content items`,
        data: rawContent,
      });
    }

    // Step 4: Check pipeline runs
    const { data: pipelineRuns, error: prErr } = await supabaseAdmin
      .from(Tables.PIPELINE_RUNS)
      .select('*')
      .eq('user_id', userId)
      .order('started_at', { ascending: false })
      .limit(10);
    steps.push({
      step: 'Pipeline runs',
      status: 'INFO',
      detail: `Found ${(pipelineRuns || []).length} pipeline runs`,
      data: pipelineRuns,
    });

    // Step 5: Check existing observations
    const { data: existingObs, count: obsCount } = await supabaseAdmin
      .from(Tables.OBSERVATIONS)
      .select('id, goal_id, content, confidence_score', { count: 'exact' })
      .eq('user_id', userId)
      .limit(5);
    steps.push({
      step: 'Existing observations',
      status: 'INFO',
      detail: `Total: ${obsCount || 0}`,
      data: existingObs,
    });

    // Step 6: Check existing insights
    const { data: existingIns, count: insCount } = await supabaseAdmin
      .from(Tables.INSIGHTS)
      .select('id, goal_id, title, content', { count: 'exact' })
      .eq('user_id', userId)
      .limit(5);
    steps.push({
      step: 'Existing insights',
      status: 'INFO',
      detail: `Total: ${insCount || 0}`,
      data: existingIns,
    });

    // Step 7: Try to get active goals with embeddings (the actual function the pipeline uses)
    try {
      const pipelineGoals = await listGoals(userId);
      const activeWithEmbed = pipelineGoals.filter((g: any) => g.is_active && g.embedding != null);
      steps.push({
        step: 'getActiveGoalsWithEmbeddings simulation',
        status: activeWithEmbed.length > 0 ? 'OK' : 'FAIL',
        detail: `listGoals returned ${pipelineGoals.length}, active with embedding: ${activeWithEmbed.length}`,
      });
    } catch (e) {
      steps.push({ step: 'getActiveGoalsWithEmbeddings simulation', status: 'FAIL', detail: errorMessage(e) });
    }

    // Step 8: Test a mini observation extraction if we have content + goals
    if (goalsWithEmbedding.length > 0 && (rawContent || []).length > 0) {
      try {
        // Just test the chunk + embedding step, not the full extraction
        const testContent = await supabaseAdmin
          .from(Tables.RAW_CONTENT)
          .select('content')
          .eq('user_id', userId)
          .limit(1)
          .single();

        if (testContent.data) {
          const contentPreview = testContent.data.content.slice(0, 200);
          steps.push({
            step: 'Content preview',
            status: 'INFO',
            detail: `First content item: "${contentPreview}..."`,
          });
        }
      } catch (e) {
        steps.push({ step: 'Content preview', status: 'FAIL', detail: errorMessage(e) });
      }
    }

    // Step 9: Check environment
    steps.push({
      step: 'Environment check',
      status: 'INFO',
      detail: `ANTHROPIC_API_KEY: ${process.env.ANTHROPIC_API_KEY ? 'set (' + process.env.ANTHROPIC_API_KEY.slice(0, 8) + '...)' : 'MISSING'}, OPENAI_API_KEY: ${process.env.OPENAI_API_KEY ? 'set (' + process.env.OPENAI_API_KEY.slice(0, 8) + '...)' : 'MISSING'}`,
    });

    res.json({ success: true, data: { steps } });
  } catch (error) {
    console.error('[admin] /diagnose', error);
    steps.push({ step: 'Unexpected error', status: 'FAIL', detail: errorMessage(error) });
    res.json({ success: true, data: { steps } });
  }
});

// ============================================
// Podcasts
// ============================================

// GET /admin/podcasts?userId= — list podcast episodes
adminRouter.get('/podcasts', async (req: Request, res: Response) => {
  try {
    const userId = req.query.userId as string;
    if (!userId) {
      res.status(400).json({ success: false, error: 'userId is required' });
      return;
    }
    const { episodes, total } = await listPodcastEpisodes(userId);
    res.json({ success: true, data: episodes, total });
  } catch (error) {
    console.error('[admin]', req.method, req.path, error);
    res.status(500).json({ success: false, error: errorMessage(error) });
  }
});

// POST /admin/podcasts/generate — trigger podcast generation for a user
adminRouter.post('/podcasts/generate', async (req: Request, res: Response) => {
  try {
    const { userId, daysSince, skipTTS, persona } = req.body;
    if (!userId) {
      res.status(400).json({ success: false, error: 'userId is required' });
      return;
    }

    const latestEp = await getLatestEpisode(userId);

    const episode = await generatePodcastEpisode({
      userId,
      daysSince: daysSince ?? 7,
      previousEpisodeId: latestEp?.id,
      generationType: 'on_demand',
      skipTTS: skipTTS ?? true, // Default to skip TTS in admin to save costs
      persona: persona ?? undefined,
    });

    res.json({ success: true, data: episode });
  } catch (error) {
    console.error('[admin]', req.method, req.path, error);
    res.status(500).json({ success: false, error: errorMessage(error) });
  }
});

// ============================================
// Stats
// ============================================

// GET /admin/stats — overall system stats
adminRouter.get('/stats', async (req: Request, res: Response) => {
  try {
    const [users, content, goals, observations, insights, runs, podcasts] = await Promise.all([
      supabaseAdmin.from(Tables.USERS).select('id', { count: 'exact', head: true }),
      supabaseAdmin.from(Tables.RAW_CONTENT).select('id', { count: 'exact', head: true }),
      supabaseAdmin.from(Tables.GOALS).select('id', { count: 'exact', head: true }),
      supabaseAdmin.from(Tables.OBSERVATIONS).select('id', { count: 'exact', head: true }),
      supabaseAdmin.from(Tables.INSIGHTS).select('id', { count: 'exact', head: true }),
      supabaseAdmin.from(Tables.PIPELINE_RUNS).select('id', { count: 'exact', head: true }),
      supabaseAdmin.from(Tables.PODCAST_EPISODES).select('id', { count: 'exact', head: true }),
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
        podcastEpisodes: podcasts.count || 0,
      },
    });
  } catch (error) {
    console.error('[admin]', req.method, req.path, error);
    res.status(500).json({ success: false, error: errorMessage(error) });
  }
});
