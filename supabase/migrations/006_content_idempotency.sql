-- Content capture idempotency
-- Migration 006: a note the user typed can never be lost.
--
-- The iOS client now writes every note to local storage with a client-generated
-- UUID before it touches the network, then drains a retry queue. That means the
-- same POST /content can legitimately arrive many times (offline retry, app
-- relaunch, token refresh). This migration gives the server the key it needs to
-- collapse those retries into exactly one row.

-- ============================================
-- RAW CONTENT - client-supplied idempotency key
-- ============================================
ALTER TABLE raw_content
    ADD COLUMN IF NOT EXISTS client_uuid UUID,
    ADD COLUMN IF NOT EXISTS ingest_claimed_at TIMESTAMPTZ;

COMMENT ON COLUMN raw_content.client_uuid IS
    'Client-generated capture id. Unique per user when present; NULL for server- and integration-sourced rows.';
COMMENT ON COLUMN raw_content.ingest_claimed_at IS
    'When a request claimed this row for agent ingestion. Used to reclaim rows abandoned mid-ingest.';

-- Partial, so every row captured before this migration (client_uuid IS NULL) is
-- untouched and unconstrained. Only client-tagged captures participate in dedupe.
CREATE UNIQUE INDEX IF NOT EXISTS idx_raw_content_user_client_uuid
    ON raw_content (user_id, client_uuid)
    WHERE client_uuid IS NOT NULL;

-- ============================================
-- IDEMPOTENT CAPTURE
-- ============================================
-- PostgREST cannot target a PARTIAL unique index: its on_conflict parameter
-- carries only column names, and Postgres refuses to infer a partial index
-- without its predicate. So the insert lives here, where the predicate can be
-- spelled out, and the route calls this instead of .upsert().
--
-- The conflict path is a deliberate no-op write. A retry carries the same note
-- the user already typed, so the stored content, metadata and processing_status
-- must survive untouched; the DO UPDATE exists only to make the pre-existing row
-- returnable. was_inserted (via the xmax system column, which is zero only on a
-- freshly inserted tuple) is reported back to the client as `deduplicated`; the
-- actual guard against double ingestion is claim_raw_content_ingest below.
CREATE OR REPLACE FUNCTION upsert_raw_content(
    p_user_id UUID,
    p_client_uuid UUID,
    p_content_type TEXT,
    p_content TEXT,
    p_content_date TIMESTAMPTZ,
    p_metadata JSONB,
    p_source_id UUID
)
RETURNS TABLE (
    raw_content_id UUID,
    capture_status TEXT,
    was_inserted BOOLEAN
)
LANGUAGE sql
AS $$
    INSERT INTO raw_content (
        user_id,
        client_uuid,
        content_type,
        content,
        content_date,
        metadata,
        source_id,
        processing_status
    )
    VALUES (
        p_user_id,
        p_client_uuid,
        p_content_type,
        p_content,
        COALESCE(p_content_date, NOW()),
        COALESCE(p_metadata, '{}'::jsonb),
        p_source_id,
        'pending'
    )
    ON CONFLICT (user_id, client_uuid) WHERE client_uuid IS NOT NULL
    DO UPDATE SET user_id = raw_content.user_id
    RETURNING raw_content.id, raw_content.processing_status, (raw_content.xmax = 0);
$$;

-- ============================================
-- INGESTION CLAIM
-- ============================================
-- Single-statement claim: the first caller to move a row out of 'pending' wins
-- and runs runAgentIngest, everyone else is told to stand down. This is what
-- stops a retried request from re-ingesting a note that is already in flight or
-- already completed. 'failed' is reclaimable because nothing is running for it;
-- 'processing' is reclaimable only once the claim has gone stale, which covers a
-- server that died mid-ingest. p_force additionally accepts 'completed', which is
-- what /content/:id/reprocess needs — folding the status reset into this single
-- statement keeps the transition and the claim under one row lock.
--
-- Scope note: this guards the two /content paths. Other runAgentIngest callers
-- (admin, pipeline, goals) do not take a claim, so the guarantee is route-local.
-- Adding a parameter would leave an older overload resolvable and ambiguous.
DROP FUNCTION IF EXISTS claim_raw_content_ingest(UUID, INTERVAL);

CREATE OR REPLACE FUNCTION claim_raw_content_ingest(
    p_raw_content_id UUID,
    p_force BOOLEAN DEFAULT false,
    p_stale_after INTERVAL DEFAULT '15 minutes'
)
RETURNS BOOLEAN
LANGUAGE sql
AS $$
    WITH claimed AS (
        UPDATE raw_content
        SET processing_status = 'processing',
            processing_error = NULL,
            ingest_claimed_at = NOW()
        WHERE id = p_raw_content_id
          AND (
                -- COALESCE because processing_status is nullable; a NULL-status
                -- row must behave like 'pending' rather than become unclaimable.
                COALESCE(processing_status, 'pending') IN ('pending', 'failed')
             OR (p_force AND COALESCE(processing_status, 'pending') = 'completed')
             OR (
                    processing_status = 'processing'
                AND COALESCE(ingest_claimed_at, created_at) < NOW() - p_stale_after
                )
          )
        RETURNING id
    )
    SELECT EXISTS (SELECT 1 FROM claimed);
$$;

-- ============================================
-- STALE CLAIM RECOVERY
-- ============================================
-- A process that dies mid-ingest (redeploy, OOM, SIGTERM) leaves a row in
-- 'processing' forever. The iOS client has already been told 202 and will never
-- POST that note again, so nothing would re-trigger the claim. This returns those
-- abandoned rows so a later request can heal them opportunistically — the note
-- itself was never at risk, but without this it never becomes observations.
CREATE OR REPLACE FUNCTION stale_raw_content_ingests(
    p_user_id UUID,
    p_limit INT DEFAULT 5,
    p_stale_after INTERVAL DEFAULT '15 minutes'
)
RETURNS TABLE (raw_content_id UUID)
LANGUAGE sql
AS $$
    SELECT id
    FROM raw_content
    WHERE user_id = p_user_id
      AND processing_status = 'processing'
      AND COALESCE(ingest_claimed_at, created_at) < NOW() - p_stale_after
    ORDER BY created_at
    LIMIT p_limit;
$$;

-- These functions take p_user_id / a bare row id and are meant for the service
-- role only. Keep them off the anon and authenticated roles so they cannot be
-- called directly to read or write rows against another user's account.
REVOKE ALL ON FUNCTION upsert_raw_content(UUID, UUID, TEXT, TEXT, TIMESTAMPTZ, JSONB, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION claim_raw_content_ingest(UUID, BOOLEAN, INTERVAL) FROM PUBLIC;
REVOKE ALL ON FUNCTION stale_raw_content_ingests(UUID, INT, INTERVAL) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION upsert_raw_content(UUID, UUID, TEXT, TEXT, TIMESTAMPTZ, JSONB, UUID) TO service_role;
GRANT EXECUTE ON FUNCTION claim_raw_content_ingest(UUID, BOOLEAN, INTERVAL) TO service_role;
GRANT EXECUTE ON FUNCTION stale_raw_content_ingests(UUID, INT, INTERVAL) TO service_role;
