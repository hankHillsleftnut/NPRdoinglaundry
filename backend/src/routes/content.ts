import { Router, Request, Response } from 'express';
import { supabaseAdmin, Tables } from '../utils/supabase.js';
import { runAgentIngest } from '../services/agent-client.js';
import { UploadContentSchema } from '../types/index.js';
import { INTEGRATION_CATALOG } from '../services/integration-catalog.js';
import { insertRawContent, type InsertClient, type InsertOutcome } from '../services/content-insert.js';
import { handOffToAgent } from '../services/agent-handoff.js';

export const contentRouter = Router();

/** Clients send a UUID (36 characters); anything far longer is refused, not stored. */
export const MAX_IDEMPOTENCY_KEY_LENGTH = 128;

/**
 * THE AGENT OWNS A ROW'S STATUS -- why this route never writes
 * `processing_status` once a row is handed off.
 *
 * The agent owns a row's status from the moment it is inserted as `pending`.
 * On success it marks it `completed`. On failure it classifies the error and,
 * if it is worth retrying, puts the row back to `pending` with an attempt count
 * and a time to try again (retry-policy.ts in the agent).
 *
 * This route used to write status itself, after the agent, and both writes were
 * wrong:
 *
 * - On failure it wrote a bare `failed`: no attempt count, no retry time, no
 *   failure kind. That overwrote the agent's correct, scheduled-for-retry state
 *   with a permanent dead end. It is the exact signature of all 2,024 rows found
 *   stranded in production on 18 October 2026, and the reason none of them was
 *   ever retried -- the retry system was built, and this line hid every failure
 *   from it.
 * - On success it wrote `completed` regardless of what the agent did, so a row
 *   the agent had skipped or not reached was stamped as done and never looked at
 *   again.
 *
 * If the agent cannot be reached at all, the row simply stays `pending`. The
 * agent's own run picks up every pending row, including ones older than its
 * usual window, so nothing left this way is lost.
 */
// Enforced structurally: the upload path hands off through handOffToAgent(),
// which is never given a database client and so cannot write status at all.

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

    const idempotencyKey = req.header('Idempotency-Key') ?? null;
    if (idempotencyKey && idempotencyKey.length > MAX_IDEMPOTENCY_KEY_LENGTH) {
      res.status(400).json({ success: false, error: 'Idempotency-Key too long' });
      return;
    }

    // Get data source ID if exists
    const { data: dataSource } = await supabaseAdmin
      .from(Tables.DATA_SOURCES)
      .select('id')
      .eq('name', contentType)
      .single();

    // Insert raw content -- once. A repeat of something already stored is
    // recognised and answered with the original row, without a second copy and
    // without a second ingest run. See services/content-insert.ts.
    const effectiveDate = contentDate || new Date().toISOString();

    let outcome: InsertOutcome;
    try {
      outcome = await insertRawContent(
        // The real client is far richer than the slice insertRawContent uses;
        // the cast is confined to this one boundary.
        supabaseAdmin as unknown as InsertClient,
        Tables.RAW_CONTENT,
        {
          user_id: user.id,
          content_type: contentType,
          content,
          content_date: effectiveDate,
          metadata: metadata || {},
          source_id: dataSource?.id || null,
          processing_status: 'pending',
        },
        {
          userId: user.id,
          contentType,
          content,
          contentDate: effectiveDate,
          metadata: metadata || {},
          idempotencyKey,
        },
      );
    } catch (insertError) {
      console.error('Insert error:', insertError);
      res.status(500).json({
        success: false,
        error: 'Failed to store content',
      });
      return;
    }

    if (outcome.kind === 'key_reused') {
      // Same key, different body: a client bug. Nothing stored, no ingest.
      res.status(409).json({ success: false, error: 'Idempotency-Key reused with a different body' });
      return;
    }

    if (outcome.kind === 'duplicate') {
      // 200, not 409. The iOS "resync all" button replays every local entry
      // and counts any error as a failure, so a 409 would make a perfectly
      // healthy resync report hundreds of failures. A replay of the original is
      // the honest answer, and the standard one for idempotent requests.
      //
      // Deliberately no ingest run here: nothing new arrived.
      res.setHeader('Idempotency-Replayed', 'true');
      res.status(200).json({
        success: true,
        data: {
          rawContentId: outcome.id,
          deduplicated: true,
          dedupReason: outcome.strategy,
          insightIds: [],
          insightCount: 0,
          observationsCreated: 0,
          insightsCreated: 0,
          goalCandidatesCreated: 0,
          agentTraceId: null,
          processingError: null,
        },
        message: 'Already stored; returning the existing entry',
      });
      return;
    }

    const rawContent = { id: outcome.id };

    // Best-effort bridge into the durable integration ledger. Content ingestion
    // must continue if the integration migration has not been deployed yet.
    const provider = INTEGRATION_CATALOG.find((entry) => entry.id === contentType);
    if (provider) {
      const now = new Date().toISOString();
      const { error: connectionError } = await supabaseAdmin
        .from(Tables.INTEGRATION_CONNECTIONS)
        .upsert({
          user_id: user.id,
          provider_id: provider.id,
          collection_mode: provider.collectionMode,
          status: 'connected',
          connected_at: now,
          last_verified_at: now,
          disconnected_at: null,
          metadata: {
            registration_source: 'content_upload',
          },
        }, { onConflict: 'user_id,provider_id' });

      if (connectionError) {
        console.warn(`Could not update integration connection for ${provider.id}: ${connectionError.message}`);
      }
    }

    // Return immediately — agent ingestion runs in the background.
    // iOS does not need to wait for extraction to finish before proceeding.
    res.status(202).json({
      success: true,
      data: {
        rawContentId: rawContent.id,
        insightIds: [],
        insightCount: 0,
        observationsCreated: 0,
        insightsCreated: 0,
        goalCandidatesCreated: 0,
        agentTraceId: null,
        processingError: null,
      },
      message: 'Content stored; agent ingestion running in background',
    });

    // Fire-and-forget: hand the row to the agent, which owns its status from
    // here. See "THE AGENT OWNS A ROW'S STATUS" at the top of this file.
    setImmediate(() => {
      void handOffToAgent(runAgentIngest, { userId: user.id, rawContentIds: [rawContent.id] });
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

    // Reset status to pending -- unless a run is reading it right now. Resetting
    // a row mid-run lets a second run lease it, and both process it.
    await supabaseAdmin
      .from(Tables.RAW_CONTENT)
      .update({
        processing_status: 'pending',
        processing_error: null,
      })
      .eq('id', content.id)
      .neq('processing_status', 'processing');

    const result = await runAgentIngest({
      userId: user.id,
      rawContentIds: [content.id],
      notes: 'Triggered by retrospect-api /content/:id/reprocess',
    });
    // No status write here: the agent has already recorded what really happened
    // to this row. See "THE AGENT OWNS A ROW'S STATUS" at the top of this file.

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
