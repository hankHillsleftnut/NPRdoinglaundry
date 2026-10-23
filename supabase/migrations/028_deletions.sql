-- ============================================================================
-- 028: account deletion -- lock first, finish in the background (BE0.7,
--      BE6.6a, BE6.6b; App Review 5.1.1(v))
--      (028: the next free backend number; main ends at 027 and no open
--      backend branch adds a migration)
--
-- Goal: `DELETE /v2/account` answers 202 only once the account is locked, and
-- a deletion can never be left half done: a crash or a redeploy part way
-- through is picked up again from this log.
--
-- Why: until now an account could only be deleted by hand. Now:
--   account_deletions          the deletion log. One row per person (user_id
--                              is UNIQUE, so a second or concurrent request
--                              gets the same id). NO foreign key to users: the
--                              row outlives the users row it describes. It
--                              holds ids, states, counts and result words
--                              only (CHECKed), never an Apple code or token, a
--                              ciphertext, an email, a name or an Apple
--                              subject.
--   lock_account_for_deletion  ONE transaction: writes the row ('requested'),
--                              sets users.access 'suspended', bumps
--                              users.token_version (every access token dies at
--                              once), ends every refresh family. A fresh Apple
--                              token sealed inside the request is stored on the
--                              users row in the same transaction. With Apple
--                              required and no token stored or given, it
--                              changes nothing and says so.
--   account_deletion_prepare   what the door reads before any Apple call: the
--                              Apple subject, whether a token is stored, an
--                              existing deletion
--   claim_account_deletion,    one worker at a time per row (a lease), and the
--   claim_due_account_deletions  sweeper's pick of unfinished rows
--   account_deletion_apple_token the sealed token, only for a user under deletion
--   note_account_deletion      a step's result word / counts
--   delete_account_user        deletes the users row (everything cascades) for
--                              a user under deletion, and nothing else
--   defer_account_deletion,    let go of the lease until the next try; done
--   finish_account_deletion
--
-- Every key to users in 001-028 is CASCADE or SET NULL
-- (tests/account-lock.test.ts checks the migrated schema), so the users-row
-- delete cannot be blocked by an orphan.
--
-- Additive. RLS on, no policies; nothing for anon/authenticated; service_role
-- only (like 019 and 025). Files only: never applied to production by an agent.
-- ============================================================================

CREATE TABLE IF NOT EXISTS account_deletions (
    id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    -- No REFERENCES: the log must survive the users row.
    user_id              UUID NOT NULL UNIQUE,
    state                TEXT NOT NULL DEFAULT 'requested'
                         CHECK (state IN ('requested', 'user_deleted', 'deleted')),
    apple                TEXT CHECK (apple IN ('revoked', 'already_revoked', 'no_token', 'skipped', 'failed')),
    sweep_before         TEXT CHECK (sweep_before IN ('ok', 'failed')),
    sweep_after          TEXT CHECK (sweep_after IN ('ok', 'failed')),
    diagnostics          TEXT CHECK (diagnostics IN ('ok', 'failed')),
    grants_failed        INTEGER NOT NULL DEFAULT 0 CHECK (grants_failed >= 0),
    objects_skipped      INTEGER NOT NULL DEFAULT 0 CHECK (objects_skipped >= 0),
    diagnostics_removed  INTEGER NOT NULL DEFAULT 0 CHECK (diagnostics_removed >= 0),
    runs                 INTEGER NOT NULL DEFAULT 0 CHECK (runs >= 0),
    claimed_until        TIMESTAMPTZ,
    next_run_at          TIMESTAMPTZ NOT NULL,
    created_at           TIMESTAMPTZ NOT NULL,
    user_deleted_at      TIMESTAMPTZ,
    finished_at          TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_account_deletions_open ON account_deletions(next_run_at) WHERE state <> 'deleted';

ALTER TABLE account_deletions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON account_deletions FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON account_deletions TO service_role;

-- The row as the worker sees it (no user data beyond the id).
CREATE OR REPLACE FUNCTION account_deletion_json(d account_deletions)
RETURNS JSONB
LANGUAGE sql
STABLE
SET search_path = public
AS $$
    SELECT jsonb_build_object(
        'id', d.id, 'user_id', d.user_id, 'state', d.state, 'apple', d.apple,
        'sweep_before', d.sweep_before, 'sweep_after', d.sweep_after, 'diagnostics', d.diagnostics,
        'grants_failed', d.grants_failed, 'objects_skipped', d.objects_skipped,
        'diagnostics_removed', d.diagnostics_removed, 'runs', d.runs);
$$;

-- Before any Apple call: whose Apple account this is, whether a token is kept,
-- and a deletion already under way (then the door answers it, calling no one).
CREATE OR REPLACE FUNCTION account_deletion_prepare(p_user UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_subject TEXT;
    v_has     BOOLEAN;
    v_id      UUID;
BEGIN
    SELECT apple_user_id, apple_refresh_token_ciphertext IS NOT NULL INTO v_subject, v_has FROM users WHERE id = p_user;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('outcome', 'no_user');
    END IF;
    SELECT id INTO v_id FROM account_deletions WHERE user_id = p_user;
    RETURN jsonb_build_object('outcome', 'ok', 'apple_user_id', v_subject, 'has_apple_token', v_has, 'deletion_id', v_id);
END;
$$;

-- The lock. Returns
--   { outcome: 'locked', id, created }            locked now (created true) or already
--   { outcome: 'apple_confirmation_required' }    Apple required, no token kept or given: nothing changed
--   { outcome: 'no_user' }
CREATE OR REPLACE FUNCTION lock_account_for_deletion(
    p_user UUID, p_now TIMESTAMPTZ, p_apple_enabled BOOLEAN, p_apple_ciphertext TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_cipher TEXT;
    v_id     UUID;
BEGIN
    -- The users row lock serializes two requests from the same person.
    SELECT apple_refresh_token_ciphertext INTO v_cipher FROM users WHERE id = p_user FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('outcome', 'no_user');
    END IF;

    SELECT id INTO v_id FROM account_deletions WHERE user_id = p_user;
    IF FOUND THEN
        RETURN jsonb_build_object('outcome', 'locked', 'id', v_id, 'created', false);
    END IF;

    IF p_apple_enabled AND p_apple_ciphertext IS NULL AND v_cipher IS NULL THEN
        RETURN jsonb_build_object('outcome', 'apple_confirmation_required');
    END IF;

    IF p_apple_enabled AND p_apple_ciphertext IS NOT NULL THEN
        UPDATE users SET apple_refresh_token_ciphertext = p_apple_ciphertext, apple_refresh_token_at = p_now WHERE id = p_user;
    END IF;

    UPDATE users SET access = 'suspended', token_version = token_version + 1 WHERE id = p_user;
    DELETE FROM refresh_grace WHERE token_hash IN (SELECT token_hash FROM refresh_tokens WHERE user_id = p_user);
    UPDATE refresh_tokens SET revoked_at = p_now WHERE user_id = p_user AND revoked_at IS NULL;

    INSERT INTO account_deletions (user_id, state, apple, next_run_at, created_at)
    VALUES (p_user, 'requested', CASE WHEN p_apple_enabled THEN NULL ELSE 'skipped' END, p_now, p_now)
    RETURNING id INTO v_id;
    RETURN jsonb_build_object('outcome', 'locked', 'id', v_id, 'created', true);
END;
$$;

-- One worker per row: the request's own background run and the sweeper never
-- run the same deletion at once. A crashed worker's lease runs out and the
-- sweeper takes the row.
CREATE OR REPLACE FUNCTION claim_account_deletion(p_id UUID, p_now TIMESTAMPTZ, p_lease_seconds INTEGER)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_row account_deletions%ROWTYPE;
BEGIN
    UPDATE account_deletions
       SET claimed_until = p_now + make_interval(secs => p_lease_seconds), runs = runs + 1
     WHERE id = p_id AND state <> 'deleted' AND next_run_at <= p_now AND (claimed_until IS NULL OR claimed_until <= p_now)
    RETURNING * INTO v_row;
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;
    RETURN account_deletion_json(v_row);
END;
$$;

CREATE OR REPLACE FUNCTION claim_due_account_deletions(p_now TIMESTAMPTZ, p_lease_seconds INTEGER, p_limit INTEGER)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_out JSONB;
BEGIN
    WITH due AS (
        SELECT id FROM account_deletions
         WHERE state <> 'deleted' AND next_run_at <= p_now AND (claimed_until IS NULL OR claimed_until <= p_now)
         ORDER BY next_run_at
         LIMIT GREATEST(p_limit, 0)
         FOR UPDATE SKIP LOCKED
    ), claimed AS (
        UPDATE account_deletions d
           SET claimed_until = p_now + make_interval(secs => p_lease_seconds), runs = d.runs + 1
          FROM due WHERE d.id = due.id
        RETURNING account_deletion_json(d) AS row_json
    )
    SELECT coalesce(jsonb_agg(row_json), '[]'::jsonb) INTO v_out FROM claimed;
    RETURN v_out;
END;
$$;

-- The sealed Apple token, only while that person's deletion is open and the
-- users row still exists.
CREATE OR REPLACE FUNCTION account_deletion_apple_token(p_id UUID)
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT u.apple_refresh_token_ciphertext
      FROM account_deletions d JOIN users u ON u.id = d.user_id
     WHERE d.id = p_id AND d.state = 'requested';
$$;

-- A step's outcome. NULL leaves a field as it is; the CHECKs keep it to result words.
CREATE OR REPLACE FUNCTION note_account_deletion(
    p_id UUID, p_apple TEXT, p_sweep_before TEXT, p_sweep_after TEXT, p_diagnostics TEXT,
    p_grants_failed INTEGER, p_objects_skipped INTEGER, p_diagnostics_removed INTEGER
)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    UPDATE account_deletions SET
        apple               = COALESCE(p_apple, apple),
        sweep_before        = COALESCE(p_sweep_before, sweep_before),
        sweep_after         = COALESCE(p_sweep_after, sweep_after),
        diagnostics         = COALESCE(p_diagnostics, diagnostics),
        grants_failed       = COALESCE(p_grants_failed, grants_failed),
        objects_skipped     = COALESCE(p_objects_skipped, objects_skipped),
        diagnostics_removed = COALESCE(p_diagnostics_removed, diagnostics_removed)
     WHERE id = p_id;
$$;

-- Deletes the users row of a person under deletion (everything keyed to it
-- cascades), and marks the row. Only a 'requested' deletion can delete a
-- users row, so this can never reach anyone else. Safe to repeat.
CREATE OR REPLACE FUNCTION delete_account_user(p_id UUID, p_now TIMESTAMPTZ)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE v_row account_deletions%ROWTYPE;
BEGIN
    SELECT * INTO v_row FROM account_deletions WHERE id = p_id FOR UPDATE;
    IF NOT FOUND THEN
        RETURN 'not_found';
    END IF;
    IF v_row.state <> 'requested' THEN
        RETURN v_row.state;
    END IF;
    DELETE FROM users WHERE id = v_row.user_id;
    UPDATE account_deletions SET state = 'user_deleted', user_deleted_at = p_now WHERE id = p_id;
    RETURN 'user_deleted';
END;
$$;

CREATE OR REPLACE FUNCTION defer_account_deletion(p_id UUID, p_next_run_at TIMESTAMPTZ)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    UPDATE account_deletions SET claimed_until = NULL, next_run_at = p_next_run_at WHERE id = p_id AND state <> 'deleted';
$$;

CREATE OR REPLACE FUNCTION finish_account_deletion(p_id UUID, p_now TIMESTAMPTZ)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    UPDATE account_deletions SET state = 'deleted', finished_at = p_now, claimed_until = NULL
     WHERE id = p_id AND state = 'user_deleted';
$$;

REVOKE ALL ON FUNCTION account_deletion_json(account_deletions) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION account_deletion_prepare(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION lock_account_for_deletion(UUID, TIMESTAMPTZ, BOOLEAN, TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION claim_account_deletion(UUID, TIMESTAMPTZ, INTEGER) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION claim_due_account_deletions(TIMESTAMPTZ, INTEGER, INTEGER) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION account_deletion_apple_token(UUID) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION note_account_deletion(UUID, TEXT, TEXT, TEXT, TEXT, INTEGER, INTEGER, INTEGER) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION delete_account_user(UUID, TIMESTAMPTZ) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION defer_account_deletion(UUID, TIMESTAMPTZ) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION finish_account_deletion(UUID, TIMESTAMPTZ) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION account_deletion_json(account_deletions) TO service_role;
GRANT EXECUTE ON FUNCTION account_deletion_prepare(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION lock_account_for_deletion(UUID, TIMESTAMPTZ, BOOLEAN, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION claim_account_deletion(UUID, TIMESTAMPTZ, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION claim_due_account_deletions(TIMESTAMPTZ, INTEGER, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION account_deletion_apple_token(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION note_account_deletion(UUID, TEXT, TEXT, TEXT, TEXT, INTEGER, INTEGER, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION delete_account_user(UUID, TIMESTAMPTZ) TO service_role;
GRANT EXECUTE ON FUNCTION defer_account_deletion(UUID, TIMESTAMPTZ) TO service_role;
GRANT EXECUTE ON FUNCTION finish_account_deletion(UUID, TIMESTAMPTZ) TO service_role;
