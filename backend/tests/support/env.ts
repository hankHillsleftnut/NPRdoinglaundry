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
 * Set to empty rather than deleted: config.ts runs dotenv, which fills in any
 * variable that is missing from a local `.env` (never one that is set), so an
 * empty value keeps a developer's real key out of the tests.
 */
const EMPTY = ['ADMIN_SECRET', 'SENTRY_DSN', 'ELEVENLABS_API_KEY', 'PERPLEXITY_API_KEY', 'APPLE_PRIVATE_KEY', 'DOTENV_CONFIG_PATH'];

// Tests run with these values, whatever the shell or a local .env holds.
for (const [key, value] of Object.entries(PLACEHOLDERS)) process.env[key] = value;
for (const key of EMPTY) process.env[key] = '';
process.env.NODE_ENV = 'test';
