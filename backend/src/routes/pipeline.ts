import { Router, Request, Response } from 'express';
import { processAllPendingContent, processContentForObservations, listObservations } from '../services/observations.js';
import { generateInsightsForAllGoals, listInsights, getInsightWithObservations } from '../services/insight-synthesis.js';
import { supabaseAdmin, Tables } from '../utils/supabase.js';

export const pipelineRouter = Router();

// ============================================
// Observation Routes
// ============================================

// POST /pipeline/observations/extract - Extract observations from all pending content
pipelineRouter.post('/observations/extract', async (req: Request, res: Response) => {
  try {
    const user = (req as any).user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const result = await processAllPendingContent(user.id);

    res.json({
      success: true,
      data: {
        contentProcessed: result.contentProcessed,
        totalObservations: result.totalObservations,
        byGoal: result.byGoal,
      },
      message: `Processed ${result.contentProcessed} content items, created ${result.totalObservations} observations.`,
    });
  } catch (error) {
    console.error('Observation extraction error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Extraction failed',
    });
  }
});

// POST /pipeline/observations/extract/:contentId - Extract observations from a specific content item
pipelineRouter.post('/observations/extract/:contentId', async (req: Request, res: Response) => {
  try {
    const user = (req as any).user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const result = await processContentForObservations(req.params.contentId!, user.id);

    res.json({
      success: true,
      data: {
        observationIds: result.observationIds,
        totalObservations: result.observationIds.length,
        byGoal: result.byGoal,
      },
    });
  } catch (error) {
    console.error('Single content observation extraction error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Extraction failed',
    });
  }
});

// GET /pipeline/observations - List observations
pipelineRouter.get('/observations', async (req: Request, res: Response) => {
  try {
    const user = (req as any).user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const options = {
      goalId: req.query.goalId as string | undefined,
      limit: req.query.limit ? parseInt(req.query.limit as string) : 50,
      offset: req.query.offset ? parseInt(req.query.offset as string) : 0,
      startDate: req.query.startDate as string | undefined,
      endDate: req.query.endDate as string | undefined,
    };

    const result = await listObservations(user.id, options);

    res.json({
      success: true,
      data: result.observations,
      pagination: {
        total: result.total,
        limit: options.limit,
        offset: options.offset,
        hasMore: options.offset + options.limit < result.total,
      },
    });
  } catch (error) {
    console.error('List observations error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Failed to list observations',
    });
  }
});

// ============================================
// Insight Routes
// ============================================

// POST /pipeline/insights/generate - Generate insights from observations
pipelineRouter.post('/insights/generate', async (req: Request, res: Response) => {
  try {
    const user = (req as any).user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const daysBack = req.body.daysBack ? parseInt(req.body.daysBack) : 30;
    const result = await generateInsightsForAllGoals(user.id, daysBack);

    res.json({
      success: true,
      data: {
        totalCreated: result.totalCreated,
        totalUpdated: result.totalUpdated,
        byGoal: result.byGoal,
      },
      message: `Created ${result.totalCreated} new insights, updated ${result.totalUpdated} existing insights.`,
    });
  } catch (error) {
    console.error('Insight generation error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Insight generation failed',
    });
  }
});

// GET /pipeline/insights - List insights
pipelineRouter.get('/insights', async (req: Request, res: Response) => {
  try {
    const user = (req as any).user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const options = {
      goalId: req.query.goalId as string | undefined,
      limit: req.query.limit ? parseInt(req.query.limit as string) : 50,
      offset: req.query.offset ? parseInt(req.query.offset as string) : 0,
    };

    const result = await listInsights(user.id, options);

    res.json({
      success: true,
      data: result.insights,
      pagination: {
        total: result.total,
        limit: options.limit,
        offset: options.offset,
        hasMore: options.offset + options.limit < result.total,
      },
    });
  } catch (error) {
    console.error('List insights error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Failed to list insights',
    });
  }
});

// GET /pipeline/insights/:id - Get an insight with its supporting observations
pipelineRouter.get('/insights/:id', async (req: Request, res: Response) => {
  try {
    const user = (req as any).user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const result = await getInsightWithObservations(req.params.id!, user.id);

    if (!result) {
      res.status(404).json({ success: false, error: 'Insight not found' });
      return;
    }

    res.json({
      success: true,
      data: result,
    });
  } catch (error) {
    console.error('Get insight error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Failed to get insight',
    });
  }
});

// ============================================
// Full Pipeline Route
// ============================================

// POST /pipeline/run - Run the full pipeline (extract observations + generate insights)
pipelineRouter.post('/run', async (req: Request, res: Response) => {
  try {
    const user = (req as any).user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const daysBack = req.body.daysBack ? parseInt(req.body.daysBack) : 30;

    // Create pipeline run record
    const { data: pipelineRun } = await supabaseAdmin
      .from(Tables.PIPELINE_RUNS)
      .insert({
        user_id: user.id,
        run_type: 'full_pipeline',
        status: 'running',
      })
      .select('id')
      .single();

    try {
      // Step 1: Extract observations from all pending content
      const obsResult = await processAllPendingContent(user.id);

      // Step 2: Generate insights from recent observations
      const insightResult = await generateInsightsForAllGoals(user.id, daysBack);

      // Mark pipeline run as completed
      if (pipelineRun) {
        await supabaseAdmin
          .from(Tables.PIPELINE_RUNS)
          .update({
            status: 'completed',
            observations_created: obsResult.totalObservations,
            insights_created: insightResult.totalCreated,
            completed_at: new Date().toISOString(),
          })
          .eq('id', pipelineRun.id);
      }

      res.json({
        success: true,
        data: {
          pipelineRunId: pipelineRun?.id,
          observations: {
            contentProcessed: obsResult.contentProcessed,
            totalObservations: obsResult.totalObservations,
            byGoal: obsResult.byGoal,
          },
          insights: {
            totalCreated: insightResult.totalCreated,
            totalUpdated: insightResult.totalUpdated,
            byGoal: insightResult.byGoal,
          },
        },
        message: `Pipeline complete. ${obsResult.totalObservations} observations, ${insightResult.totalCreated} new insights, ${insightResult.totalUpdated} updated insights.`,
      });
    } catch (err) {
      if (pipelineRun) {
        await supabaseAdmin
          .from(Tables.PIPELINE_RUNS)
          .update({
            status: 'failed',
            error_message: err instanceof Error ? err.message : 'Unknown error',
            completed_at: new Date().toISOString(),
          })
          .eq('id', pipelineRun.id);
      }
      throw err;
    }
  } catch (error) {
    console.error('Full pipeline error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Pipeline failed',
    });
  }
});

// GET /pipeline/runs - List pipeline run history
pipelineRouter.get('/runs', async (req: Request, res: Response) => {
  try {
    const user = (req as any).user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const limit = req.query.limit ? parseInt(req.query.limit as string) : 20;

    const { data, error } = await supabaseAdmin
      .from(Tables.PIPELINE_RUNS)
      .select('*')
      .eq('user_id', user.id)
      .order('started_at', { ascending: false })
      .limit(limit);

    if (error) throw error;

    res.json({
      success: true,
      data: data || [],
    });
  } catch (error) {
    console.error('List pipeline runs error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Failed to list runs',
    });
  }
});
