-- 006: sign out everywhere.
--
-- Session tokens last 30 days and could not be cancelled early. Each account
-- now carries a session_epoch, stamped into every token it issues; bumping it
-- ends every existing session at once (a lost phone, a shared device).
--
-- Additive: one column with a default. Apply BEFORE deploying the backend that
-- reads it.

ALTER TABLE users ADD COLUMN IF NOT EXISTS session_epoch INTEGER NOT NULL DEFAULT 0;

COMMENT ON COLUMN users.session_epoch IS
    'Bumped by "sign out everywhere"; a token whose epoch differs is rejected.';
