import dotenv from 'dotenv';

dotenv.config();

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

  // JWT
  jwt: {
    secret: requireEnv('JWT_SECRET'),
    expiresIn: '30d',
  },

  // Apple Sign In
  apple: {
    teamId: optionalEnv('APPLE_TEAM_ID', ''),
    keyId: optionalEnv('APPLE_KEY_ID', ''),
    privateKey: optionalEnv('APPLE_PRIVATE_KEY', ''),
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
