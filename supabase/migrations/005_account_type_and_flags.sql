-- ============================================
-- 005: Test accounts + per-user feature flags
--
-- Two mechanisms that let the product change in production without
-- affecting live users:
--
--   1. users.account_type — a 'test' account shares the production
--      database and real integrations (so it can exercise real Google /
--      Gmail sync) but is excluded from anything that treats users in
--      aggregate or spends money on their behalf in a batch.
--
--   2. feature_flags / user_feature_flags — a flag can be flipped on for
--      ONE user id in production, so risky global surfaces (LLM prompt
--      versions, pipeline behaviour) can be varied for a single account.
--
-- Resolution precedence (see backend/src/services/feature-flags.ts):
--   per-user override  >  flag default_enabled  >  false
-- Flags always fail CLOSED: unknown key, missing row, or a DB error all
-- resolve to false.
-- ============================================

-- ============================================
-- ACCOUNT TYPE
-- ============================================
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS account_type TEXT NOT NULL DEFAULT 'real';

DO $$
BEGIN
    -- conname is unique per relation, not globally, so scope the check to
    -- `users` — otherwise a same-named constraint on another table would make
    -- this silently skip and leave account_type unconstrained.
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'users_account_type_check'
          AND conrelid = 'users'::regclass
    ) THEN
        ALTER TABLE users
            ADD CONSTRAINT users_account_type_check
            CHECK (account_type IN ('real', 'test'));
    END IF;
END $$;

COMMENT ON COLUMN users.account_type IS
    'real = a live customer. test = a founder-owned throwaway account that shares the production database and real integrations but must be excluded from aggregate stats, analytics, billing/revenue reporting and batch/cron spend.';

-- Aggregate reads filter on account_type = 'real', so index it.
CREATE INDEX IF NOT EXISTS idx_users_account_type ON users(account_type);

-- ============================================
-- FEATURE FLAGS (global definitions)
-- ============================================
CREATE TABLE IF NOT EXISTS feature_flags (
    key TEXT PRIMARY KEY,
    description TEXT,
    -- Default CLOSED. A new flag must never turn a variant on for everyone
    -- the moment it is created; that is the exact failure mode this table
    -- exists to prevent.
    default_enabled BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE feature_flags IS
    'Global flag definitions. default_enabled applies to every user WITHOUT a user_feature_flags override.';

-- ============================================
-- USER FEATURE FLAG OVERRIDES
-- ============================================
CREATE TABLE IF NOT EXISTS user_feature_flags (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    flag_key TEXT NOT NULL REFERENCES feature_flags(key) ON DELETE CASCADE,
    enabled BOOLEAN NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT user_feature_flags_user_flag_unique UNIQUE (user_id, flag_key)
);

COMMENT ON TABLE user_feature_flags IS
    'Per-user overrides. An explicit row (enabled true OR false) always wins over feature_flags.default_enabled.';

CREATE INDEX IF NOT EXISTS idx_user_feature_flags_user_id ON user_feature_flags(user_id);
CREATE INDEX IF NOT EXISTS idx_user_feature_flags_flag_key ON user_feature_flags(flag_key);

-- Reuse the shared updated_at trigger defined in 001_initial_schema.sql
DROP TRIGGER IF EXISTS update_user_feature_flags_updated_at ON user_feature_flags;
CREATE TRIGGER update_user_feature_flags_updated_at
    BEFORE UPDATE ON user_feature_flags
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================
-- feature_flags is global config: the service role reads/writes it, and no
-- client-facing policy is granted (RLS on + zero policies = deny for anon
-- and authenticated, allow for the service role which bypasses RLS).
ALTER TABLE feature_flags ENABLE ROW LEVEL SECURITY;

ALTER TABLE user_feature_flags ENABLE ROW LEVEL SECURITY;

-- A user may READ their own overrides, never write them. Flipping a flag is
-- a founder action performed with the service role.
DROP POLICY IF EXISTS "Users can view own feature flags" ON user_feature_flags;
CREATE POLICY "Users can view own feature flags" ON user_feature_flags
    FOR SELECT USING (user_id = auth.uid());

-- ============================================
-- SEED FLAGS
-- ============================================
-- Both seeded flags gate a surface that currently hits every user at once.
-- Both default to false so production behaviour is byte-identical until a
-- per-user override is inserted.
INSERT INTO feature_flags (key, description, default_enabled) VALUES
    (
        'insight_synthesis_prompt_v2',
        'Use the v2 CBT insight-synthesis system prompt in backend/src/services/insight-synthesis.ts instead of the shipped v1 prompt. The LLM prompt is otherwise global — this flag is the only way to trial a prompt revision on one account in production.',
        false
    ),
    (
        'pipeline_agent_v2',
        'Route this user''s /pipeline/* runs at the v2 agent pipeline behaviour (forwarded to the agent service as featureFlags on the ingest payload) instead of the default pipeline.',
        false
    )
ON CONFLICT (key) DO NOTHING;

-- Example of how a flag is turned on for exactly one account in production
-- (kept as documentation, intentionally not executed):
--
--   INSERT INTO user_feature_flags (user_id, flag_key, enabled)
--   VALUES ('<founder-user-uuid>', 'insight_synthesis_prompt_v2', true)
--   ON CONFLICT (user_id, flag_key)
--   DO UPDATE SET enabled = EXCLUDED.enabled, updated_at = NOW();
