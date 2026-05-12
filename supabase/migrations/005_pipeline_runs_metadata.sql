-- ============================================
-- 005 — pipeline_runs metadata for v2 observability
-- ============================================
-- The v2 podcast orchestrator writes a structured rollup of the run into
-- `metadata` on completion (stage durations, Stage 2 agent stop reason,
-- ordered tool-call summary, counts). This gives us a single-row debug view
-- per episode without having to join agent_tool_traces, and makes ad-hoc
-- analytics (e.g. "how often did Stage 2 hit max_steps?") straightforward.
--
-- agent_tool_traces continues to hold the per-call detail (see migration 004).

ALTER TABLE pipeline_runs
    ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS idx_pipeline_runs_metadata_gin
    ON pipeline_runs USING GIN (metadata);
