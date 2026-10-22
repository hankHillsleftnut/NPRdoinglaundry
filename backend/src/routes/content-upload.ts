import type { Request, RequestHandler, Response } from 'express';
import { UploadContentSchema } from '../types/index.js';
import { INTEGRATION_CATALOG, type IntegrationCatalogEntry } from '../services/integration-catalog.js';
import type { InsertOutcome } from '../services/content-insert.js';
import type { DedupInput } from '../services/dedup-key.js';
import { explicitKeyOf } from '../services/dedup-key.js';

/** Clients send a UUID (36 characters); anything far longer is refused, not stored. */
export const MAX_IDEMPOTENCY_KEY_LENGTH = 128;

/**
 * What `POST /content` needs from the outside world, passed in so the route is
 * tested over HTTP without a database or an agent (routes/content.ts wires the
 * real ones).
 */
export interface UploadDeps {
  /** The data_sources id for a content type, if there is one. */
  findDataSourceId(contentType: string): Promise<string | null>;
  /** Stores the row once (services/content-insert.ts). */
  insert(row: Record<string, unknown> & { user_id: string }, dedup: DedupInput): Promise<InsertOutcome>;
  /** Best effort: records that the user's provider is connected. */
  markConnected(userId: string, provider: IntegrationCatalogEntry): Promise<void>;
  /** Hands the new row to the agent, after the response is sent. */
  startIngest(userId: string, rawContentId: string): void;
  now?: () => Date;
}

const EMPTY_RESULT = {
  insightIds: [],
  insightCount: 0,
  observationsCreated: 0,
  insightsCreated: 0,
  goalCandidatesCreated: 0,
  agentTraceId: null,
  processingError: null,
};

export function uploadContentHandler(deps: UploadDeps): RequestHandler {
  return async (req: Request, res: Response) => {
    try {
      const user = req.user;
      if (!user) {
        res.status(401).json({ success: false, error: 'Unauthorized' });
        return;
      }

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
      // Measured on the key actually used: the trimmed header, else client_event_id.
      const explicitKey = explicitKeyOf(idempotencyKey, metadata);
      if (explicitKey && explicitKey.length > MAX_IDEMPOTENCY_KEY_LENGTH) {
        res.status(400).json({ success: false, error: 'Idempotency-Key too long' });
        return;
      }

      const sourceId = await deps.findDataSourceId(contentType);

      // Insert raw content -- once. A repeat of something already stored is
      // recognised and answered with the original row, without a second copy and
      // without a second ingest run. See services/content-insert.ts.
      const effectiveDate = contentDate || (deps.now?.() ?? new Date()).toISOString();

      let outcome: InsertOutcome;
      try {
        outcome = await deps.insert(
          {
            user_id: user.id,
            content_type: contentType,
            content,
            content_date: effectiveDate,
            metadata: metadata || {},
            source_id: sourceId,
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
        res.status(500).json({ success: false, error: 'Failed to store content' });
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
          data: { rawContentId: outcome.id, deduplicated: true, dedupReason: outcome.strategy, ...EMPTY_RESULT },
          message: 'Already stored; returning the existing entry',
        });
        return;
      }

      // Best-effort bridge into the durable integration ledger.
      const provider = INTEGRATION_CATALOG.find((entry) => entry.id === contentType);
      if (provider) await deps.markConnected(user.id, provider);

      // Return immediately — agent ingestion runs in the background.
      // iOS does not need to wait for extraction to finish before proceeding.
      res.status(202).json({
        success: true,
        data: { rawContentId: outcome.id, ...EMPTY_RESULT },
        message: 'Content stored; agent ingestion running in background',
      });

      deps.startIngest(user.id, outcome.id);
    } catch (error) {
      console.error('Content upload error:', error);
      res.status(500).json({ success: false, error: 'Failed to process content' });
    }
  };
}
