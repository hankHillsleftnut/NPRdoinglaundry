import express from 'express';
import { captureExceptionForUser } from './services/telemetry.js';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import path from 'path';

import { config } from './utils/config.js';
import { authMiddleware } from './middleware/auth.js';
import { featureFlagsMiddleware } from './services/feature-flags.js';
import { authRouter } from './routes/auth.js';
import { contentRouter } from './routes/content.js';
import { goalsRouter } from './routes/goals.js';
import { pipelineRouter } from './routes/pipeline.js';
import { adminRouter } from './routes/admin.js';
import { podcastsRouter } from './routes/podcasts.js';
import { profileRouter } from './routes/profile.js';
import { claudeRouter } from './routes/claude.js';
import { integrationOauthCallbackRouter, integrationsRouter } from './routes/integrations.js';
import { graphRouter } from './routes/graph.js';


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
app.use('/integrations', integrationOauthCallbackRouter);

// Protected routes
app.use('/content', authMiddleware, contentRouter);
app.use('/goals', authMiddleware, goalsRouter);
// /pipeline and /podcasts branch on feature flags, so they resolve them once
// per request. Other routers skip the lookup; a route that reads
// req.featureFlags without this mounted sees undefined, which reads as all-off.
app.use('/pipeline', authMiddleware, featureFlagsMiddleware, pipelineRouter);
app.use('/podcasts', authMiddleware, featureFlagsMiddleware, podcastsRouter);
app.use('/profile', authMiddleware, profileRouter);
app.use('/claude', authMiddleware, claudeRouter);
app.use('/integrations', authMiddleware, integrationsRouter);
app.use('/graph', authMiddleware, graphRouter);

// Error handling middleware
app.use(
  (
    err: Error,
    _req: express.Request,
    res: express.Response,
    _next: express.NextFunction
  ) => {
    console.error('Unhandled error:', err);
    // User-aware: errors from test accounts never enter the Sentry aggregates.
    captureExceptionForUser(err, _req.user, { path: _req.path, method: _req.method });
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

console.log('Legacy backend crons are disabled. Agent crons own ingestion and podcasts.');

// Start server
const server = app.listen(config.server.port, () => {
  console.log(`Server running on port ${config.server.port}`);
  console.log(`Environment: ${config.server.nodeEnv}`);
});

// Podcast generation with v3 TTS can take several minutes
server.timeout = 300_000; // 5 minutes
server.keepAliveTimeout = 120_000;

export default app;
