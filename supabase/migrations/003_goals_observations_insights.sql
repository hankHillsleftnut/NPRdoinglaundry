-- Goals, Observations, and Insights Pipeline
-- Migration 003: Adds goal-based observation extraction and insight synthesis

-- ============================================
-- GOALS TABLE - User's personal goals
-- ============================================
CREATE TABLE IF NOT EXISTS goals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    embedding vector(3072),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_goals_user_id ON goals(user_id);
CREATE INDEX idx_goals_active ON goals(user_id, is_active);
CREATE INDEX idx_goals_embedding ON goals
    USING ivfflat (embedding vector_cosine_ops) WITH (lists = 50);

-- ============================================
-- OBSERVATIONS TABLE - Atomic, goal-relevant facts
-- Each observation is one fact extracted from raw content
-- that is relevant to a specific user goal.
-- ============================================
CREATE TABLE IF NOT EXISTS observations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    goal_id UUID NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
    raw_content_id UUID REFERENCES raw_content(id) ON DELETE SET NULL,
    content TEXT NOT NULL,            -- the atomic fact / snippet
    reason_why TEXT NOT NULL,         -- why this is relevant to the goal
    confidence_score DECIMAL(3,2) DEFAULT 0.8 CHECK (confidence_score >= 0 AND confidence_score <= 1),
    observation_date TIMESTAMPTZ NOT NULL,
    embedding vector(3072),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_observations_user_id ON observations(user_id);
CREATE INDEX idx_observations_goal_id ON observations(goal_id);
CREATE INDEX idx_observations_date ON observations(observation_date DESC);
CREATE INDEX idx_observations_raw_content ON observations(raw_content_id);
CREATE INDEX idx_observations_embedding ON observations
    USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- ============================================
-- INSIGHTS TABLE - Higher-level conclusions
-- Each insight is synthesized from a cluster of observations
-- for a specific goal.
-- ============================================
CREATE TABLE IF NOT EXISTS insights (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    goal_id UUID NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
    title TEXT NOT NULL,                -- short headline
    content TEXT NOT NULL,              -- the full insight / conclusion
    evidence_summary TEXT NOT NULL,     -- summary of supporting observations
    supporting_observation_ids UUID[] DEFAULT '{}',
    confidence_score DECIMAL(3,2) DEFAULT 0.7 CHECK (confidence_score >= 0 AND confidence_score <= 1),
    time_range_start TIMESTAMPTZ,
    time_range_end TIMESTAMPTZ,
    embedding vector(3072),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_insights_user_id ON insights(user_id);
CREATE INDEX idx_insights_goal_id ON insights(goal_id);
CREATE INDEX idx_insights_created ON insights(created_at DESC);
CREATE INDEX idx_insights_embedding ON insights
    USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- ============================================
-- PIPELINE RUNS TABLE - Track each pipeline execution
-- ============================================
CREATE TABLE IF NOT EXISTS pipeline_runs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    run_type TEXT NOT NULL CHECK (run_type IN ('observation_extraction', 'insight_generation', 'full_pipeline')),
    status TEXT DEFAULT 'running' CHECK (status IN ('running', 'completed', 'failed')),
    raw_content_ids UUID[] DEFAULT '{}',
    observations_created INTEGER DEFAULT 0,
    insights_created INTEGER DEFAULT 0,
    error_message TEXT,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

CREATE INDEX idx_pipeline_runs_user ON pipeline_runs(user_id);
CREATE INDEX idx_pipeline_runs_status ON pipeline_runs(status);

-- ============================================
-- TRIGGERS
-- ============================================
CREATE TRIGGER update_goals_updated_at
    BEFORE UPDATE ON goals
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_insights_updated_at
    BEFORE UPDATE ON insights
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================
ALTER TABLE goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE observations ENABLE ROW LEVEL SECURITY;
ALTER TABLE insights ENABLE ROW LEVEL SECURITY;
ALTER TABLE pipeline_runs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own goals" ON goals
    FOR ALL USING (user_id = auth.uid());

CREATE POLICY "Users can view own observations" ON observations
    FOR ALL USING (user_id = auth.uid());

CREATE POLICY "Users can view own insights" ON insights
    FOR ALL USING (user_id = auth.uid());

CREATE POLICY "Users can view own pipeline_runs" ON pipeline_runs
    FOR ALL USING (user_id = auth.uid());

-- ============================================
-- DATABASE FUNCTIONS
-- ============================================

-- Match observations by vector similarity (for clustering)
CREATE OR REPLACE FUNCTION match_observations(
    query_embedding vector(3072),
    match_threshold float,
    match_count int,
    filter_user_id uuid,
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
      AND 1 - (o.embedding <=> query_embedding) > match_threshold
    ORDER BY o.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- Match insights by vector similarity (for future search-your-brain)
CREATE OR REPLACE FUNCTION match_user_insights(
    query_embedding vector(3072),
    match_threshold float,
    match_count int,
    filter_user_id uuid,
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
        1 - (i.embedding <=> query_embedding) AS similarity
    FROM insights i
    WHERE i.user_id = filter_user_id
      AND i.embedding IS NOT NULL
      AND (filter_goal_id IS NULL OR i.goal_id = filter_goal_id)
      AND 1 - (i.embedding <=> query_embedding) > match_threshold
    ORDER BY i.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;
