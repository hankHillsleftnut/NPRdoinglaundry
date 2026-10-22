import type { PGlite } from '@electric-sql/pglite' with { 'resolution-mode': 'import' };

/**
 * The agent's tables the brief and guess doors read, as the agent's migrations
 * define them (retrospect-agent `supabase/migrations/128_daily_briefs.sql`,
 * `155_brief_audio.sql` and `149_hypotheses_and_dials.sql`), for a backend test database. The backend's own
 * migrations never create these: production and staging get them from the
 * agent's migrate command. Kept to the columns the doors touch, verbatim in
 * type and default, so a mapping that works here works on the real rows.
 */
export const AGENT_BRIEF_TABLES_SQL = `
  ALTER TABLE users ADD COLUMN IF NOT EXISTS daily_brief_enabled BOOLEAN NOT NULL DEFAULT false;
  ALTER TABLE users ADD COLUMN IF NOT EXISTS voice_persona TEXT;

  CREATE TABLE IF NOT EXISTS daily_briefs (
    id                     UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    brief_date             DATE NOT NULL,
    kind                   TEXT NOT NULL CHECK (kind IN ('brief', 'quiet')),
    through_line           TEXT NOT NULL,
    spine_question_id      SMALLINT,
    spine_movement         TEXT,
    items                  JSONB NOT NULL DEFAULT '[]',
    dropped                INTEGER NOT NULL DEFAULT 0,
    model_version          TEXT,
    cost_usd               NUMERIC(8, 4) NOT NULL DEFAULT 0,
    created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    audio_path             TEXT,
    audio_status           TEXT NOT NULL DEFAULT 'none' CHECK (audio_status IN ('none', 'making', 'ready', 'failed')),
    audio_duration_seconds NUMERIC(8, 2),
    audio_parts            JSONB NOT NULL DEFAULT '[]',
    audio_chars            INTEGER,
    audio_updated_at       TIMESTAMPTZ,
    UNIQUE (user_id, brief_date)
  );
  CREATE INDEX IF NOT EXISTS idx_daily_briefs_user_date ON daily_briefs(user_id, brief_date DESC);

  -- 149_hypotheses_and_dials.sql: the rows the guess doors read for ownership and status.
  CREATE TABLE IF NOT EXISTS hypotheses (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    framework       TEXT NOT NULL,
    domain_id       TEXT,
    question        TEXT NOT NULL,
    rationale       TEXT,
    supports        JSONB NOT NULL DEFAULT '[]',
    status          TEXT NOT NULL DEFAULT 'stored' CHECK (status IN ('stored', 'offered', 'confirmed', 'declined', 'expired')),
    offered_count   INTEGER NOT NULL DEFAULT 0,
    last_offered_at TIMESTAMPTZ,
    status_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    model_version   TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
  );
`;

export async function createAgentBriefTables(db: PGlite): Promise<void> {
  await db.exec(AGENT_BRIEF_TABLES_SQL);
}
