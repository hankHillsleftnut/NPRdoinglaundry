-- ============================================================================
-- 007: invite-only access -- the access state, invites, the waitlist (BE0.12)
--
-- Goal: you get in only through an invite link; the founder approves each
-- waitlister; every approved person gets three single-use invites of their
-- own; existing users are grandfathered (founder, 21 Oct; contract 00 §4).
--
-- Why: nothing today stops a new sign-in from using everything. This adds:
--   users.access  waitlisted | approved | member | staff | suspended. Every
--                 user that exists when this runs becomes a member first;
--                 only then does the default (waitlisted) apply to new rows.
--   invites       single-use codes, stored as a SHA-256 hash; the code itself
--                 is kept encrypted only while unused, so "your invites" can
--                 show the link again, and cleared at use or revoke
--   waitlist      people asking to get in, from the app or the website
--
-- Additive. RLS on; nothing for anon/authenticated; service_role only.
-- Files only: never applied to production by an agent.
-- ============================================================================

-- Grandfather everyone who exists now, then make waitlisted the default.
ALTER TABLE users ADD COLUMN IF NOT EXISTS access TEXT;
UPDATE users SET access = 'member' WHERE access IS NULL;
ALTER TABLE users ALTER COLUMN access SET DEFAULT 'waitlisted';
ALTER TABLE users ALTER COLUMN access SET NOT NULL;
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'users_access_check') THEN
        ALTER TABLE users ADD CONSTRAINT users_access_check
            CHECK (access IN ('waitlisted', 'approved', 'member', 'staff', 'suspended'));
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS invites (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code_hash        TEXT NOT NULL UNIQUE,
    code_ciphertext  TEXT,
    kind             TEXT NOT NULL CHECK (kind IN ('founder', 'member', 'review')),
    owner_user_id    UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    used_by_user_id  UUID REFERENCES users(id) ON DELETE SET NULL,
    used_at          TIMESTAMPTZ,
    revoked_at       TIMESTAMPTZ,
    expires_at       TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_invites_owner ON invites(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_invites_used_by ON invites(used_by_user_id);

CREATE TABLE IF NOT EXISTS waitlist (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source      TEXT NOT NULL CHECK (source IN ('app', 'web')),
    user_id     UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    email       TEXT,
    name        TEXT,
    reason      TEXT CHECK (reason IS NULL OR length(reason) <= 280),
    status      TEXT NOT NULL DEFAULT 'waiting' CHECK (status IN ('waiting', 'approved', 'declined')),
    invite_id   UUID REFERENCES invites(id) ON DELETE SET NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    decided_at  TIMESTAMPTZ
);
CREATE UNIQUE INDEX IF NOT EXISTS waitlist_email_unique ON waitlist (lower(email)) WHERE email IS NOT NULL;

ALTER TABLE invites  ENABLE ROW LEVEL SECURITY;
ALTER TABLE waitlist ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON invites, waitlist FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON invites, waitlist TO service_role;
