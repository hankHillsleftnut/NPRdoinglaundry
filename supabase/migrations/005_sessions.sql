-- ============================================================================
-- 005: sessions -- short access tokens, rotating refresh tokens, nonces (BE0.4)
--
-- Goal: people stay signed in for as long as they use the app, silently, and a
-- copied pass stops working quickly (founder, 21 Oct). Contract 00 §3.
--
-- Why: the only session today is a 30-day JWT with no refresh and no way to
-- revoke it. This adds the server side of the new sessions:
--   refresh_tokens   one row per refresh token, stored as a SHA-256 hash only;
--                    a "family" is one device's chain of rotations
--   refresh_grace    the successor refresh token for 30 seconds after a
--                    rotation, so a retried refresh (a dropped response) gets
--                    the same one instead of tripping reuse detection; stored
--                    encrypted only, and the row expires. No access token is
--                    stored: a retry is given a freshly issued one.
--   auth_nonces      sign-in nonces, accepted once
--   users.time_zone, users.token_version, users.first_name
-- and the functions that change them, each one transaction:
--   issue_session, rotate_refresh_token, revoke_session, use_nonce.
--
-- Additive. RLS on; nothing for anon/authenticated; service_role only.
-- Files only: never applied to production by an agent.
-- ============================================================================

ALTER TABLE users ADD COLUMN IF NOT EXISTS time_zone TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS token_version INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS first_name TEXT;

CREATE TABLE IF NOT EXISTS refresh_tokens (
    id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id              UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    family_id            UUID NOT NULL,
    token_hash           TEXT NOT NULL UNIQUE,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- Sliding: each rotation gives the successor 60 more days...
    expires_at           TIMESTAMPTZ NOT NULL,
    -- ...but never past 180 days from the family's first sign-in.
    absolute_expires_at  TIMESTAMPTZ NOT NULL,
    rotated_at           TIMESTAMPTZ,
    replaced_by          UUID REFERENCES refresh_tokens(id) ON DELETE SET NULL,
    revoked_at           TIMESTAMPTZ,
    device_label         TEXT
);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_family ON refresh_tokens(family_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user ON refresh_tokens(user_id);

CREATE TABLE IF NOT EXISTS refresh_grace (
    token_hash          TEXT PRIMARY KEY,
    refresh_ciphertext  TEXT NOT NULL,
    expires_at          TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS auth_nonces (
    nonce_hash  TEXT PRIMARY KEY,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at  TIMESTAMPTZ NOT NULL
);

-- A new family for one device: its first refresh token.
CREATE OR REPLACE FUNCTION issue_session(
    p_user UUID, p_token_hash TEXT, p_now TIMESTAMPTZ, p_device TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_id UUID;
BEGIN
    INSERT INTO refresh_tokens (user_id, family_id, token_hash, created_at, expires_at, absolute_expires_at, device_label)
    VALUES (p_user, uuid_generate_v4(), p_token_hash, p_now, p_now + INTERVAL '60 days', p_now + INTERVAL '180 days', p_device)
    RETURNING id INTO v_id;
    RETURN v_id;
END;
$$;

-- One refresh, in one transaction, with the presented token's row locked so
-- two refreshes of one token at once produce one successor. Returns
--   { outcome: 'rotated', user_id }               the successor is stored
--   { outcome: 'grace', user_id,                  rotated in the last p_grace_seconds:
--     refresh_ciphertext }                        the same successor (sealed)
--   { outcome: 'revoked' }                        unknown, expired, revoked, or
--                                                 reused (the family is revoked)
CREATE OR REPLACE FUNCTION rotate_refresh_token(
    p_token_hash TEXT, p_new_hash TEXT, p_now TIMESTAMPTZ, p_refresh_ciphertext TEXT,
    p_grace_seconds INTEGER DEFAULT 30
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_row   refresh_tokens%ROWTYPE;
    v_grace refresh_grace%ROWTYPE;
    v_next  UUID;
BEGIN
    SELECT * INTO v_row FROM refresh_tokens WHERE token_hash = p_token_hash FOR UPDATE;
    IF NOT FOUND OR v_row.revoked_at IS NOT NULL THEN
        RETURN jsonb_build_object('outcome', 'revoked');
    END IF;

    IF v_row.rotated_at IS NOT NULL THEN
        IF p_now <= v_row.rotated_at + make_interval(secs => p_grace_seconds) THEN
            SELECT * INTO v_grace FROM refresh_grace WHERE token_hash = p_token_hash AND expires_at >= p_now;
            IF FOUND THEN
                RETURN jsonb_build_object('outcome', 'grace', 'user_id', v_row.user_id,
                    'refresh_ciphertext', v_grace.refresh_ciphertext);
            END IF;
        END IF;
        -- Reused outside the grace window: someone else has a copy. End the whole family.
        UPDATE refresh_tokens SET revoked_at = p_now WHERE family_id = v_row.family_id AND revoked_at IS NULL;
        DELETE FROM refresh_grace WHERE token_hash IN (SELECT token_hash FROM refresh_tokens WHERE family_id = v_row.family_id);
        RETURN jsonb_build_object('outcome', 'revoked', 'reuse', true);
    END IF;

    IF v_row.expires_at <= p_now OR v_row.absolute_expires_at <= p_now THEN
        RETURN jsonb_build_object('outcome', 'revoked');
    END IF;

    INSERT INTO refresh_tokens (user_id, family_id, token_hash, created_at, expires_at, absolute_expires_at, device_label)
    VALUES (v_row.user_id, v_row.family_id, p_new_hash, p_now,
            LEAST(p_now + INTERVAL '60 days', v_row.absolute_expires_at), v_row.absolute_expires_at, v_row.device_label)
    RETURNING id INTO v_next;
    UPDATE refresh_tokens SET rotated_at = p_now, replaced_by = v_next WHERE id = v_row.id;
    INSERT INTO refresh_grace (token_hash, refresh_ciphertext, expires_at)
    VALUES (p_token_hash, p_refresh_ciphertext, p_now + make_interval(secs => p_grace_seconds))
    ON CONFLICT (token_hash) DO NOTHING;
    -- Expired grace rows are of no use to anyone.
    DELETE FROM refresh_grace WHERE expires_at < p_now;
    RETURN jsonb_build_object('outcome', 'rotated', 'user_id', v_row.user_id);
END;
$$;

-- Sign out this device: the presented token's whole family. True if it ended a live session.
CREATE OR REPLACE FUNCTION revoke_session(p_token_hash TEXT, p_now TIMESTAMPTZ)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_family UUID; v_count INTEGER;
BEGIN
    SELECT family_id INTO v_family FROM refresh_tokens WHERE token_hash = p_token_hash;
    IF NOT FOUND THEN RETURN FALSE; END IF;
    UPDATE refresh_tokens SET revoked_at = p_now WHERE family_id = v_family AND revoked_at IS NULL;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    DELETE FROM refresh_grace WHERE token_hash IN (SELECT token_hash FROM refresh_tokens WHERE family_id = v_family);
    RETURN v_count > 0;
END;
$$;

-- A sign-in nonce, accepted once while it lives. False if it was seen before.
CREATE OR REPLACE FUNCTION use_nonce(p_nonce_hash TEXT, p_now TIMESTAMPTZ, p_ttl_seconds INTEGER DEFAULT 600)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    DELETE FROM auth_nonces WHERE expires_at < p_now;
    INSERT INTO auth_nonces (nonce_hash, created_at, expires_at)
    VALUES (p_nonce_hash, p_now, p_now + make_interval(secs => p_ttl_seconds))
    ON CONFLICT (nonce_hash) DO NOTHING;
    RETURN FOUND;
END;
$$;

ALTER TABLE refresh_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE refresh_grace  ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth_nonces    ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON refresh_tokens, refresh_grace, auth_nonces FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON refresh_tokens, refresh_grace, auth_nonces TO service_role;

REVOKE ALL ON FUNCTION issue_session(UUID, TEXT, TIMESTAMPTZ, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION rotate_refresh_token(TEXT, TEXT, TIMESTAMPTZ, TEXT, INTEGER) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION revoke_session(TEXT, TIMESTAMPTZ) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION use_nonce(TEXT, TIMESTAMPTZ, INTEGER) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION issue_session(UUID, TEXT, TIMESTAMPTZ, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION rotate_refresh_token(TEXT, TEXT, TIMESTAMPTZ, TEXT, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION revoke_session(TEXT, TIMESTAMPTZ) TO service_role;
GRANT EXECUTE ON FUNCTION use_nonce(TEXT, TIMESTAMPTZ, INTEGER) TO service_role;
