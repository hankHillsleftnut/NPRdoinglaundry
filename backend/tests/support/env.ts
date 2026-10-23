/**
 * Loaded before every test file (`npm test` passes `--import`), so config.ts
 * finds what it requires before anything imports it. Imports are hoisted, so
 * a test file can't set these itself in time.
 *
 * Every value is an obvious placeholder, never a key. URLs point at a closed
 * local port, so a test that reached a real service by mistake fails at once.
 */
const PLACEHOLDERS: Record<string, string> = {
  SUPABASE_URL: 'http://127.0.0.1:9',
  SUPABASE_SERVICE_KEY: 'test-only-not-a-key',
  SUPABASE_ANON_KEY: 'test-only-not-a-key',
  ANTHROPIC_API_KEY: 'test-only-not-a-key',
  OPENAI_API_KEY: 'test-only-not-a-key',
  JWT_SECRET: 'test-only-not-a-key',
  AGENT_SERVICE_URL: 'http://127.0.0.1:9',
  INTERNAL_API_SECRET: 'test-only-not-a-key',
  INVITE_CODE_KEY: 'test-only-not-a-key',
  // Integration providers, so their contract tests see configured providers.
  GOOGLE_OAUTH_CLIENT_ID: 'test-google-client', GOOGLE_OAUTH_CLIENT_SECRET: 'test-google-secret',
  SPOTIFY_CLIENT_ID: 'test-spotify-client', SPOTIFY_CLIENT_SECRET: 'test-spotify-secret',
  REDDIT_CLIENT_ID: 'test-reddit-client', REDDIT_CLIENT_SECRET: 'test-reddit-secret',
  PINTEREST_CLIENT_ID: 'test-pinterest-client', PINTEREST_CLIENT_SECRET: 'test-pinterest-secret',
  TIKTOK_CLIENT_KEY: 'test-tiktok-client-key', TIKTOK_CLIENT_SECRET: 'test-tiktok-secret',
  LINKEDIN_CLIENT_ID: 'test-linkedin-client', LINKEDIN_CLIENT_SECRET: 'test-linkedin-secret',
  X_CLIENT_ID: 'test-x-client', X_CLIENT_SECRET: 'test-x-secret',
};

/**
 * Cleared, so a key exported in the shell never reaches a test. (config.ts
 * skips its .env file entirely when NODE_ENV is "test".)
 */
const EMPTY = ['ADMIN_SECRET', 'SENTRY_DSN', 'ELEVENLABS_API_KEY', 'PERPLEXITY_API_KEY', 'APPLE_PRIVATE_KEY', 'DAILY_BRIEF_UTC_TIME', 'APPLE_REVOKE_ENABLED', 'TOKEN_ENCRYPTION_KEY'];

// Tests run with these values, whatever the shell or a local .env holds.
for (const [key, value] of Object.entries(PLACEHOLDERS)) process.env[key] = value;
for (const key of EMPTY) process.env[key] = '';
process.env.NODE_ENV = 'test';
