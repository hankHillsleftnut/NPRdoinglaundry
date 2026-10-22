-- ============================================================================
-- 026: the daily brief is on by default (founder, 22 Oct)
--      (026: the next free backend number; 021-025 are on main or landing)
--
-- Goal: Beta 1 testers get the brief without finding a switch. The brief's
-- switch, users.daily_brief_enabled, was added by the brain's migration 128
-- with DEFAULT false; from now on a new person starts switched on, and
-- everyone who exists today is switched on once. PUT /v2/briefs/enabled false
-- still switches it off, and stays off.
--
-- ADD COLUMN IF NOT EXISTS makes this safe where 128 hasn't run (the backend's
-- own test database): there it creates the column with the new default; in
-- production, where 128 has run, it only changes the default and backfills.
--
-- Additive. Files only: never applied to production by an agent.
-- ============================================================================

ALTER TABLE users ADD COLUMN IF NOT EXISTS daily_brief_enabled BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE users ALTER COLUMN daily_brief_enabled SET DEFAULT true;
UPDATE users SET daily_brief_enabled = true WHERE daily_brief_enabled = false;
