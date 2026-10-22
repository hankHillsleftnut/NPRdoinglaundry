-- ============================================================================
-- 021: the invite's serial, the redeem date and the redeem key; the check
--      function; redeem made idempotent for the redeemer (BE2.0b)
--      (021: the card said 013; 013-018 are assigned in plans-consistency.md §3,
--      019 is merged, 020 is taken by the BE0.12 follow-up)
--
-- Goal: the ticket prints only after sign-in and only what's true, and the
-- code is spent at the tear, exactly once, even if the tear's response is lost
-- (contract 01 §2.2-§2.3; the founder's board, 21 Oct).
--
-- Why: the ticket shows "no. 0412" and the kept stub shows the day it was torn,
-- and the app must be able to look at a code before spending it. This adds:
--   invites.serial       the invite's place in the order invites were made,
--                        from invite_serial_seq, given at creation (minting,
--                        approval, the three member invites), so a code's number
--                        is the same on the link page, the preview, the check
--                        and the stub; existing rows numbered in created_at order
--   invites.redeemed_on  the calendar date of the tear in the redeemer's zone
--                        (computed by the door from X-Time-Zone, UTC without it)
--   invites.redeem_key   the Idempotency-Key the tear was sent with, kept on the
--                        row it spent: the same person sending the same key with
--                        another code is a mismatch; no separate key store
--   invite_check         what the ticket says, or why the code can't be used,
--                        reading nothing it doesn't need: never code_ciphertext
--   redeem_invite        new signature (key and date in, serial and date out);
--                        the same decision order as before, with the key's
--                        replay and mismatch checked first
--
-- Additive. RLS stays on; nothing for anon/authenticated; service_role only.
-- Files only: never applied to production by an agent.
-- ============================================================================

CREATE SEQUENCE IF NOT EXISTS invite_serial_seq;
ALTER TABLE invites ADD COLUMN IF NOT EXISTS serial BIGINT;
ALTER TABLE invites ADD COLUMN IF NOT EXISTS redeemed_on DATE;
ALTER TABLE invites ADD COLUMN IF NOT EXISTS redeem_key UUID;

-- Existing invites are numbered in the order they were made; the sequence
-- continues from there.
UPDATE invites i
   SET serial = numbered.n
  FROM (SELECT id, row_number() OVER (ORDER BY created_at, id) AS n FROM invites) numbered
 WHERE i.id = numbered.id AND i.serial IS NULL;
SELECT setval('invite_serial_seq', COALESCE((SELECT max(serial) FROM invites), 0) + 1, false);
-- Invites redeemed before this migration get the UTC date of their use, so a
-- redeemer's own retry still answers with a date (no zone was recorded then).
UPDATE invites SET redeemed_on = (used_at AT TIME ZONE 'UTC')::date
 WHERE used_by_user_id IS NOT NULL AND redeemed_on IS NULL AND used_at IS NOT NULL;
ALTER TABLE invites ALTER COLUMN serial SET DEFAULT nextval('invite_serial_seq');
ALTER TABLE invites ALTER COLUMN serial SET NOT NULL;
ALTER SEQUENCE invite_serial_seq OWNED BY invites.serial;
CREATE UNIQUE INDEX IF NOT EXISTS invites_serial_unique ON invites (serial);

REVOKE ALL ON SEQUENCE invite_serial_seq FROM PUBLIC, anon, authenticated;
GRANT USAGE, SELECT ON SEQUENCE invite_serial_seq TO service_role;

-- Looking at a code before spending it (POST /v2/invites/check). Read-only:
-- no row changes, and code_ciphertext is never selected. The same order as
-- redeem_invite, so the check always agrees with the tear that follows:
--   { outcome: 'yours', face }        this caller already redeemed it (checked
--                                     first: after the tear the caller is
--                                     'approved', so "already in" would hide it)
--   { outcome: 'already_in' }         the caller is past the waitlist
--   { outcome: 'usable', face }       live, and this caller may spend it
--   { outcome: 'invalid' | 'used' | 'expired' | 'no_user' }
-- face: { from, kind, serial, created_at }; revoked reads as invalid, as on
-- redeem (it says less).
CREATE OR REPLACE FUNCTION invite_check(p_user UUID, p_code_hash TEXT, p_now TIMESTAMPTZ)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_access TEXT;
    v_id UUID;
    v_kind TEXT;
    v_owner UUID;
    v_used_by UUID;
    v_revoked_at TIMESTAMPTZ;
    v_expires_at TIMESTAMPTZ;
    v_created_at TIMESTAMPTZ;
    v_serial BIGINT;
    v_from TEXT;
    v_face JSONB;
BEGIN
    SELECT access INTO v_access FROM users WHERE id = p_user;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('outcome', 'no_user');
    END IF;

    SELECT i.id, i.kind, i.owner_user_id, i.used_by_user_id, i.revoked_at, i.expires_at, i.created_at, i.serial
      INTO v_id, v_kind, v_owner, v_used_by, v_revoked_at, v_expires_at, v_created_at, v_serial
      FROM invites i WHERE i.code_hash = p_code_hash;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('outcome', 'invalid');
    END IF;
    SELECT first_name INTO v_from FROM users WHERE id = v_owner;
    v_face := jsonb_build_object('from', v_from, 'kind', v_kind, 'serial', v_serial, 'created_at', v_created_at);

    IF v_used_by = p_user THEN
        RETURN jsonb_build_object('outcome', 'yours', 'face', v_face);
    END IF;
    IF v_access <> 'waitlisted' THEN
        RETURN jsonb_build_object('outcome', 'already_in');
    END IF;
    IF v_revoked_at IS NOT NULL THEN
        RETURN jsonb_build_object('outcome', 'invalid');
    END IF;
    IF v_used_by IS NOT NULL THEN
        RETURN jsonb_build_object('outcome', 'used');
    END IF;
    IF v_expires_at IS NOT NULL AND v_expires_at <= p_now THEN
        RETURN jsonb_build_object('outcome', 'expired');
    END IF;
    RETURN jsonb_build_object('outcome', 'usable', 'face', v_face);
END;
$$;

-- Redeeming an invite (POST /v2/invites/redeem), replacing 007's function. The
-- caller's row is locked, so two redemptions by one person run one after the
-- other: a person is let in once and gets exactly three invites, however often
-- the app retries or with however many codes. The invite's update keeps
-- "used_by_user_id IS NULL" as the guard, so of two people racing for one code,
-- one wins.
--
-- The key (p_redeem_key, the request's Idempotency-Key; null when the client
-- sent none) is kept on the row the tear spent. Before the code is looked up:
-- the same caller with the same key and the same code is their own retry (the
-- stored answer, with the serial and the date of the tear); the same key with
-- another code is a mismatch. Another person's key is simply that person's
-- first use of it (keys are scoped to the caller). A retry with a different
-- key, or without one, still gets the same answer through the own-retry path
-- below, and the first key stays on the row.
--   { outcome: 'redeemed', invited_by, serial, redeemed_on }
--                                        let in now, or this caller's own retry
--   { outcome: 'already_in', access }     the caller is past the waitlist; no code is spent
--   { outcome: 'mismatch' }               this key was used by this caller for another code
--   { outcome: 'invalid' | 'used' | 'expired' }
--   { outcome: 'no_user' }
-- The last two parameters have defaults, so the backend that is live when this is applied
-- (it calls with five arguments) keeps tearing until the new one is deployed: no
-- "function not found" in between. Without a date the tear's day is the UTC day, the
-- same rule the backfill above uses.
DROP FUNCTION IF EXISTS redeem_invite(UUID, TEXT, TIMESTAMPTZ, TEXT[], TEXT[]);
CREATE OR REPLACE FUNCTION redeem_invite(
    p_user UUID, p_code_hash TEXT, p_now TIMESTAMPTZ, p_new_hashes TEXT[], p_new_ciphertexts TEXT[],
    p_redeem_key UUID DEFAULT NULL, p_redeemed_on DATE DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_access TEXT;
    v_invite invites%ROWTYPE;
    v_keyed invites%ROWTYPE;
    v_used UUID;
    v_by TEXT;
BEGIN
    SELECT access INTO v_access FROM users WHERE id = p_user FOR UPDATE;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('outcome', 'no_user');
    END IF;

    -- The key first: a retry with a lost response is answered before the code
    -- is even looked up, and a reused key with another code is refused.
    IF p_redeem_key IS NOT NULL THEN
        SELECT * INTO v_keyed FROM invites WHERE used_by_user_id = p_user AND redeem_key = p_redeem_key;
        IF FOUND THEN
            IF v_keyed.code_hash <> p_code_hash THEN
                RETURN jsonb_build_object('outcome', 'mismatch');
            END IF;
            SELECT first_name INTO v_by FROM users WHERE id = v_keyed.owner_user_id;
            RETURN jsonb_build_object('outcome', 'redeemed', 'invited_by', v_by,
                                      'serial', v_keyed.serial, 'redeemed_on', v_keyed.redeemed_on);
        END IF;
    END IF;

    SELECT * INTO v_invite FROM invites WHERE code_hash = p_code_hash;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('outcome', 'invalid');
    END IF;
    SELECT first_name INTO v_by FROM users WHERE id = v_invite.owner_user_id;

    -- This caller already redeemed this code: the same answer, nothing new.
    IF v_invite.used_by_user_id = p_user THEN
        RETURN jsonb_build_object('outcome', 'redeemed', 'invited_by', v_by,
                                  'serial', v_invite.serial, 'redeemed_on', v_invite.redeemed_on);
    END IF;
    IF v_access <> 'waitlisted' THEN
        RETURN jsonb_build_object('outcome', 'already_in', 'access', v_access);
    END IF;
    IF v_invite.revoked_at IS NOT NULL THEN
        RETURN jsonb_build_object('outcome', 'invalid');
    END IF;
    IF v_invite.used_by_user_id IS NOT NULL THEN
        RETURN jsonb_build_object('outcome', 'used');
    END IF;
    IF v_invite.expires_at IS NOT NULL AND v_invite.expires_at <= p_now THEN
        RETURN jsonb_build_object('outcome', 'expired');
    END IF;

    UPDATE invites
       SET used_by_user_id = p_user, used_at = p_now, code_ciphertext = NULL,
           redeem_key = p_redeem_key, redeemed_on = COALESCE(p_redeemed_on, (p_now AT TIME ZONE 'UTC')::date)
     WHERE id = v_invite.id AND used_by_user_id IS NULL AND revoked_at IS NULL
     RETURNING id INTO v_used;
    IF v_used IS NULL THEN
        RETURN jsonb_build_object('outcome', 'used');
    END IF;

    UPDATE users SET access = 'approved' WHERE id = p_user;
    INSERT INTO invites (code_hash, code_ciphertext, kind, owner_user_id, created_at)
    SELECT h, c, 'member', p_user, p_now FROM unnest(p_new_hashes, p_new_ciphertexts) AS t(h, c);
    UPDATE waitlist SET status = 'approved', decided_at = p_now, invite_id = v_invite.id
     WHERE user_id = p_user AND status = 'waiting';
    RETURN jsonb_build_object('outcome', 'redeemed', 'invited_by', v_by,
                              'serial', v_invite.serial, 'redeemed_on', COALESCE(p_redeemed_on, (p_now AT TIME ZONE 'UTC')::date));
END;
$$;

REVOKE ALL ON FUNCTION invite_check(UUID, TEXT, TIMESTAMPTZ) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION redeem_invite(UUID, TEXT, TIMESTAMPTZ, TEXT[], TEXT[], UUID, DATE) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION invite_check(UUID, TEXT, TIMESTAMPTZ) TO service_role;
GRANT EXECUTE ON FUNCTION redeem_invite(UUID, TEXT, TIMESTAMPTZ, TEXT[], TEXT[], UUID, DATE) TO service_role;
