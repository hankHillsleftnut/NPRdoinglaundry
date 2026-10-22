-- ============================================================================
-- 024: the invite preview's face (BE2.0a)
--      (024: the next free backend number; 021 is BE2.0b's, 022 BE1.1's,
--      023 BE1.5's)
--
-- Goal: when you open a friend's link before signing in, the screen can say
-- "priya kept a place for you." with the ticket's number and date, without
-- spending anything or telling a stranger whether a code works (contract 01
-- §2.1).
--
-- Why: 007's invite_face answers the link page with the inviter's first name
-- for a live code. The preview (GET /public/invites/:code) prints the whole
-- face: the same function now also returns the invite's kind, serial (021)
-- and the day it was made, still only for a live code, and still never the
-- sealed code. Same signature, same grants; the link page keeps working.
--
-- Additive. RLS unchanged; service_role only. Files only: never applied to
-- production by an agent.
-- ============================================================================

CREATE OR REPLACE FUNCTION invite_face(p_code_hash TEXT, p_now TIMESTAMPTZ)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT jsonb_build_object(
               'live', i.id IS NOT NULL,
               'from', u.first_name,
               'kind', i.kind,
               'serial', i.serial,
               'created_at', i.created_at)
      FROM (SELECT 1) one
      LEFT JOIN invites i ON i.code_hash = p_code_hash AND i.used_by_user_id IS NULL AND i.revoked_at IS NULL
                          AND (i.expires_at IS NULL OR i.expires_at > p_now)
      LEFT JOIN users u ON u.id = i.owner_user_id;
$$;

REVOKE ALL ON FUNCTION invite_face(TEXT, TIMESTAMPTZ) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION invite_face(TEXT, TIMESTAMPTZ) TO service_role;
