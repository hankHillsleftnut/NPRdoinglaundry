-- 004 · podcast_episodes and users.voice_persona as numbered migrations (M14 B0.4)
--
-- Both existed only in supabase/combined_migration.sql, so a database built from
-- the numbered migrations (001–003) lacked them. This file is idempotent: on a
-- database that already has them (production), it changes nothing.

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS voice_persona TEXT DEFAULT 'thoughtful_friend';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'users_voice_persona_check'
    ) THEN
        ALTER TABLE users ADD CONSTRAINT users_voice_persona_check
            CHECK (voice_persona IN ('thoughtful_friend', 'wise_mentor', 'energetic_host')) NOT VALID;
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS podcast_episodes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    script TEXT NOT NULL,
    audio_url TEXT,
    duration_seconds INTEGER,
    mood TEXT,
    generation_type TEXT DEFAULT 'weekly' CHECK (generation_type IN ('weekly', 'on_demand', 'milestone')),
    status TEXT DEFAULT 'generating' CHECK (status IN ('generating', 'ready', 'failed')),
    insight_ids UUID[] DEFAULT '{}',
    goal_ids UUID[] DEFAULT '{}',
    research_citations JSONB DEFAULT '[]',
    outline JSONB DEFAULT '{}',
    episode_number INTEGER,
    covers_period_start TIMESTAMPTZ,
    covers_period_end TIMESTAMPTZ,
    previous_episode_id UUID REFERENCES podcast_episodes(id),
    topics_covered TEXT[] DEFAULT '{}',
    error_message TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_podcast_episodes_user ON podcast_episodes(user_id);
CREATE INDEX IF NOT EXISTS idx_podcast_episodes_status ON podcast_episodes(status);
CREATE INDEX IF NOT EXISTS idx_podcast_episodes_created ON podcast_episodes(created_at DESC);

ALTER TABLE podcast_episodes ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'podcast_episodes' AND policyname = 'Users can view own episodes'
    ) THEN
        CREATE POLICY "Users can view own episodes" ON podcast_episodes FOR ALL USING (user_id = auth.uid());
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_podcast_episodes_updated_at'
    ) THEN
        CREATE TRIGGER update_podcast_episodes_updated_at
            BEFORE UPDATE ON podcast_episodes
            FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;
