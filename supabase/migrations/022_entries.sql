-- ============================================================================
-- 022: the journal's sending door and "today" (BE1.1)
--      (022: the next free backend number; 013-018 are assigned in
--      plans-consistency.md §3, 019 and 020 are merged, 021 is BE2.0b's)
--
-- Goal: everything you type or say in the journal lands in your bank exactly
-- once, even when you were offline when you sent it (contract 02 §2, §5; the
-- integrator's contract pass for BE1.1/BE1.5, 22 Oct).
--
-- Why: the app's outbox sends each entry with its own key (clientEntryId) and
-- retries until it hears back, so the server must answer a retry with the
-- row it already has and refuse the same key with different words. This adds:
--   raw_content_client_entry_unique  one row per (user, client entry id),
--                 whatever the content type (the agent's dedup key, 117, is
--                 per content type, so the same key sent as typed and then
--                 as voice would make two rows; this index makes it one)
--   resolve_zone  the person's zone for "today" and "day": the request's
--                 X-Time-Zone (stored on the user when it changes, as
--                 contract 00 §1 promises), else the stored one, else UTC
--   entry_create  insert once; a replay is answered with the stored row; the
--                 same key with other words is a mismatch
--   entries_today the person's own entries (the agent's "sent by the person"
--                 types, passed in) on today's calendar day in their zone
-- Nothing here reads raw_content.embedding or any other person's rows.
--
-- Before applying by hand: no two rows of one user may share
-- metadata->>'client_entry_id' (nothing on main writes that field yet).
-- Additive. RLS unchanged; service_role only. Files only: never applied to
-- production by an agent.
-- ============================================================================

CREATE UNIQUE INDEX IF NOT EXISTS raw_content_client_entry_unique
    ON raw_content (user_id, (metadata->>'client_entry_id'))
    WHERE metadata->>'client_entry_id' IS NOT NULL;

-- The zone a request's dates are read in. The header wins and is remembered;
-- without one the remembered zone is used, and UTC when nothing is known.
-- NULL when there is no such user.
CREATE OR REPLACE FUNCTION resolve_zone(p_user UUID, p_zone TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_stored TEXT;
BEGIN
    SELECT time_zone INTO v_stored FROM users WHERE id = p_user;
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;
    IF p_zone IS NOT NULL AND p_zone IS DISTINCT FROM v_stored THEN
        UPDATE users SET time_zone = p_zone WHERE id = p_user;
    END IF;
    RETURN COALESCE(p_zone, v_stored, 'UTC');
END;
$$;

-- One entry as the door reads it (contract 02 §5's Entry, before the door maps
-- content_type to kind and processing_status to reading).
CREATE OR REPLACE FUNCTION entry_json(r raw_content, p_zone TEXT)
RETURNS JSONB
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT jsonb_build_object(
        'id', r.id,
        'content_type', r.content_type,
        'content', r.content,
        'at', COALESCE(r.content_date, r.created_at),
        'day', (COALESCE(r.content_date, r.created_at) AT TIME ZONE p_zone)::date,
        'processing_status', r.processing_status,
        'client_entry_id', r.metadata->>'client_entry_id'
    );
$$;

-- Sending an entry (POST /v2/entries). The row is inserted with the client's
-- key in metadata; the unique index decides the race, so two retries at once
-- can't both write. p_request_hash fingerprints what was sent (kind and text,
-- computed by the door); a replay with the same fingerprint is the stored row,
-- another fingerprint under the same key is a mismatch and stores nothing.
--   { outcome: 'created' | 'replayed', entry }
--   { outcome: 'mismatch' }
--   { outcome: 'no_user' }
CREATE OR REPLACE FUNCTION entry_create(
    p_user UUID, p_client_entry_id TEXT, p_content_type TEXT, p_content TEXT, p_content_date TIMESTAMPTZ,
    p_request_hash TEXT, p_app_version TEXT, p_zone TEXT, p_now TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_zone TEXT;
    v_row raw_content%ROWTYPE;
BEGIN
    v_zone := resolve_zone(p_user, p_zone);
    IF v_zone IS NULL THEN
        RETURN jsonb_build_object('outcome', 'no_user');
    END IF;

    INSERT INTO raw_content (user_id, content_type, content, content_date, metadata, processing_status, created_at)
    VALUES (p_user, p_content_type, p_content, p_content_date,
            jsonb_strip_nulls(jsonb_build_object('client_entry_id', p_client_entry_id, 'request_hash', p_request_hash, 'app_version', p_app_version)),
            'pending', p_now)
    ON CONFLICT (user_id, (metadata->>'client_entry_id')) WHERE metadata->>'client_entry_id' IS NOT NULL DO NOTHING
    RETURNING * INTO v_row;
    IF FOUND THEN
        RETURN jsonb_build_object('outcome', 'created', 'entry', entry_json(v_row, v_zone));
    END IF;

    SELECT * INTO v_row FROM raw_content WHERE user_id = p_user AND metadata->>'client_entry_id' = p_client_entry_id;
    IF NOT FOUND THEN
        -- Gone between the conflict and the read; the caller retries.
        RAISE EXCEPTION 'entry_create: conflict but no row' USING ERRCODE = 'serialization_failure';
    END IF;
    IF v_row.metadata->>'request_hash' IS DISTINCT FROM p_request_hash THEN
        RETURN jsonb_build_object('outcome', 'mismatch');
    END IF;
    RETURN jsonb_build_object('outcome', 'replayed', 'entry', entry_json(v_row, v_zone));
END;
$$;

-- Today's entries (GET /v2/entries/today): the person's own words (p_types is
-- the agent's "sent by the person" set) whose moment falls on today's calendar
-- day in their zone, oldest first, at most p_limit.
--   { date, entries: [...] } or { outcome: 'no_user' }
CREATE OR REPLACE FUNCTION entries_today(p_user UUID, p_types TEXT[], p_zone TEXT, p_now TIMESTAMPTZ, p_limit INT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_zone TEXT;
    v_day DATE;
    v_entries JSONB;
BEGIN
    v_zone := resolve_zone(p_user, p_zone);
    IF v_zone IS NULL THEN
        RETURN jsonb_build_object('outcome', 'no_user');
    END IF;
    v_day := (p_now AT TIME ZONE v_zone)::date;
    SELECT COALESCE(jsonb_agg(entry_json(r, v_zone) ORDER BY COALESCE(r.content_date, r.created_at), r.id), '[]'::jsonb)
      INTO v_entries
      FROM (
          SELECT * FROM raw_content
           WHERE user_id = p_user AND content_type = ANY(p_types)
             AND (COALESCE(content_date, created_at) AT TIME ZONE v_zone)::date = v_day
           ORDER BY COALESCE(content_date, created_at), id
           LIMIT p_limit
      ) r;
    RETURN jsonb_build_object('date', v_day, 'entries', v_entries);
END;
$$;

REVOKE ALL ON FUNCTION resolve_zone(UUID, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION entry_json(raw_content, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION entry_create(UUID, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, TEXT, TEXT, TIMESTAMPTZ) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION entries_today(UUID, TEXT[], TEXT, TIMESTAMPTZ, INT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION resolve_zone(UUID, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION entry_json(raw_content, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION entry_create(UUID, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, TEXT, TEXT, TIMESTAMPTZ) TO service_role;
GRANT EXECUTE ON FUNCTION entries_today(UUID, TEXT[], TEXT, TIMESTAMPTZ, INT) TO service_role;
