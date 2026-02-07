-- Vector Search Function for Finding Similar Insights
-- Uses cosine similarity for semantic matching

CREATE OR REPLACE FUNCTION match_insights(
    query_embedding vector(3072),
    match_threshold float DEFAULT 0.7,
    match_count int DEFAULT 10,
    filter_user_id uuid DEFAULT NULL,
    filter_category text DEFAULT NULL,
    exclude_insight_id uuid DEFAULT NULL
)
RETURNS TABLE (
    id uuid,
    content text,
    primary_category text,
    secondary_categories text[],
    insight_date timestamptz,
    sentiment text,
    is_inferred boolean,
    similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        iu.id,
        iu.content,
        iu.primary_category,
        iu.secondary_categories,
        iu.insight_date,
        iu.sentiment,
        iu.is_inferred,
        1 - (iu.embedding <=> query_embedding) AS similarity
    FROM insight_units iu
    WHERE
        iu.embedding IS NOT NULL
        AND (filter_user_id IS NULL OR iu.user_id = filter_user_id)
        AND (filter_category IS NULL OR iu.primary_category = filter_category)
        AND (exclude_insight_id IS NULL OR iu.id != exclude_insight_id)
        AND 1 - (iu.embedding <=> query_embedding) > match_threshold
    ORDER BY iu.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- Function to find insights within a date range with semantic search
CREATE OR REPLACE FUNCTION search_insights_in_range(
    query_embedding vector(3072),
    p_user_id uuid,
    start_date timestamptz,
    end_date timestamptz,
    match_threshold float DEFAULT 0.5,
    match_count int DEFAULT 50
)
RETURNS TABLE (
    id uuid,
    content text,
    primary_category text,
    insight_date timestamptz,
    sentiment text,
    intensity decimal,
    similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        iu.id,
        iu.content,
        iu.primary_category,
        iu.insight_date,
        iu.sentiment,
        iu.intensity,
        1 - (iu.embedding <=> query_embedding) AS similarity
    FROM insight_units iu
    WHERE
        iu.user_id = p_user_id
        AND iu.embedding IS NOT NULL
        AND iu.insight_date >= start_date
        AND iu.insight_date <= end_date
        AND 1 - (iu.embedding <=> query_embedding) > match_threshold
    ORDER BY iu.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- Function to get insight clusters by category
CREATE OR REPLACE FUNCTION get_category_insights(
    p_user_id uuid,
    p_category text,
    p_days_back int DEFAULT 30,
    p_limit int DEFAULT 100
)
RETURNS TABLE (
    id uuid,
    content text,
    insight_date timestamptz,
    sentiment text,
    intensity decimal,
    emotion_tags text[],
    is_inferred boolean
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        iu.id,
        iu.content,
        iu.insight_date,
        iu.sentiment,
        iu.intensity,
        iu.emotion_tags,
        iu.is_inferred
    FROM insight_units iu
    WHERE
        iu.user_id = p_user_id
        AND (iu.primary_category = p_category OR p_category = ANY(iu.secondary_categories))
        AND iu.insight_date >= NOW() - (p_days_back || ' days')::interval
    ORDER BY iu.insight_date DESC
    LIMIT p_limit;
END;
$$;

-- Function to get connection graph for an insight
CREATE OR REPLACE FUNCTION get_insight_connections(
    p_insight_id uuid,
    p_depth int DEFAULT 1
)
RETURNS TABLE (
    source_id uuid,
    source_content text,
    target_id uuid,
    target_content text,
    connection_type text,
    strength decimal,
    reasoning text
)
LANGUAGE sql
AS $$
    WITH RECURSIVE connection_graph AS (
        -- Base case: direct connections
        SELECT
            ic.source_insight_id,
            ic.target_insight_id,
            ic.connection_type,
            ic.strength,
            ic.reasoning,
            1 as depth
        FROM insight_connections ic
        WHERE ic.source_insight_id = p_insight_id
           OR ic.target_insight_id = p_insight_id

        UNION ALL

        -- Recursive case: connections of connections (if depth > 1)
        SELECT
            ic.source_insight_id,
            ic.target_insight_id,
            ic.connection_type,
            ic.strength,
            ic.reasoning,
            cg.depth + 1
        FROM insight_connections ic
        JOIN connection_graph cg ON (
            ic.source_insight_id = cg.target_insight_id
            OR ic.target_insight_id = cg.source_insight_id
        )
        WHERE cg.depth < p_depth
    )
    SELECT DISTINCT
        cg.source_insight_id,
        src.content,
        cg.target_insight_id,
        tgt.content,
        cg.connection_type,
        cg.strength,
        cg.reasoning
    FROM connection_graph cg
    JOIN insight_units src ON src.id = cg.source_insight_id
    JOIN insight_units tgt ON tgt.id = cg.target_insight_id;
$$;

-- Function to get user statistics
CREATE OR REPLACE FUNCTION get_user_stats(
    p_user_id uuid,
    p_days_back int DEFAULT 30
)
RETURNS TABLE (
    total_insights bigint,
    insights_by_category jsonb,
    sentiment_distribution jsonb,
    avg_intensity decimal,
    inferred_ratio decimal,
    total_patterns bigint,
    active_patterns bigint
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        (SELECT COUNT(*) FROM insight_units
         WHERE user_id = p_user_id
         AND insight_date >= NOW() - (p_days_back || ' days')::interval) as total_insights,

        (SELECT jsonb_object_agg(primary_category, cnt)
         FROM (
             SELECT primary_category, COUNT(*) as cnt
             FROM insight_units
             WHERE user_id = p_user_id
             AND insight_date >= NOW() - (p_days_back || ' days')::interval
             GROUP BY primary_category
         ) sub) as insights_by_category,

        (SELECT jsonb_object_agg(COALESCE(sentiment, 'unknown'), cnt)
         FROM (
             SELECT sentiment, COUNT(*) as cnt
             FROM insight_units
             WHERE user_id = p_user_id
             AND insight_date >= NOW() - (p_days_back || ' days')::interval
             GROUP BY sentiment
         ) sub) as sentiment_distribution,

        (SELECT AVG(intensity)
         FROM insight_units
         WHERE user_id = p_user_id
         AND insight_date >= NOW() - (p_days_back || ' days')::interval
         AND intensity IS NOT NULL) as avg_intensity,

        (SELECT COUNT(*)::decimal / NULLIF(COUNT(*) FILTER (WHERE NOT is_inferred), 0)
         FROM insight_units
         WHERE user_id = p_user_id
         AND insight_date >= NOW() - (p_days_back || ' days')::interval) as inferred_ratio,

        (SELECT COUNT(*)
         FROM patterns
         WHERE user_id = p_user_id) as total_patterns,

        (SELECT COUNT(*)
         FROM patterns
         WHERE user_id = p_user_id AND is_active = true) as active_patterns;
END;
$$;
