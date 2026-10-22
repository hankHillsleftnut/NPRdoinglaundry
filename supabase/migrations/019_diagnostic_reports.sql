-- ============================================================================
-- 019: diagnostics reports (DG.1) -- number to be confirmed by the integrator
--
-- Goal: a tester can "send a report" of how the app behaved, and we can read
-- it to fix what went wrong (founder, 22 Oct; docs/team/flows/diagnostics.md).
--
-- Why: TestFlight testers' bug reports are only as good as what they can tell
-- us. A report is how the app behaved -- screens, requests, failures, timings,
-- device settings -- never what the person wrote (the door's schema can't
-- carry it), plus an optional note they write to us on purpose.
--
--   diagnostic_reports  one row per report: who sent it, its short reference,
--                       counts, where the bundle is stored, when it expires
--   bucket diagnostics  the bundles themselves, private, under the user's id
-- Kept 30 days, then deleted by the backend's purge job. Rows cascade with the
-- user; the stored bundles are removed by deleteDiagnosticsFor(userId).
--
-- Additive. RLS on; nothing for anon/authenticated; service_role only.
-- Files only: never applied to production by an agent.
-- ============================================================================

CREATE TABLE IF NOT EXISTS diagnostic_reports (
    id            UUID PRIMARY KEY,                 -- the client's report id (its Idempotency-Key)
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reference     TEXT NOT NULL UNIQUE CHECK (reference ~ '^r-[0-9A-HJKMNP-TV-Z]{4}$'),
    body_hash     TEXT NOT NULL,                    -- SHA-256 of the bundle, to tell a retry from a reuse
    storage_path  TEXT NOT NULL,
    size_bytes    INTEGER NOT NULL CHECK (size_bytes >= 0),
    counts        JSONB NOT NULL DEFAULT '{}',      -- events, requests, failures, crashes, hasNote
    app_version   TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at    TIMESTAMPTZ NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_diagnostic_reports_user ON diagnostic_reports(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_diagnostic_reports_expiry ON diagnostic_reports(expires_at);

ALTER TABLE diagnostic_reports ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON diagnostic_reports FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON diagnostic_reports TO service_role;

INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('diagnostics', 'diagnostics', FALSE, 10485760)
ON CONFLICT (id) DO UPDATE SET public = FALSE;
