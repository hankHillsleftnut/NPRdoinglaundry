import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import cron from 'node-cron';
import path from 'path';

import { config } from './utils/config.js';
import { authMiddleware } from './middleware/auth.js';
import { authRouter } from './routes/auth.js';
import { contentRouter } from './routes/content.js';
import { insightsRouter } from './routes/insights.js';
import { patternsRouter } from './routes/patterns.js';
import { analyticsRouter } from './routes/analytics.js';
import { goalsRouter } from './routes/goals.js';
import { pipelineRouter } from './routes/pipeline.js';
import { adminRouter } from './routes/admin.js';
import { runDailyPatternDetection } from './jobs/daily-patterns.js';
import { runWeeklyPatternDetection } from './jobs/weekly-patterns.js';
import { runObservationInsightsPipeline } from './jobs/observation-insights-pipeline.js';
import { runWeeklyPodcastGeneration } from './jobs/weekly-podcast-generation.js';
import { podcastsRouter } from './routes/podcasts.js';
import { profileRouter } from './routes/profile.js';
import { v2ContentRouter } from './v2/routes/v2-content.js';
import { v2PodcastsRouter } from './v2/routes/v2-podcasts.js';
import { v2SuggestedGoalsRouter } from './v2/routes/v2-suggested-goals.js';
import { v2UserPreferencesRouter } from './v2/routes/v2-user-preferences.js';
import { v2EntriesRouter } from './v2/routes/v2-entries.js';
import { v2OnboardingRouter } from './v2/routes/v2-onboarding.js';
import { v2AdminRouter } from './routes/v2-admin.js';


const app = express();

// Security middleware — relax CSP for the admin dashboard's inline scripts
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      scriptSrcAttr: ["'unsafe-inline'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:"],
      connectSrc: ["'self'"],
    },
  },
}));
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Rate limiting
const limiter = rateLimit({
  windowMs: config.rateLimit.windowMs,
  max: config.rateLimit.maxRequests,
  message: {
    success: false,
    error: 'Too many requests, please try again later',
  },
});
app.use(limiter);

// Serve dashboard static files (public/ is copied alongside dist/ during build)
const publicDir = path.join(__dirname, 'public');
app.use('/public', express.static(publicDir));

// Dashboard route
app.get('/dashboard', (_req: express.Request, res: express.Response) => {
  res.sendFile(path.join(publicDir, 'dashboard.html'));
});

// Health check endpoint (no auth)
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Admin routes (protected by admin secret, not JWT)
app.use('/admin', adminRouter);

// Auth routes (no auth middleware)
app.use('/auth', authRouter);

// Protected routes
app.use('/content', authMiddleware, contentRouter);
app.use('/insights', authMiddleware, insightsRouter);
app.use('/patterns', authMiddleware, patternsRouter);
app.use('/analytics', authMiddleware, analyticsRouter);
app.use('/goals', authMiddleware, goalsRouter);
app.use('/pipeline', authMiddleware, pipelineRouter);
app.use('/podcasts', authMiddleware, podcastsRouter);
app.use('/profile', authMiddleware, profileRouter);

// v2 routes — new agentic pipeline. Mounts under /v2/* and runs in parallel
// with the legacy routes above until we validate and retire them.
app.use('/v2/content', authMiddleware, v2ContentRouter);
app.use('/v2/podcasts', authMiddleware, v2PodcastsRouter);
app.use('/v2/suggested-goals', authMiddleware, v2SuggestedGoalsRouter);
app.use('/v2/user-preferences', authMiddleware, v2UserPreferencesRouter);
app.use('/v2/entries', authMiddleware, v2EntriesRouter);
app.use('/v2/onboarding', authMiddleware, v2OnboardingRouter);

// v2 admin / monitoring (admin-secret protected, no JWT). Feeds the
// MONITORING tab in the dashboard.
app.use('/admin/v2', v2AdminRouter);

// Error handling middleware
app.use(
  (
    err: Error,
    _req: express.Request,
    res: express.Response,
    _next: express.NextFunction
  ) => {
    console.error('Unhandled error:', err);
    res.status(500).json({
      success: false,
      error: config.server.isProduction
        ? 'Internal server error'
        : err.message,
    });
  }
);

// 404 handler
app.use((_req, res) => {
  res.status(404).json({
    success: false,
    error: 'Endpoint not found',
  });
});

// Schedule cron jobs
// Daily pattern detection at 3 AM UTC
cron.schedule('0 3 * * *', async () => {
  console.log('Running daily pattern detection...');
  try {
    await runDailyPatternDetection();
    console.log('Daily pattern detection completed');
  } catch (error) {
    console.error('Daily pattern detection failed:', error);
  }
});

// Weekly pattern detection at 4 AM UTC on Sundays
cron.schedule('0 4 * * 0', async () => {
  console.log('Running weekly pattern detection...');
  try {
    await runWeeklyPatternDetection();
    console.log('Weekly pattern detection completed');
  } catch (error) {
    console.error('Weekly pattern detection failed:', error);
  }
});

// Observations → Insights pipeline at 5 AM UTC daily
cron.schedule('0 5 * * *', async () => {
  console.log('Running observations → insights pipeline...');
  try {
    await runObservationInsightsPipeline();
    console.log('Observations → insights pipeline completed');
  } catch (error) {
    console.error('Observations → insights pipeline failed:', error);
  }
});

// Legacy weekly podcast generation at 6 AM UTC on Sundays.
//
// The v2 agentic pipeline runs in the same Sunday 06:00 UTC slot via the
// `v2-weekly-podcast` Render Cron service (see backend/render.yaml). To avoid
// duplicate episodes we leave the legacy job *registered* but gated behind a
// feature flag. Flip ENABLE_LEGACY_PODCAST_CRON=false once v2 is validated in
// production; the import stays in place so we can roll back instantly.
const ENABLE_LEGACY_PODCAST_CRON =
  (process.env.ENABLE_LEGACY_PODCAST_CRON ?? 'true') !== 'false';

if (ENABLE_LEGACY_PODCAST_CRON) {
  cron.schedule('0 6 * * 0', async () => {
    console.log('Running weekly podcast generation (legacy)...');
    try {
      await runWeeklyPodcastGeneration();
      console.log('Weekly podcast generation (legacy) completed');
    } catch (error) {
      console.error('Weekly podcast generation (legacy) failed:', error);
    }
  });
} else {
  console.log(
    '[cron] Legacy weekly podcast cron disabled — v2 Render Cron service handles Sunday 06:00 UTC.'
  );
}

// Start server
const server = app.listen(config.server.port, () => {
  console.log(`Server running on port ${config.server.port}`);
  console.log(`Environment: ${config.server.nodeEnv}`);
});

// Podcast generation with v3 TTS can take several minutes
server.timeout = 300_000; // 5 minutes
server.keepAliveTimeout = 120_000;

export default app;
