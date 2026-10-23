-- ============================================================================
-- 027: keep Apple's refresh token so account deletion can revoke it (BE0.5)
--      (027: the next free backend number; no open branch adds 027 or 028)
--
-- Goal: App Review 5.1.1(v) and Apple TN3194. Deleting an account that signed
-- in with Apple must revoke the Apple token. Apple only hands out a token in
-- exchange for the one-time authorization code the app sends at sign-in, so
-- the sign-in door trades that code for Apple's refresh token and keeps it.
--
-- Why: until now the code was validated and dropped, so no token could ever
-- be revoked. Now:
--   users.apple_refresh_token_ciphertext  Apple's refresh token, sealed with
--                                         AES-256-GCM under TOKEN_ENCRYPTION_KEY
--                                         (`v1:<iv>:<tag>:<ciphertext>`); the key
--                                         never lives in the database. Null until
--                                         a sign-in with APPLE_REVOKE_ENABLED on.
--   users.apple_refresh_token_at          when it was stored (the newest sign-in wins)
-- Account deletion (BE0.7) revokes it; nothing reads it yet.
--
-- Additive. RLS unchanged: the server writes these columns as service_role,
-- and the old "own profile" policies match auth.uid(), which the app's own
-- tokens never set. Files only: never applied to production by an agent.
-- ============================================================================

ALTER TABLE users ADD COLUMN IF NOT EXISTS apple_refresh_token_ciphertext TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS apple_refresh_token_at TIMESTAMPTZ;
