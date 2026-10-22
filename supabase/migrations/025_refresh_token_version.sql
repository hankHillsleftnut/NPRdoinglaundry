-- ============================================================================
-- 025: a session remembers the token version it was issued under (BE0.4 follow-up)
--      (025: the next free backend number; 021-024 are on open PRs)
--
-- Goal: bumping users.token_version is a real kill switch. It already ends
-- every access token at once (the auth middleware compares the token's
-- version); it must end every refresh too, or the app refreshes and carries
-- on (sign-in contract pass, F4).
--
-- Why: refresh_tokens never recorded the version a family was issued under,
-- so /v2/auth/refresh had nothing to compare. Now:
--   refresh_tokens.token_version  the users.token_version at sign-in,
--                                 inherited by every successor in the family;
--                                 existing rows take their user's current version
--   issue_session                 takes p_token_version (the 4-argument form is
--                                 dropped, so migration and deploy land together)
--   rotate_refresh_token          the successor inherits the family's version
-- The route refuses a refresh whose family is behind the user's version
-- (session_revoked) and ends the family. Nothing else in 005 changes.
--
-- Additive. RLS unchanged; service_role only. Files only: never applied to
-- production by an agent.
-- ============================================================================

ALTER TABLE refresh_tokens ADD COLUMN IF NOT EXISTS token_version INTEGER NOT NULL DEFAULT 0;
UPDATE refresh_tokens r SET token_version = u.token_version FROM users u WHERE u.id = r.user_id AND r.token_version <> u.token_version;

DROP FUNCTION IF EXISTS issue_session(UUID, TEXT, TIMESTAMPTZ, TEXT);
CREATE OR REPLACE FUNCTION issue_session(
    p_user UUID, p_token_hash TEXT, p_now TIMESTAMPTZ, p_device TEXT, p_token_version INTEGER
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_id UUID;
BEGIN
    INSERT INTO refresh_tokens (user_id, family_id, token_hash, created_at, expires_at, absolute_expires_at, device_label, token_version)
    VALUES (p_user, uuid_generate_v4(), p_token_hash, p_now, p_now + INTERVAL '60 days', p_now + INTERVAL '180 days', p_device, p_token_version)
    RETURNING id INTO v_id;
    RETURN v_id;
END;
$$;

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

    INSERT INTO refresh_tokens (user_id, family_id, token_hash, created_at, expires_at, absolute_expires_at, device_label, token_version)
    VALUES (v_row.user_id, v_row.family_id, p_new_hash, p_now,
            LEAST(p_now + INTERVAL '60 days', v_row.absolute_expires_at), v_row.absolute_expires_at, v_row.device_label, v_row.token_version)
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

REVOKE ALL ON FUNCTION issue_session(UUID, TEXT, TIMESTAMPTZ, TEXT, INTEGER) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION rotate_refresh_token(TEXT, TEXT, TIMESTAMPTZ, TEXT, INTEGER) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION issue_session(UUID, TEXT, TIMESTAMPTZ, TEXT, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION rotate_refresh_token(TEXT, TEXT, TIMESTAMPTZ, TEXT, INTEGER) TO service_role;
