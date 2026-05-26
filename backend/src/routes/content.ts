import { Router, Request, Response } from 'express';
import { supabaseAdmin, Tables } from '../utils/supabase.js';
import { runAgentIngest } from '../services/agent-client.js';
import { UploadContentSchema } from '../types/index.js';

export const contentRouter = Router();

// POST /content - Upload new content for processing
contentRouter.post('/', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    // Validate request body
    const validationResult = UploadContentSchema.safeParse(req.body);
    if (!validationResult.success) {
      res.status(400).json({
        success: false,
        error: 'Invalid request body',
        details: validationResult.error.errors,
      });
      return;
    }

    const { contentType, content, contentDate, metadata } = validationResult.data;

    // Get data source ID if exists
    const { data: dataSource } = await supabaseAdmin
      .from(Tables.DATA_SOURCES)
      .select('id')
      .eq('name', contentType)
      .single();

    // Insert raw content
    const { data: rawContent, error: insertError } = await supabaseAdmin
      .from(Tables.RAW_CONTENT)
      .insert({
        user_id: user.id,
        content_type: contentType,
        content,
        content_date: contentDate || new Date().toISOString(),
        metadata: metadata || {},
        source_id: dataSource?.id || null,
        processing_status: 'pending',
      })
      .select('id')
      .single();

    if (insertError || !rawContent) {
      console.error('Insert error:', insertError);
      res.status(500).json({
        success: false,
        error: 'Failed to store content',
      });
      return;
    }

    // Agent-only path: the backend stores raw content, then asks retrospect-agent
    // to turn that content into observations, insights, and goal candidates.
    let agentResult:
      | Awaited<ReturnType<typeof runAgentIngest>>
      | null = null;
    let agentError: string | null = null;

    try {
      agentResult = await runAgentIngest({
        userId: user.id,
        rawContentIds: [rawContent.id],
      });

      await supabaseAdmin
        .from(Tables.RAW_CONTENT)
        .update({
          processing_status: 'completed',
          processing_error: null,
          processed_at: new Date().toISOString(),
        })
        .eq('id', rawContent.id);
    } catch (err) {
      agentError = err instanceof Error ? err.message : String(err);
      console.error('Agent ingestion error:', err);

      await supabaseAdmin
        .from(Tables.RAW_CONTENT)
        .update({
          processing_status: 'failed',
          processing_error: agentError,
        })
        .eq('id', rawContent.id);
    }

    res.status(201).json({
      success: true,
      data: {
        rawContentId: rawContent.id,
        insightIds: [],
        insightCount: agentResult?.insights_created ?? 0,
        observationsCreated: agentResult?.observations_created ?? 0,
        insightsCreated: agentResult?.insights_created ?? 0,
        goalCandidatesCreated: agentResult?.goal_candidates_created ?? 0,
        agentTraceId: agentResult?.traceId ?? null,
        processingError: agentError,
      },
      message: agentError
        ? 'Content stored; agent ingestion failed and can be retried later'
        : `Agent processed content into ${agentResult?.observations_created ?? 0} observations and ${agentResult?.insights_created ?? 0} insights`,
    });
  } catch (error) {
    console.error('Content upload error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to process content',
    });
  }
});

// GET /content - List raw content entries
contentRouter.get('/', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const limit = Math.min(parseInt(req.query.limit as string) || 50, 100);
    const offset = parseInt(req.query.offset as string) || 0;
    const status = req.query.status as string;

    let query = supabaseAdmin
      .from(Tables.RAW_CONTENT)
      .select('id, content_type, content_date, processing_status, created_at', {
        count: 'exact',
      })
      .eq('user_id', user.id)
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (status) {
      query = query.eq('processing_status', status);
    }

    const { data, error, count } = await query;

    if (error) {
      throw error;
    }

    res.json({
      success: true,
      data: data || [],
      pagination: {
        total: count || 0,
        limit,
        offset,
        hasMore: (count || 0) > offset + limit,
      },
    });
  } catch (error) {
    console.error('List content error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to list content',
    });
  }
});

// GET /content/:id - Get raw content details
contentRouter.get('/:id', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const { data, error } = await supabaseAdmin
      .from(Tables.RAW_CONTENT)
      .select('*')
      .eq('id', req.params.id)
      .eq('user_id', user.id)
      .single();

    if (error || !data) {
      res.status(404).json({
        success: false,
        error: 'Content not found',
      });
      return;
    }

    // Get associated insights
    const { data: insights } = await supabaseAdmin
      .from(Tables.INSIGHT_UNITS)
      .select('id, content, primary_category, is_inferred, sentiment')
      .eq('raw_content_id', data.id);

    res.json({
      success: true,
      data: {
        ...data,
        insights: insights || [],
      },
    });
  } catch (error) {
    console.error('Get content error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get content',
    });
  }
});

// POST /content/:id/reprocess - Reprocess failed content
contentRouter.post('/:id/reprocess', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    // Verify content belongs to user
    const { data: content, error: fetchError } = await supabaseAdmin
      .from(Tables.RAW_CONTENT)
      .select('id, processing_status')
      .eq('id', req.params.id)
      .eq('user_id', user.id)
      .single();

    if (fetchError || !content) {
      res.status(404).json({
        success: false,
        error: 'Content not found',
      });
      return;
    }

    // Reset status to pending
    await supabaseAdmin
      .from(Tables.RAW_CONTENT)
      .update({
        processing_status: 'pending',
        processing_error: null,
      })
      .eq('id', content.id);

    const result = await runAgentIngest({
      userId: user.id,
      rawContentIds: [content.id],
      notes: 'Triggered by retrospect-api /content/:id/reprocess',
    });

    await supabaseAdmin
      .from(Tables.RAW_CONTENT)
      .update({
        processing_status: 'completed',
        processing_error: null,
        processed_at: new Date().toISOString(),
      })
      .eq('id', content.id);

    res.json({
      success: true,
      data: {
        insightIds: [],
        insightCount: result.insights_created,
        observationsCreated: result.observations_created,
        insightsCreated: result.insights_created,
        goalCandidatesCreated: result.goal_candidates_created,
        agentTraceId: result.traceId,
      },
    });
  } catch (error) {
    console.error('Reprocess content error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to reprocess content',
    });
  }
});

// DELETE /content/:id - Delete raw content and associated insights
contentRouter.delete('/:id', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    // Delete raw content (insights will be updated via ON DELETE SET NULL)
    const { error } = await supabaseAdmin
      .from(Tables.RAW_CONTENT)
      .delete()
      .eq('id', req.params.id)
      .eq('user_id', user.id);

    if (error) {
      throw error;
    }

    res.json({
      success: true,
      message: 'Content deleted',
    });
  } catch (error) {
    console.error('Delete content error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to delete content',
    });
  }
});
