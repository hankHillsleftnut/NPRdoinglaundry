import { Router, Request, Response } from 'express';
import { supabaseAdmin, Tables } from '../utils/supabase.js';
import { runAgentIngest } from '../services/agent-client.js';
import { UploadContentSchema } from '../types/index.js';
import { INTEGRATION_CATALOG } from '../services/integration-catalog.js';

export const contentRouter = Router();

interface StoredCapture {
  rawContentId: string;
  /** False when this request lost the idempotency race and an earlier copy of the note already existed. */
  wasInserted: boolean;
}

interface CaptureInput {
  userId: string;
  clientUuid?: string;
  contentType: string;
  content: string;
  contentDate?: string;
  metadata?: Record<string, unknown>;
  sourceId: string | null;
}

/**
 * Postgres' own "function does not exist". Deliberately narrow: PostgREST's
 * PGRST202 is NOT treated as missing, because it also fires on a stale schema
 * cache and on an argument mismatch — both against a database where migration 006
 * IS applied. Falling back there would write client_uuid-less rows that sit
 * outside the unique index, so every client retry would create a new row and
 * re-run ingestion. A retryable error is much cheaper than that: the note is
 * already safe on the device.
 */
const MISSING_FUNCTION_CODE = '42883';

class SchemaCacheError extends Error {}
class IngestClaimError extends Error {}

/**
 * Idempotent capture. Delegates to the upsert_raw_content function because the
 * unique index behind it is partial (client_uuid IS NOT NULL) and PostgREST's
 * on_conflict parameter cannot name an index predicate.
 */
async function storeIdempotently(input: CaptureInput): Promise<StoredCapture | null> {
  const { data, error } = await supabaseAdmin
    .rpc('upsert_raw_content', {
      p_user_id: input.userId,
      p_client_uuid: input.clientUuid,
      p_content_type: input.contentType,
      p_content: input.content,
      p_content_date: input.contentDate || new Date().toISOString(),
      p_metadata: input.metadata || {},
      p_source_id: input.sourceId,
    })
    .single<{ raw_content_id: string; capture_status: string; was_inserted: boolean }>();

  if (error) {
    if (error.code === MISSING_FUNCTION_CODE) {
      // Migration 006 genuinely has not reached this database. Losing the note is
      // worse than storing it twice, so fall back rather than fail the upload.
      console.warn('upsert_raw_content missing (migration 006 not applied); falling back to insert');
      return storeDirectly({ ...input, clientUuid: undefined });
    }
    if (error.code === 'PGRST202') {
      // Stale schema cache or an argument mismatch. Tell the client to retry —
      // its local copy is durable and the cache reload is usually seconds away.
      console.error('upsert_raw_content not resolvable by PostgREST:', error.message);
      throw new SchemaCacheError('Content store is reloading; retry shortly');
    }
    console.error('Idempotent insert error:', error);
    return null;
  }

  return data
    ? { rawContentId: data.raw_content_id, wasInserted: data.was_inserted }
    : null;
}

/** Legacy path for callers that send no clientUuid. Every upload is a new row. */
async function storeDirectly(input: CaptureInput): Promise<StoredCapture | null> {
  const { data, error } = await supabaseAdmin
    .from(Tables.RAW_CONTENT)
    .insert({
      user_id: input.userId,
      content_type: input.contentType,
      content: input.content,
      content_date: input.contentDate || new Date().toISOString(),
      metadata: input.metadata || {},
      source_id: input.sourceId,
      processing_status: 'pending',
    })
    .select('id')
    .single();

  if (error || !data) {
    console.error('Insert error:', error);
    return null;
  }

  return { rawContentId: data.id, wasInserted: true };
}

/**
 * Take ownership of a row's agent ingestion. Returns false when another request
 * is already ingesting it or has finished, which is how a retried upload avoids
 * re-running extraction over a note that has already been through the pipeline.
 *
 * `force` also claims a 'completed' row, for the explicit reprocess endpoint.
 */
async function claimForIngest(rawContentId: string, force = false): Promise<boolean> {
  const { data, error } = await supabaseAdmin.rpc('claim_raw_content_ingest', {
    p_raw_content_id: rawContentId,
    p_force: force,
  });

  if (error) {
    if (error.code === MISSING_FUNCTION_CODE) {
      // Pre-migration behaviour: ingest unconditionally, as this route always did.
      return true;
    }
    console.error('Ingestion claim error:', error);
    throw new IngestClaimError('Could not claim content for ingestion; retry shortly');
  }

  return data === true;
}

/**
 * Run the agent over a row already claimed by this request, recording the outcome.
 */
async function ingestClaimed(userId: string, rawContentId: string, notes?: string): Promise<void> {
  try {
    await runAgentIngest({ userId, rawContentIds: [rawContentId], notes });
    await supabaseAdmin
      .from(Tables.RAW_CONTENT)
      .update({ processing_status: 'completed', processing_error: null, processed_at: new Date().toISOString() })
      .eq('id', rawContentId);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error('Background agent ingestion error:', err);
    await supabaseAdmin
      .from(Tables.RAW_CONTENT)
      .update({ processing_status: 'failed', processing_error: msg })
      .eq('id', rawContentId);
  }
}

/**
 * Heal rows abandoned before or during ingestion by a process that died.
 * The client was already told 202 and will never resend, so nothing else would
 * pick these up. Piggy-backing on the next capture keeps the recovery free of a
 * cron or a server-lifecycle hook.
 */
async function recoverStaleIngests(userId: string): Promise<void> {
  const { data, error } = await supabaseAdmin.rpc('stale_raw_content_ingests', {
    p_user_id: userId,
  });

  if (error) {
    if (error.code !== MISSING_FUNCTION_CODE) {
      console.warn(`Could not scan for stale ingests: ${error.message}`);
    }
    return;
  }

  const stale = (data as Array<{ raw_content_id: string }> | null) || [];
  for (const row of stale) {
    console.warn(`Recovering stale ingest for raw_content ${row.raw_content_id}`);
    if (await claimForIngest(row.raw_content_id)) {
      await ingestClaimed(userId, row.raw_content_id, 'Recovered after an abandoned ingest');
    }
  }
}

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

    const { contentType, content, contentDate, metadata, clientUuid } = validationResult.data;

    // Get data source ID if exists
    const { data: dataSource } = await supabaseAdmin
      .from(Tables.DATA_SOURCES)
      .select('id')
      .eq('name', contentType)
      .single();

    // Store raw content. With a clientUuid the write is idempotent — the same
    // note retried from the iOS queue lands on the same row and comes back 202,
    // never a duplicate and never a 409. Without one we keep the legacy insert
    // so existing callers and integration-sourced content are unaffected.
    const stored = clientUuid
      ? await storeIdempotently({
          userId: user.id,
          clientUuid,
          contentType,
          content,
          contentDate,
          metadata,
          sourceId: dataSource?.id || null,
        })
      : await storeDirectly({
          userId: user.id,
          contentType,
          content,
          contentDate,
          metadata,
          sourceId: dataSource?.id || null,
        });

    if (!stored) {
      res.status(500).json({
        success: false,
        error: 'Failed to store content',
      });
      return;
    }

    const rawContentId = stored.rawContentId;

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

    // Resolve the claim before acknowledging so RPC failures leave the client
    // retrying its durable copy. A legitimate false claim is still a success.
    const claimed = await claimForIngest(rawContentId);

    // Agent ingestion runs in the background after the claim completes.
    // iOS does not need to wait for extraction to finish before proceeding.
    res.status(202).json({
      success: true,
      data: {
        rawContentId,
        clientUuid: clientUuid || null,
        deduplicated: !stored.wasInserted,
        insightIds: [],
        insightCount: 0,
        observationsCreated: 0,
        insightsCreated: 0,
        goalCandidatesCreated: 0,
        agentTraceId: null,
        processingError: null,
      },
      message: stored.wasInserted
        ? 'Content stored; agent ingestion running in background'
        : 'Content already stored; returning existing capture',
    });

    // Fire-and-forget: agent turns raw content into observations/insights.
    // Only the caller that won the claim actually ingests this capture.
    setImmediate(async () => {
      try {
        if (claimed) {
          await ingestClaimed(user.id, rawContentId);
        }
        await recoverStaleIngests(user.id);
      } catch (error) {
        console.error('Background ingestion recovery error:', error);
      }
    });
  } catch (error) {
    if (error instanceof SchemaCacheError || error instanceof IngestClaimError) {
      // 503 so the client's queue keeps the note and retries it.
      res.status(503).json({
        success: false,
        error: error.message,
      });
      return;
    }
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

    // One statement takes the status transition and the claim under a single row
    // lock. A forced claim also accepts 'completed', which is the whole point of
    // this endpoint, but still refuses a row that is genuinely mid-ingest — so a
    // manual reprocess racing a background retry can no longer double-ingest.
    if (!(await claimForIngest(content.id, true))) {
      res.status(409).json({
        success: false,
        error: 'Content is already being processed',
      });
      return;
    }

    let result;
    try {
      result = await runAgentIngest({
        userId: user.id,
        rawContentIds: [content.id],
        notes: 'Triggered by retrospect-api /content/:id/reprocess',
      });
    } catch (err) {
      // Release the claim so the row is reprocessable immediately rather than
      // sitting in 'processing' until the stale window expires.
      const msg = err instanceof Error ? err.message : String(err);
      await supabaseAdmin
        .from(Tables.RAW_CONTENT)
        .update({ processing_status: 'failed', processing_error: msg })
        .eq('id', content.id);
      throw err;
    }

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
    res.status(error instanceof IngestClaimError ? 503 : 500).json({
      success: false,
      error: error instanceof IngestClaimError ? error.message : 'Failed to reprocess content',
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
