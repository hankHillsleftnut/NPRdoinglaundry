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
--   functions     one per change, each one transaction (below): redeeming,
--                 the waitlist, "your invites", and the admin's actions.
--                 Codes arrive hashed (and sealed, for showing a link again);
--                 the plain code never reaches the database.
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

-- The app's "join the waitlist" (POST /v2/waitlist): once per person. Only a
-- waitlisted person is added; a second call changes nothing (the first reason
-- stays). Returns whether they are waiting now.
CREATE OR REPLACE FUNCTION join_waitlist(p_user UUID, p_reason TEXT, p_now TIMESTAMPTZ)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO waitlist (source, user_id, reason, created_at)
    SELECT 'app', u.id, p_reason, p_now FROM users u WHERE u.id = p_user AND u.access = 'waitlisted'
    ON CONFLICT (user_id) DO NOTHING;
    RETURN EXISTS (SELECT 1 FROM waitlist WHERE user_id = p_user AND status = 'waiting');
END;
$$;

-- "Am I on the waitlist" (GET /v2/access): a waiting row of their own.
CREATE OR REPLACE FUNCTION waitlist_state(p_user UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (SELECT 1 FROM waitlist WHERE user_id = p_user AND status = 'waiting');
$$;

REVOKE ALL ON FUNCTION join_waitlist(UUID, TEXT, TIMESTAMPTZ) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION waitlist_state(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION join_waitlist(UUID, TEXT, TIMESTAMPTZ) TO service_role;
GRANT EXECUTE ON FUNCTION waitlist_state(UUID) TO service_role;

-- Redeeming an invite (POST /v2/invites/redeem). The caller's row is locked, so
-- two redemptions by one person run one after the other: a person is let in
-- once and gets exactly three invites, however often the app retries or with
-- however many codes. The invite's update keeps "used_by_user_id IS NULL" as
-- the guard, so of two people racing for one code, one wins.
--   { outcome: 'redeemed', invited_by }   let in now, or this caller's own retry
--   { outcome: 'already_in', access }     the caller is past the waitlist; no code is spent
--   { outcome: 'invalid' | 'used' | 'expired' }
--   { outcome: 'no_user' }
CREATE OR REPLACE FUNCTION redeem_invite(
    p_user UUID, p_code_hash TEXT, p_now TIMESTAMPTZ, p_new_hashes TEXT[], p_new_ciphertexts TEXT[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_access TEXT;
    v_invite invites%ROWTYPE;
    v_used UUID;
    v_by TEXT;
BEGIN
    SELECT access INTO v_access FROM users WHERE id = p_user FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('outcome', 'no_user');
    END IF;

    SELECT * INTO v_invite FROM invites WHERE code_hash = p_code_hash;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('outcome', 'invalid');
    END IF;
    SELECT first_name INTO v_by FROM users WHERE id = v_invite.owner_user_id;

    -- This caller already redeemed this code: the same answer, nothing new.
    IF v_invite.used_by_user_id = p_user THEN
        RETURN jsonb_build_object('outcome', 'redeemed', 'invited_by', v_by);
    END IF;
    IF v_access <> 'waitlisted' THEN
        RETURN jsonb_build_object('outcome', 'already_in', 'access', v_access);
    END IF;
    IF v_invite.revoked_at IS NOT NULL THEN
        RETURN jsonb_build_object('outcome', 'invalid');
    END IF;
    IF v_invite.used_by_user_id IS NOT NULL THEN
        RETURN jsonb_build_object('outcome', 'used');
    END IF;
    IF v_invite.expires_at IS NOT NULL AND v_invite.expires_at <= p_now THEN
        RETURN jsonb_build_object('outcome', 'expired');
    END IF;

    UPDATE invites
       SET used_by_user_id = p_user, used_at = p_now, code_ciphertext = NULL
     WHERE id = v_invite.id AND used_by_user_id IS NULL AND revoked_at IS NULL
     RETURNING id INTO v_used;
    IF v_used IS NULL THEN
        RETURN jsonb_build_object('outcome', 'used');
    END IF;

    UPDATE users SET access = 'approved' WHERE id = p_user;
    INSERT INTO invites (code_hash, code_ciphertext, kind, owner_user_id, created_at)
    SELECT h, c, 'member', p_user, p_now FROM unnest(p_new_hashes, p_new_ciphertexts) AS t(h, c);
    UPDATE waitlist SET status = 'approved', decided_at = p_now, invite_id = v_invite.id
     WHERE user_id = p_user AND status = 'waiting';
    RETURN jsonb_build_object('outcome', 'redeemed', 'invited_by', v_by);
END;
$$;

-- "Your invites" (GET /v2/invites/mine): oldest first; revoked ones are gone.
CREATE OR REPLACE FUNCTION invites_of(p_user UUID)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
               'id', i.id, 'code_ciphertext', i.code_ciphertext, 'created_at', i.created_at,
               'used', i.used_by_user_id IS NOT NULL OR i.used_at IS NOT NULL, 'used_by', u.first_name)
             ORDER BY i.created_at, i.id), '[]'::jsonb)
      FROM invites i LEFT JOIN users u ON u.id = i.used_by_user_id
     WHERE i.owner_user_id = p_user AND i.revoked_at IS NULL;
$$;

-- The link page (GET /i/:code): the inviter's first name, only for a live code.
CREATE OR REPLACE FUNCTION invite_face(p_code_hash TEXT, p_now TIMESTAMPTZ)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT jsonb_build_object('live', i.id IS NOT NULL, 'from', u.first_name)
      FROM (SELECT 1) one
      LEFT JOIN invites i ON i.code_hash = p_code_hash AND i.used_by_user_id IS NULL AND i.revoked_at IS NULL
                          AND (i.expires_at IS NULL OR i.expires_at > p_now)
      LEFT JOIN users u ON u.id = i.owner_user_id;
$$;

-- The website's waitlist (POST /public/waitlist): one row per email, whatever
-- is sent again; the caller always gets the same answer.
CREATE OR REPLACE FUNCTION join_public_waitlist(p_email TEXT, p_name TEXT, p_reason TEXT, p_now TIMESTAMPTZ)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    INSERT INTO waitlist (source, email, name, reason, created_at)
    VALUES ('web', lower(p_email), p_name, p_reason, p_now)
    ON CONFLICT ((lower(email))) WHERE email IS NOT NULL DO NOTHING;
$$;

-- Admin: approve a waiting person with a founder invite (its code is shown once, by the backend).
CREATE OR REPLACE FUNCTION approve_waitlister(p_id UUID, p_code_hash TEXT, p_code_ciphertext TEXT, p_now TIMESTAMPTZ)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_invite UUID;
BEGIN
    PERFORM 1 FROM waitlist WHERE id = p_id AND status = 'waiting' FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('outcome', 'not_waiting');
    END IF;
    INSERT INTO invites (code_hash, code_ciphertext, kind, created_at)
    VALUES (p_code_hash, p_code_ciphertext, 'founder', p_now)
    RETURNING id INTO v_invite;
    UPDATE waitlist SET status = 'approved', decided_at = p_now, invite_id = v_invite WHERE id = p_id;
    RETURN jsonb_build_object('outcome', 'approved', 'invite_id', v_invite);
END;
$$;

CREATE OR REPLACE FUNCTION decline_waitlister(p_id UUID, p_now TIMESTAMPTZ)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE waitlist SET status = 'declined', decided_at = p_now WHERE id = p_id AND status = 'waiting';
    RETURN FOUND;
END;
$$;

-- Admin: new invites (founder or review codes, or more for a member).
CREATE OR REPLACE FUNCTION create_invites(
    p_kind TEXT, p_owner UUID, p_hashes TEXT[], p_ciphertexts TEXT[], p_expires TIMESTAMPTZ, p_now TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    WITH made AS (
        INSERT INTO invites (code_hash, code_ciphertext, kind, owner_user_id, expires_at, created_at)
        SELECT h, c, p_kind, p_owner, p_expires, p_now FROM unnest(p_hashes, p_ciphertexts) AS t(h, c)
        RETURNING id
    )
    SELECT COALESCE(jsonb_agg(id), '[]'::jsonb) FROM made;
$$;

CREATE OR REPLACE FUNCTION revoke_invite(p_id UUID, p_now TIMESTAMPTZ)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE invites SET revoked_at = p_now, code_ciphertext = NULL
     WHERE id = p_id AND used_by_user_id IS NULL AND revoked_at IS NULL;
    RETURN FOUND;
END;
$$;

CREATE OR REPLACE FUNCTION set_user_access(p_user UUID, p_access TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE users SET access = p_access WHERE id = p_user;
    RETURN FOUND;
END;
$$;

-- Admin lists: who is waiting, and who invited whom. Never a code.
CREATE OR REPLACE FUNCTION admin_waitlist(p_status TEXT)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
               'id', w.id, 'source', w.source, 'user_id', w.user_id, 'email', w.email, 'name', w.name,
               'reason', w.reason, 'status', w.status, 'created_at', w.created_at, 'decided_at', w.decided_at)
             ORDER BY w.created_at), '[]'::jsonb)
      FROM waitlist w WHERE p_status IS NULL OR w.status = p_status;
$$;

CREATE OR REPLACE FUNCTION admin_invites()
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
               'id', i.id, 'kind', i.kind, 'owner_user_id', i.owner_user_id, 'owner_name', o.first_name,
               'used_by_user_id', i.used_by_user_id, 'used_by_name', u.first_name, 'created_at', i.created_at,
               'used_at', i.used_at, 'revoked_at', i.revoked_at, 'expires_at', i.expires_at)
             ORDER BY i.created_at DESC), '[]'::jsonb)
      FROM invites i
      LEFT JOIN users o ON o.id = i.owner_user_id
      LEFT JOIN users u ON u.id = i.used_by_user_id;
$$;

REVOKE ALL ON FUNCTION redeem_invite(UUID, TEXT, TIMESTAMPTZ, TEXT[], TEXT[]) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION invites_of(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION invite_face(TEXT, TIMESTAMPTZ) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION join_public_waitlist(TEXT, TEXT, TEXT, TIMESTAMPTZ) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION approve_waitlister(UUID, TEXT, TEXT, TIMESTAMPTZ) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION decline_waitlister(UUID, TIMESTAMPTZ) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION create_invites(TEXT, UUID, TEXT[], TEXT[], TIMESTAMPTZ, TIMESTAMPTZ) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION revoke_invite(UUID, TIMESTAMPTZ) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION set_user_access(UUID, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION admin_waitlist(TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION admin_invites() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION redeem_invite(UUID, TEXT, TIMESTAMPTZ, TEXT[], TEXT[]) TO service_role;
GRANT EXECUTE ON FUNCTION invites_of(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION invite_face(TEXT, TIMESTAMPTZ) TO service_role;
GRANT EXECUTE ON FUNCTION join_public_waitlist(TEXT, TEXT, TEXT, TIMESTAMPTZ) TO service_role;
GRANT EXECUTE ON FUNCTION approve_waitlister(UUID, TEXT, TEXT, TIMESTAMPTZ) TO service_role;
GRANT EXECUTE ON FUNCTION decline_waitlister(UUID, TIMESTAMPTZ) TO service_role;
GRANT EXECUTE ON FUNCTION create_invites(TEXT, UUID, TEXT[], TEXT[], TIMESTAMPTZ, TIMESTAMPTZ) TO service_role;
GRANT EXECUTE ON FUNCTION revoke_invite(UUID, TIMESTAMPTZ) TO service_role;
GRANT EXECUTE ON FUNCTION set_user_access(UUID, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION admin_waitlist(TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION admin_invites() TO service_role;
