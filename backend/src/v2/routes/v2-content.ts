/**
 * POST /v2/content
 *   Upload raw content (voice transcript, text entry, doc, etc.) and kick off
 *   the v2 single-LLM-call ingestion. Synchronous — returns observations,
 *   insights, and suggested_goals counts when done.
 *
 *   Behavior mirrors legacy /content shape so the iOS client only has to flip
 *   the base path when we're ready to switch.
 */

import { Router, Request, Response } from 'express';
import { supabaseAdmin, Tables } from '../../utils/supabase.js';
import { UploadContentSchema } from '../../types/index.js';
import { runV2Ingestion } from '../ingestion/run-ingestion.js';

export const v2ContentRouter = Router();

v2ContentRouter.post('/', async (req: Request, res: Response) => {
  try {
    const user = req.user;
    if (!user) {
      res.status(401).json({ success: false, error: 'Unauthorized' });
      return;
    }

    const validation = UploadContentSchema.safeParse(req.body);
    if (!validation.success) {
      res.status(400).json({
        success: false,
        error: 'Invalid request body',
        details: validation.error.errors,
      });
      return;
    }

    const { contentType, content, contentDate, metadata } = validation.data;

    const { data: dataSource } = await supabaseAdmin
      .from(Tables.DATA_SOURCES)
      .select('id')
      .eq('name', contentType)
      .maybeSingle();

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
      console.error('[v2:content] insert error:', insertError);
      res.status(500).json({ success: false, error: 'Failed to store content' });
      return;
    }

    const result = await runV2Ingestion({
      userId: user.id,
      rawContentIds: [rawContent.id as string],
    });

    res.json({
      success: true,
      data: {
        rawContentId: rawContent.id,
        pipelineRunId: result.pipelineRunId,
        observationsCreated: result.observationsCreated,
        insightsCreated: result.insightsCreated,
        suggestedGoalsCreated: result.suggestedGoalsCreated,
      },
    });
  } catch (err) {
    console.error('[v2:content] error:', err);
    res.status(500).json({
      success: false,
      error: err instanceof Error ? err.message : 'v2 ingestion failed',
    });
  }
});
