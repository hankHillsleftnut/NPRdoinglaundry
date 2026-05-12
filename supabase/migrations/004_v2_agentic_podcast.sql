-- Retrospect v2: agentic podcast + simplified ingestion
-- Migration 004: user_preferences, suggested_goals, podcast_episodes.summary,
--                plus relaxed NOT NULL on observations.goal_id and insights.goal_id
--                to support the v2 ingestion path where Claude may extract an insight
--                that does not map to any existing goal (unassigned pattern).

-- ============================================
-- USER_PREFERENCES TABLE
-- Podcast tone / trusted voice / pacing. Derived from post-episode feedback
-- over time (not just user-set). Stage 2 agent and Stage 3 script generator
-- both read from this.
-- ============================================
CREATE TABLE IF NOT EXISTS user_preferences (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    tone JSONB DEFAULT '{}',                  -- free-form tone knobs the script generator can reference
    trusted_voice_description TEXT,           -- prose description of "someone this user trusts"
    pacing TEXT,                              -- e.g. "slow, reflective" | "energetic" | "direct"
    focus_areas TEXT[] DEFAULT '{}',          -- which goals / life areas to emphasize next episode
    avoid_topics TEXT[] DEFAULT '{}',         -- topics the user explicitly asked to avoid
    last_podcast_feedback TEXT,               -- most recent free-text feedback from the user
    last_feedback_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own preferences" ON user_preferences
    FOR ALL USING (user_id = auth.uid());

-- ============================================
-- SUGGESTED_GOALS TABLE
-- Claude's ingestion pass can detect a pattern that isn't yet a tracked goal.
-- We surface these to the user for accept/dismiss rather than auto-creating goals.
-- ============================================
CREATE TABLE IF NOT EXISTS suggested_goals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    rationale TEXT NOT NULL,                    -- why the model thinks this is a goal
    supporting_insight_ids UUID[] DEFAULT '{}', -- insights/observations that triggered the suggestion
    supporting_observation_ids UUID[] DEFAULT '{}',
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'accepted', 'dismissed')),
    accepted_goal_id UUID REFERENCES goals(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_suggested_goals_user_status ON suggested_goals(user_id, status);

ALTER TABLE suggested_goals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own suggested goals" ON suggested_goals
    FOR ALL USING (user_id = auth.uid());

-- ============================================
-- PODCAST_EPISODES: 2-paragraph continuity summary
-- The v2 Stage 2 agent calls search_previous_podcasts which vector-searches
-- on summary_embedding for non-repetition and continuity callbacks.
-- ============================================
ALTER TABLE podcast_episodes
    ADD COLUMN IF NOT EXISTS summary TEXT,
    ADD COLUMN IF NOT EXISTS summary_embedding vector(3072);

CREATE INDEX IF NOT EXISTS idx_podcast_episodes_summary_embedding ON podcast_episodes
    USING ivfflat (summary_embedding vector_cosine_ops) WITH (lists = 50);

-- ============================================
-- Relax goal_id NOT NULL on observations and insights
-- v2 ingestion may extract an insight / observation that represents a pattern
-- not yet tied to any active goal. These feed suggested_goals surfacing.
-- ============================================
ALTER TABLE observations ALTER COLUMN goal_id DROP NOT NULL;
ALTER TABLE insights ALTER COLUMN goal_id DROP NOT NULL;

-- ============================================
-- Pipeline run type additions for v2
-- ============================================
ALTER TABLE pipeline_runs DROP CONSTRAINT IF EXISTS pipeline_runs_run_type_check;
ALTER TABLE pipeline_runs ADD CONSTRAINT pipeline_runs_run_type_check
    CHECK (run_type IN (
        'observation_extraction',
        'insight_generation',
        'full_pipeline',
        'v2_ingestion',
        'v2_podcast'
    ));

-- ============================================
-- Agent tool-call trace for Stage 2 observability
-- One row per tool invocation in the agent loop. We use pipeline_runs.id as the
-- run key so traces cascade with the run.
-- ============================================
CREATE TABLE IF NOT EXISTS agent_tool_traces (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pipeline_run_id UUID NOT NULL REFERENCES pipeline_runs(id) ON DELETE CASCADE,
    step_index INT NOT NULL,
    tool_name TEXT NOT NULL,
    tool_input JSONB NOT NULL,
    tool_output_summary TEXT,          -- short stringified summary of what the tool returned
    tool_output_items_count INT,       -- e.g. number of observations/insights/citations returned
    duration_ms INT,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_agent_tool_traces_run ON agent_tool_traces(pipeline_run_id, step_index);

ALTER TABLE agent_tool_traces ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own agent traces" ON agent_tool_traces
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM pipeline_runs pr
            WHERE pr.id = agent_tool_traces.pipeline_run_id
              AND pr.user_id = auth.uid()
        )
    );

-- ============================================
-- DATABASE FUNCTIONS
-- ============================================

-- Match previous podcast episodes by vector similarity on their summary.
-- Used by the Stage 2 agent's search_previous_podcasts tool for non-repetition
-- and continuity callbacks.
CREATE OR REPLACE FUNCTION match_podcast_episodes(
    query_embedding vector(3072),
    match_threshold float,
    match_count int,
    filter_user_id uuid
)
RETURNS TABLE (
    id uuid,
    title text,
    summary text,
    created_at timestamptz,
    episode_number int,
    similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id,
        p.title,
        p.summary,
        p.created_at,
        p.episode_number,
        1 - (p.summary_embedding <=> query_embedding) AS similarity
    FROM podcast_episodes p
    WHERE p.user_id = filter_user_id
      AND p.status = 'ready'
      AND p.summary_embedding IS NOT NULL
      AND 1 - (p.summary_embedding <=> query_embedding) > match_threshold
    ORDER BY p.summary_embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- Match raw_content by vector similarity. Raw content does not currently carry
-- embeddings at write time; this is a last-resort tool that falls back to ILIKE.
-- When embeddings are populated it will use them; until then it returns a text-search.
CREATE OR REPLACE FUNCTION search_raw_content_text(
    search_query text,
    filter_user_id uuid,
    match_count int
)
RETURNS TABLE (
    id uuid,
    content_type text,
    content text,
    content_date timestamptz,
    created_at timestamptz
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        r.id,
        r.content_type,
        r.content,
        r.content_date,
        r.created_at
    FROM raw_content r
    WHERE r.user_id = filter_user_id
      AND r.content ILIKE '%' || search_query || '%'
    ORDER BY r.created_at DESC
    LIMIT match_count;
END;
$$;

-- Extend match_observations with date-range filters (v2 Stage 2 agent needs to
-- restrict searches to specific time windows — e.g. "older than 30 days").
-- We create a new function rather than altering the existing one to avoid
-- breaking legacy callers.
CREATE OR REPLACE FUNCTION match_observations_dated(
    query_embedding vector(3072),
    match_threshold float,
    match_count int,
    filter_user_id uuid,
    date_start timestamptz DEFAULT NULL,
    date_end timestamptz DEFAULT NULL,
    filter_goal_id uuid DEFAULT NULL
)
RETURNS TABLE (
    id uuid,
    content text,
    reason_why text,
    goal_id uuid,
    observation_date timestamptz,
    similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        o.id,
        o.content,
        o.reason_why,
        o.goal_id,
        o.observation_date,
        1 - (o.embedding <=> query_embedding) AS similarity
    FROM observations o
    WHERE o.user_id = filter_user_id
      AND o.embedding IS NOT NULL
      AND (filter_goal_id IS NULL OR o.goal_id = filter_goal_id)
      AND (date_start IS NULL OR o.observation_date >= date_start)
      AND (date_end IS NULL OR o.observation_date <= date_end)
      AND 1 - (o.embedding <=> query_embedding) > match_threshold
    ORDER BY o.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

CREATE OR REPLACE FUNCTION match_insights_dated(
    query_embedding vector(3072),
    match_threshold float,
    match_count int,
    filter_user_id uuid,
    date_start timestamptz DEFAULT NULL,
    date_end timestamptz DEFAULT NULL,
    filter_goal_id uuid DEFAULT NULL
)
RETURNS TABLE (
    id uuid,
    title text,
    content text,
    evidence_summary text,
    goal_id uuid,
    confidence_score decimal,
    created_at timestamptz,
    supporting_observation_ids uuid[],
    similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        i.id,
        i.title,
        i.content,
        i.evidence_summary,
        i.goal_id,
        i.confidence_score,
        i.created_at,
        i.supporting_observation_ids,
        1 - (i.embedding <=> query_embedding) AS similarity
    FROM insights i
    WHERE i.user_id = filter_user_id
      AND i.embedding IS NOT NULL
      AND (filter_goal_id IS NULL OR i.goal_id = filter_goal_id)
      AND (date_start IS NULL OR i.created_at >= date_start)
      AND (date_end IS NULL OR i.created_at <= date_end)
      AND 1 - (i.embedding <=> query_embedding) > match_threshold
    ORDER BY i.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- ============================================
-- TRIGGERS
-- ============================================
CREATE TRIGGER update_user_preferences_updated_at
    BEFORE UPDATE ON user_preferences
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_suggested_goals_updated_at
    BEFORE UPDATE ON suggested_goals
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
