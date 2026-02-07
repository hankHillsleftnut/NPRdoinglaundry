-- Knowledge Graph System for Retrospect
-- Initial Schema Migration

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "vector";

-- ============================================
-- USERS TABLE (for multi-user support)
-- ============================================
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    apple_user_id TEXT UNIQUE NOT NULL,
    email TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_users_apple_user_id ON users(apple_user_id);

-- ============================================
-- DATA SOURCES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS data_sources (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    extraction_prompt TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- CATEGORIES TABLE - Topic Taxonomy
-- ============================================
CREATE TABLE IF NOT EXISTS categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    description TEXT,
    parent_category_id UUID REFERENCES categories(id),
    color TEXT,
    icon TEXT,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_categories_name ON categories(name);
CREATE INDEX idx_categories_parent ON categories(parent_category_id);

-- ============================================
-- RAW CONTENT TABLE - Original Data Before Processing
-- ============================================
CREATE TABLE IF NOT EXISTS raw_content (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content_type TEXT NOT NULL,
    content TEXT NOT NULL,
    content_date TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}',
    processing_status TEXT DEFAULT 'pending' CHECK (processing_status IN ('pending', 'processing', 'completed', 'failed')),
    processing_error TEXT,
    source_id UUID REFERENCES data_sources(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    processed_at TIMESTAMPTZ
);

CREATE INDEX idx_raw_content_user_id ON raw_content(user_id);
CREATE INDEX idx_raw_content_status ON raw_content(processing_status);
CREATE INDEX idx_raw_content_type ON raw_content(content_type);
CREATE INDEX idx_raw_content_created ON raw_content(created_at DESC);

-- ============================================
-- INSIGHT UNITS TABLE - Atomic Facts
-- ============================================
CREATE TABLE IF NOT EXISTS insight_units (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    raw_content_id UUID REFERENCES raw_content(id) ON DELETE SET NULL,
    content TEXT NOT NULL,
    primary_category TEXT NOT NULL,
    secondary_categories TEXT[] DEFAULT '{}',
    is_inferred BOOLEAN DEFAULT false,
    confidence_score DECIMAL(3,2) DEFAULT 1.0 CHECK (confidence_score >= 0 AND confidence_score <= 1),
    inference_reasoning TEXT,
    insight_date TIMESTAMPTZ NOT NULL,
    sentiment TEXT CHECK (sentiment IN ('positive', 'negative', 'neutral', 'mixed')),
    emotion_tags TEXT[] DEFAULT '{}',
    intensity DECIMAL(3,1) CHECK (intensity >= 1 AND intensity <= 10),
    embedding vector(3072),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_insight_units_user_id ON insight_units(user_id);
CREATE INDEX idx_insight_units_category ON insight_units(primary_category);
CREATE INDEX idx_insight_units_date ON insight_units(insight_date DESC);
CREATE INDEX idx_insight_units_inferred ON insight_units(is_inferred);
CREATE INDEX idx_insight_units_sentiment ON insight_units(sentiment);
CREATE INDEX idx_insight_units_raw_content ON insight_units(raw_content_id);

-- Vector similarity search index (IVFFlat for performance)
CREATE INDEX idx_insight_units_embedding ON insight_units
USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- ============================================
-- INSIGHT CONNECTIONS TABLE - Links Between Insights
-- ============================================
CREATE TABLE IF NOT EXISTS insight_connections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_insight_id UUID NOT NULL REFERENCES insight_units(id) ON DELETE CASCADE,
    target_insight_id UUID NOT NULL REFERENCES insight_units(id) ON DELETE CASCADE,
    connection_type TEXT NOT NULL CHECK (connection_type IN ('same_topic', 'causal', 'temporal', 'supports', 'contradicts')),
    strength DECIMAL(3,2) DEFAULT 0.5 CHECK (strength >= 0 AND strength <= 1),
    reasoning TEXT,
    is_bidirectional BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT unique_connection UNIQUE (source_insight_id, target_insight_id, connection_type)
);

CREATE INDEX idx_insight_connections_source ON insight_connections(source_insight_id);
CREATE INDEX idx_insight_connections_target ON insight_connections(target_insight_id);
CREATE INDEX idx_insight_connections_type ON insight_connections(connection_type);

-- ============================================
-- PATTERNS TABLE - Detected Patterns
-- ============================================
CREATE TABLE IF NOT EXISTS patterns (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    pattern_type TEXT NOT NULL CHECK (pattern_type IN ('correlation', 'trend', 'cycle', 'anomaly', 'habit')),
    categories TEXT[] DEFAULT '{}',
    supporting_insight_ids UUID[] DEFAULT '{}',
    confidence_score DECIMAL(3,2) DEFAULT 0.5 CHECK (confidence_score >= 0 AND confidence_score <= 1),
    frequency TEXT CHECK (frequency IN ('daily', 'weekly', 'monthly', 'occasional', 'one_time')),
    time_range_start TIMESTAMPTZ,
    time_range_end TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT true,
    user_acknowledged BOOLEAN DEFAULT false,
    user_feedback TEXT CHECK (user_feedback IN ('confirmed', 'rejected', 'unsure')),
    feedback_notes TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_validated_at TIMESTAMPTZ
);

CREATE INDEX idx_patterns_user_id ON patterns(user_id);
CREATE INDEX idx_patterns_type ON patterns(pattern_type);
CREATE INDEX idx_patterns_active ON patterns(is_active);
CREATE INDEX idx_patterns_created ON patterns(created_at DESC);

-- ============================================
-- PATTERN INSIGHTS JUNCTION TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS pattern_insights (
    pattern_id UUID NOT NULL REFERENCES patterns(id) ON DELETE CASCADE,
    insight_id UUID NOT NULL REFERENCES insight_units(id) ON DELETE CASCADE,
    relevance_score DECIMAL(3,2) DEFAULT 0.5,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    PRIMARY KEY (pattern_id, insight_id)
);

CREATE INDEX idx_pattern_insights_pattern ON pattern_insights(pattern_id);
CREATE INDEX idx_pattern_insights_insight ON pattern_insights(insight_id);

-- ============================================
-- PROCESSING QUEUE TABLE (for async jobs)
-- ============================================
CREATE TABLE IF NOT EXISTS processing_queue (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_type TEXT NOT NULL CHECK (job_type IN ('extract_insights', 'generate_embeddings', 'find_connections', 'detect_patterns')),
    payload JSONB NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    priority INTEGER DEFAULT 0,
    attempts INTEGER DEFAULT 0,
    max_attempts INTEGER DEFAULT 3,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
);

CREATE INDEX idx_processing_queue_status ON processing_queue(status);
CREATE INDEX idx_processing_queue_type ON processing_queue(job_type);
CREATE INDEX idx_processing_queue_priority ON processing_queue(priority DESC, created_at ASC);

-- ============================================
-- ANALYTICS CACHE TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS analytics_cache (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    cache_key TEXT NOT NULL,
    cache_value JSONB NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT unique_user_cache_key UNIQUE (user_id, cache_key)
);

CREATE INDEX idx_analytics_cache_user ON analytics_cache(user_id);
CREATE INDEX idx_analytics_cache_expires ON analytics_cache(expires_at);

-- ============================================
-- UPDATED_AT TRIGGER FUNCTION
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply updated_at triggers
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_insight_units_updated_at
    BEFORE UPDATE ON insight_units
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_patterns_updated_at
    BEFORE UPDATE ON patterns
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================

-- Enable RLS on all user-scoped tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE raw_content ENABLE ROW LEVEL SECURITY;
ALTER TABLE insight_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE insight_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE patterns ENABLE ROW LEVEL SECURITY;
ALTER TABLE pattern_insights ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_cache ENABLE ROW LEVEL SECURITY;

-- RLS Policies (users can only access their own data)
-- Note: These assume auth.uid() returns the user's ID from Supabase Auth

CREATE POLICY "Users can view own profile" ON users
    FOR SELECT USING (id = auth.uid());

CREATE POLICY "Users can update own profile" ON users
    FOR UPDATE USING (id = auth.uid());

CREATE POLICY "Users can view own raw_content" ON raw_content
    FOR ALL USING (user_id = auth.uid());

CREATE POLICY "Users can view own insight_units" ON insight_units
    FOR ALL USING (user_id = auth.uid());

CREATE POLICY "Users can view own connections" ON insight_connections
    FOR ALL USING (
        source_insight_id IN (SELECT id FROM insight_units WHERE user_id = auth.uid())
    );

CREATE POLICY "Users can view own patterns" ON patterns
    FOR ALL USING (user_id = auth.uid());

CREATE POLICY "Users can view own pattern_insights" ON pattern_insights
    FOR ALL USING (
        pattern_id IN (SELECT id FROM patterns WHERE user_id = auth.uid())
    );

CREATE POLICY "Users can view own analytics_cache" ON analytics_cache
    FOR ALL USING (user_id = auth.uid());
