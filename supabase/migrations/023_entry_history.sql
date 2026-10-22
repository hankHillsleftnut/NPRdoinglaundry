-- ============================================================================
-- 023: entry history and one entry (BE1.5)
--      (023: the next free backend number; 021 is BE2.0b's, 022 is BE1.1's)
--
-- Goal: the drawer lists everything you sent, newest first, in pages that
-- never shift as new entries arrive, with a search over your own words; one
-- entry opens by id, and another person's id is simply not there (contract
-- 02 §5; the integrator's BE1.1/BE1.5 contract pass, 22 Oct).
--
-- Why: pages are keyed, not offset: the cursor is the last row's moment in
-- microseconds and its id, so a new entry sits above the first page and
-- nothing is skipped or repeated, however many rows share one timestamp.
-- This adds:
--   entry_fields_json  one entry from named columns (never the whole row: the
--                      agent's migrations add a 3,072-float embedding to
--                      raw_content, which nothing here should read)
--   entries_today      022's function, now reading named columns (same signature)
--   entries_list       own words, newest first, keyset after (p_before_us,
--                      p_before_id), optional ILIKE over the text (the door
--                      escapes % _ \), at most p_limit
--   entry_get          one row of the caller's, or null
-- Additive. RLS unchanged; service_role only. Files only: never applied to
-- production by an agent.
-- ============================================================================

CREATE OR REPLACE FUNCTION entry_fields_json(
    p_id UUID, p_content_type TEXT, p_content TEXT, p_content_date TIMESTAMPTZ, p_created_at TIMESTAMPTZ,
    p_processing_status TEXT, p_metadata JSONB, p_zone TEXT
)
RETURNS JSONB
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT jsonb_build_object(
        'id', p_id,
        'content_type', p_content_type,
        'content', p_content,
        'at', COALESCE(p_content_date, p_created_at),
        'at_us', (extract(epoch FROM COALESCE(p_content_date, p_created_at)) * 1000000)::bigint,
        'day', (COALESCE(p_content_date, p_created_at) AT TIME ZONE p_zone)::date,
        'processing_status', p_processing_status,
        'client_entry_id', p_metadata->>'client_entry_id'
    );
$$;

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
    SELECT COALESCE(jsonb_agg(entry_fields_json(r.id, r.content_type, r.content, r.content_date, r.created_at, r.processing_status, r.metadata, v_zone)
                              ORDER BY COALESCE(r.content_date, r.created_at), r.id), '[]'::jsonb)
      INTO v_entries
      FROM (
          SELECT id, content_type, content, content_date, created_at, processing_status, metadata FROM raw_content
           WHERE user_id = p_user AND content_type = ANY(p_types)
             AND (COALESCE(content_date, created_at) AT TIME ZONE v_zone)::date = v_day
           ORDER BY COALESCE(content_date, created_at), id
           LIMIT p_limit
      ) r;
    RETURN jsonb_build_object('date', v_day, 'entries', v_entries);
END;
$$;

-- The drawer (GET /v2/entries). Rows strictly before the cursor in
-- (moment, id) order, newest first; p_pattern is an ILIKE pattern the door
-- built (wildcards escaped with a backslash), or null for everything.
--   { entries: [...] } or { outcome: 'no_user' }
CREATE OR REPLACE FUNCTION entries_list(
    p_user UUID, p_types TEXT[], p_zone TEXT, p_limit INT, p_before_us BIGINT, p_before_id UUID, p_pattern TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_zone TEXT;
    v_entries JSONB;
BEGIN
    v_zone := resolve_zone(p_user, p_zone);
    IF v_zone IS NULL THEN
        RETURN jsonb_build_object('outcome', 'no_user');
    END IF;
    SELECT COALESCE(jsonb_agg(entry_fields_json(r.id, r.content_type, r.content, r.content_date, r.created_at, r.processing_status, r.metadata, v_zone)
                              ORDER BY r.at DESC, r.id DESC), '[]'::jsonb)
      INTO v_entries
      FROM (
          SELECT id, content_type, content, content_date, created_at, processing_status, metadata,
                 COALESCE(content_date, created_at) AS at
            FROM raw_content
           WHERE user_id = p_user AND content_type = ANY(p_types)
             AND (p_before_us IS NULL
                  OR ((extract(epoch FROM COALESCE(content_date, created_at)) * 1000000)::bigint, id) < (p_before_us, p_before_id))
             AND (p_pattern IS NULL OR content ILIKE p_pattern ESCAPE '\')
           ORDER BY COALESCE(content_date, created_at) DESC, id DESC
           LIMIT p_limit
      ) r;
    RETURN jsonb_build_object('entries', v_entries);
END;
$$;

-- One entry (GET /v2/entries/:id): the caller's own, else null (never
-- another person's; the door answers not_found either way).
CREATE OR REPLACE FUNCTION entry_get(p_user UUID, p_id UUID, p_types TEXT[], p_zone TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_zone TEXT;
    v_entry JSONB;
BEGIN
    v_zone := resolve_zone(p_user, p_zone);
    IF v_zone IS NULL THEN
        RETURN jsonb_build_object('outcome', 'no_user');
    END IF;
    SELECT entry_fields_json(r.id, r.content_type, r.content, r.content_date, r.created_at, r.processing_status, r.metadata, v_zone)
      INTO v_entry
      FROM raw_content r
     WHERE r.id = p_id AND r.user_id = p_user AND r.content_type = ANY(p_types);
    RETURN jsonb_build_object('entry', v_entry);
END;
$$;

REVOKE ALL ON FUNCTION entry_fields_json(UUID, TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT, JSONB, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION entries_today(UUID, TEXT[], TEXT, TIMESTAMPTZ, INT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION entries_list(UUID, TEXT[], TEXT, INT, BIGINT, UUID, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION entry_get(UUID, UUID, TEXT[], TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION entry_fields_json(UUID, TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT, JSONB, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION entries_today(UUID, TEXT[], TEXT, TIMESTAMPTZ, INT) TO service_role;
GRANT EXECUTE ON FUNCTION entries_list(UUID, TEXT[], TEXT, INT, BIGINT, UUID, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION entry_get(UUID, UUID, TEXT[], TEXT) TO service_role;
