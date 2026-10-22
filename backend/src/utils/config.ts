import dotenv from 'dotenv';

// DOTENV_CONFIG_PATH names the env file to read instead of `.env`. Local staging
// sets it (in .env.staging), and that file then wins over the shell: a variable
// missing there is never filled in from the `.env` beside it, and a production
// value exported in the shell never reaches a staging run. Without it (Render,
// plain `npm run dev`), `.env` is read as before and never overrides.
// Tests never read an env file: tests/support/env.ts sets every value they use.
const envFile = process.env.DOTENV_CONFIG_PATH;
if (process.env.NODE_ENV !== 'test') dotenv.config(envFile ? { path: envFile, override: true } : undefined);

function requireEnv(key: string): string {
  const value = process.env[key];
  if (!value) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
  return value;
}

function optionalEnv(key: string, defaultValue: string): string {
  return process.env[key] ?? defaultValue;
}

export const config = {
  // Supabase
  supabase: {
    url: requireEnv('SUPABASE_URL'),
    serviceKey: requireEnv('SUPABASE_SERVICE_KEY'),
    anonKey: requireEnv('SUPABASE_ANON_KEY'),
  },

  // Anthropic (Claude) — used for all intelligence tasks
  anthropic: {
    apiKey: requireEnv('ANTHROPIC_API_KEY'),
    model: 'claude-sonnet-4-20250514',
  },

  // OpenAI — used ONLY for embeddings
  openai: {
    apiKey: requireEnv('OPENAI_API_KEY'),
    embeddingModel: 'text-embedding-3-large',
  },

  // Perplexity (Sonar Pro) — used for research enrichment in podcast generation
  perplexity: {
    apiKey: optionalEnv('PERPLEXITY_API_KEY', ''),
    model: 'sonar-pro',
  },

  // ElevenLabs — text-to-speech for podcast audio (v3: most expressive, native audio tags)
  elevenlabs: {
    apiKey: optionalEnv('ELEVENLABS_API_KEY', ''),
    voiceId: optionalEnv('ELEVENLABS_VOICE_ID', 'pNInz6obpgDQGcFmaJgB'), // Default: Adam
    model: 'eleven_v3',
    maxCharsPerRequest: 4800, // v3 limit is 5,000; leave buffer for safety
  },

  // JWT
  jwt: {
    secret: requireEnv('JWT_SECRET'),
    expiresIn: '30d',
  },

  // Apple Sign In
  apple: {
    clientId: optionalEnv('APPLE_CLIENT_ID', 'com.shauryanarang.Retrospect'),
    teamId: optionalEnv('APPLE_TEAM_ID', ''),
    keyId: optionalEnv('APPLE_KEY_ID', ''),
    privateKey: optionalEnv('APPLE_PRIVATE_KEY', ''),
  },

  // Invites (BE0.12). INVITE_CODE_KEY seals unused codes so "your invites" can
  // show a link again; without it, nothing can issue an invite (redeem and the
  // admin's approve answer 500) while everything else works. Founder sets it.
  invites: {
    codeKey: process.env.INVITE_CODE_KEY || null,
    baseUrl: optionalEnv('INVITE_BASE_URL', 'https://retrospect-api.onrender.com'),
    /** Where the link page's download button goes (TestFlight or the App Store); no button when unset. */
    appUrl: process.env.INVITE_APP_URL || null,
  },

  // Briefs (BE1.3). DAILY_BRIEF_UTC_TIME ("HH:MM") is when the agent's daily
  // brief cron runs, set only where briefs run (local staging: 08:00) and unset
  // in production (D10: no production briefs), so `nextAt` is null there.
  // BE6.1a replaces it with each person's own time.
  briefs: {
    runTimeUtc: /^\d{2}:\d{2}$/.test(process.env.DAILY_BRIEF_UTC_TIME ?? '') ? process.env.DAILY_BRIEF_UTC_TIME! : null,
  },

  // Admin
  admin: {
    // No default: without ADMIN_SECRET the admin routes are not mounted.
    secret: process.env.ADMIN_SECRET || null,
  },

  // Agent service — the only execution path for ingestion and podcast generation.
  agent: {
    serviceUrl: requireEnv('AGENT_SERVICE_URL'),
    internalSecret: requireEnv('INTERNAL_API_SECRET'),
  },
  integrations: {
    oauthCallbackBaseUrl: optionalEnv('INTEGRATION_OAUTH_CALLBACK_BASE_URL', 'https://retrospect-api.onrender.com'),
    appRedirectUrl: optionalEnv('INTEGRATION_APP_REDIRECT_URL', 'retrospect://integration-connected'),
    googleClientId: optionalEnv('GOOGLE_OAUTH_CLIENT_ID', ''),
    googleClientSecret: optionalEnv('GOOGLE_OAUTH_CLIENT_SECRET', ''),
    spotifyClientId: optionalEnv('SPOTIFY_CLIENT_ID', ''),
    spotifyClientSecret: optionalEnv('SPOTIFY_CLIENT_SECRET', ''),
    redditClientId: optionalEnv('REDDIT_CLIENT_ID', ''),
    redditClientSecret: optionalEnv('REDDIT_CLIENT_SECRET', ''),
    pinterestClientId: optionalEnv('PINTEREST_CLIENT_ID', ''),
    pinterestClientSecret: optionalEnv('PINTEREST_CLIENT_SECRET', ''),
    tiktokClientKey: optionalEnv('TIKTOK_CLIENT_KEY', ''),
    tiktokClientSecret: optionalEnv('TIKTOK_CLIENT_SECRET', ''),
    linkedinClientId: optionalEnv('LINKEDIN_CLIENT_ID', ''),
    linkedinClientSecret: optionalEnv('LINKEDIN_CLIENT_SECRET', ''),
    xClientId: optionalEnv('X_CLIENT_ID', ''),
    xClientSecret: optionalEnv('X_CLIENT_SECRET', ''),
  },

  // Server
  server: {
    port: parseInt(optionalEnv('PORT', '3000'), 10),
    nodeEnv: optionalEnv('NODE_ENV', 'development'),
    isProduction: optionalEnv('NODE_ENV', 'development') === 'production',
  },

  // Rate Limiting
  rateLimit: {
    windowMs: parseInt(optionalEnv('RATE_LIMIT_WINDOW_MS', '900000'), 10),
    maxRequests: parseInt(optionalEnv('RATE_LIMIT_MAX_REQUESTS', '100'), 10),
  },

  // Pattern Detection Thresholds
  patterns: {
    minInsightsForCorrelation: 5,
    minConfidenceThreshold: 0.6,
    similarityThreshold: 0.7,
    connectionStrengthThreshold: 0.5,
  },

  // Embedding Configuration
  embeddings: {
    dimensions: 3072,
    batchSize: 100,
  },
} as const;

export type Config = typeof config;
