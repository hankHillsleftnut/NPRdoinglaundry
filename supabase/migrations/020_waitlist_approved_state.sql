-- ============================================================================
-- 020: an approved waitlister is still "on the waitlist" (BE0.12 follow-up)
--      (020: the next free backend number; 013-018 are assigned in plans-consistency.md, 019 is merged)
--
-- Goal: someone the founder has approved, who hasn't opened their invite link
-- yet, keeps seeing "you're on the list" in the app, not "ask to join" again.
--
-- Why: 007's waitlist_state and join_waitlist counted status 'waiting' only,
-- and approving sets 'approved' while the person's access stays 'waitlisted'
-- until they redeem. So GET /v2/access answered { onWaitlist: false } and a
-- second POST /v2/waitlist answered the same, and the app would ask them to
-- join a list they're already on (integrator review of #115, 22 Oct).
--
-- The fix: "on the waitlist" = a row of their own with status waiting or
-- approved, while users.access is still 'waitlisted'. Once they redeem (or
-- are let in another way) the answer is false again, as before. Declined
-- stays false. Same signatures, same grants; only the two function bodies
-- change. Nothing else in 007 moves.
--
-- Additive. Files only: never applied to production by an agent.
-- ============================================================================

CREATE OR REPLACE FUNCTION join_waitlist(p_user UUID, p_reason TEXT, p_now TIMESTAMPTZ)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO waitlist (source, user_id, reason, created_at)
    SELECT 'app', u.id, p_reason, p_now FROM users u WHERE u.id = p_user AND u.access = 'waitlisted'
    ON CONFLICT (user_id) DO NOTHING;
    RETURN waitlist_state(p_user);
END;
$$;

CREATE OR REPLACE FUNCTION waitlist_state(p_user UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM waitlist w JOIN users u ON u.id = w.user_id
         WHERE w.user_id = p_user AND w.status IN ('waiting', 'approved') AND u.access = 'waitlisted'
    );
$$;

REVOKE ALL ON FUNCTION join_waitlist(UUID, TEXT, TIMESTAMPTZ) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION waitlist_state(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION join_waitlist(UUID, TEXT, TIMESTAMPTZ) TO service_role;
GRANT EXECUTE ON FUNCTION waitlist_state(UUID) TO service_role;
