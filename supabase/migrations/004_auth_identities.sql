-- Migration 004: Split identity from account
--
-- WHY
-- ---
-- Until now `users.apple_user_id` was the only identity anchor: the single
-- column that answered "which human is this?". That makes an account a hostage
-- of one sign-in method. Adding Google sign-in would mint a *second* users row
-- for the same person and orphan everything hanging off the first one
-- (raw_content, insight_units, goals, observations, insights, podcast_episodes,
-- integration_connections, ... all `user_id REFERENCES users(id) ON DELETE
-- CASCADE`). A user who changed their Apple ID would suffer the same silent,
-- total loss of their second brain.
--
-- This migration introduces `auth_identities`: a many-to-one table of
-- (provider, provider_subject) credentials pointing at one durable `users.id`.
-- The account becomes the stable thing; sign-in methods become attachable and
-- detachable facts about it.
--
-- ============================================
-- AUTH IDENTITIES TABLE
-- One row per (provider, subject) credential. Many rows may point at one user,
-- which is the entire point: link Google to an existing Apple account and the
-- user's data stays exactly where it is.
-- ============================================
CREATE TABLE IF NOT EXISTS auth_identities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    -- Constrained and lowercase on purpose: 'Apple' and 'apple' would not
    -- collide under the unique index below, quietly giving one human two
    -- accounts — the exact failure this table exists to prevent. Adding a
    -- provider is a deliberate migration.
    provider TEXT NOT NULL CHECK (provider IN ('apple', 'google', 'dev')),
    provider_subject TEXT NOT NULL,
    email TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ DEFAULT NOW()
);

-- The load-bearing constraint. A given credential belongs to exactly one
-- account, forever. The backend relies on this for its upsert: concurrent
-- first sign-ins for the same subject collide here rather than racing to
-- create two users.
CREATE UNIQUE INDEX IF NOT EXISTS idx_auth_identities_provider_subject
    ON auth_identities(provider, provider_subject);

-- "Which sign-in methods does this account have?" — used by account settings
-- and by the link flow's conflict checks.
CREATE INDEX IF NOT EXISTS idx_auth_identities_user_id
    ON auth_identities(user_id);

COMMENT ON TABLE auth_identities IS
    'Sign-in credentials (provider + subject) attached to a user account. A user may have many; the account, not the credential, is the durable identity.';
COMMENT ON COLUMN auth_identities.provider IS
    'Identity provider key: apple, google, dev.';
COMMENT ON COLUMN auth_identities.provider_subject IS
    'Stable subject identifier issued by the provider (Apple/Google JWT `sub`).';
COMMENT ON COLUMN auth_identities.last_seen_at IS
    'Updated every time this specific credential is used to sign in.';

-- ============================================
-- BACKFILL
-- Every existing account keeps working with zero user-visible change: each
-- current users.apple_user_id becomes an 'apple' identity row pointing at the
-- same users.id, so the new (provider, subject) -> users.id lookup resolves
-- exactly the same account the old apple_user_id lookup did.
--
-- created_at/last_seen_at are seeded from the user row so the new table does
-- not claim every historical account was created the moment this migration ran.
-- ON CONFLICT DO NOTHING keeps the migration re-runnable.
-- ============================================
INSERT INTO auth_identities (user_id, provider, provider_subject, email, created_at, last_seen_at)
SELECT
    u.id,
    'apple',
    u.apple_user_id,
    u.email,
    COALESCE(u.created_at, NOW()),
    COALESCE(u.updated_at, u.created_at, NOW())
FROM users u
WHERE u.apple_user_id IS NOT NULL
ON CONFLICT (provider, provider_subject) DO NOTHING;

-- ============================================
-- DEPRECATE users.apple_user_id (staged, not dropped)
--
-- Why the column stays for now:
--   1. Dropping a column and rewriting its readers in one migration means a
--      deploy where either half can fail alone. Old backend code still running
--      during a rolling deploy would 500 on every sign-in the instant the
--      column vanished.
--   2. It is the rollback path. While the column exists and new Apple sign-ups
--      keep dual-writing it, reverting the backend to the pre-004 build still
--      resolves users correctly.
--   3. GET /admin/users still selects it.
--
-- So: drop only NOT NULL, which is what actually blocks progress — a
-- Google-only or dev user must be able to exist with no Apple ID at all. The
-- UNIQUE index stays as a safety net during the staging window (Postgres
-- permits many NULLs under a unique index, so it does not impede new rows).
--
-- A LATER migration drops the column, once nothing reads it:
--   ALTER TABLE users DROP COLUMN apple_user_id;
-- Do not fold that into this file.
-- ============================================
ALTER TABLE users ALTER COLUMN apple_user_id DROP NOT NULL;

COMMENT ON COLUMN users.apple_user_id IS
    'DEPRECATED: superseded by auth_identities (provider=''apple''). Retained temporarily for rollback safety and dual-written on new Apple sign-ups; do not add new readers. Dropped in a later migration.';

-- ============================================
-- ROW LEVEL SECURITY
-- The backend uses the service-role key and bypasses RLS entirely; this policy
-- exists so that any anon/authenticated client cannot enumerate other people's
-- sign-in methods. Deliberately no INSERT/UPDATE/DELETE policy: identities are
-- only ever written by the backend.
--
-- NOTE: `users.id` is a `uuid_generate_v4()` of our own, unrelated to Supabase
-- GoTrue's `auth.uid()`, so this predicate never matches and the policy is
-- deny-all in practice. That is the correct outcome here, and it matches the
-- existing (equally inert) policies in 001 and 003. Do not "fix" it into a
-- real grant without first reconciling the two id spaces.
-- ============================================
ALTER TABLE auth_identities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own identities" ON auth_identities;
CREATE POLICY "Users can view own identities" ON auth_identities
    FOR SELECT USING (user_id = auth.uid());
