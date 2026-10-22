import express from 'express';
import { captureException } from './services/telemetry.js';
import cors from 'cors';
import helmet from 'helmet';
import path from 'path';

import { config } from './utils/config.js';
import { authMiddleware } from './middleware/auth.js';
import { authRouter } from './routes/auth.js';
import { contentRouter } from './routes/content.js';
import { goalsRouter } from './routes/goals.js';
import { pipelineRouter } from './routes/pipeline.js';
import { mountAdmin } from './routes/admin-mount.js';
import { podcastsRouter } from './routes/podcasts.js';
import { profileRouter } from './routes/profile.js';
import { claudeRouter } from './routes/claude.js';
import { speechRouter } from './routes/speech.js';
import { integrationOauthCallbackRouter, integrationsRouter } from './routes/integrations.js';
import { graphRouter } from './routes/graph.js';
import { applyServerTimeouts, globalLimiter, trustRenderProxy } from './server-settings.js';


const app = express();
trustRenderProxy(app);

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

// Rate limiting by IP, except /health and /v2 (doors limit per user)
app.use(globalLimiter({ windowMs: config.rateLimit.windowMs, max: config.rateLimit.maxRequests }));

// The admin dashboard's files (public/ is copied alongside dist/ during build);
// served only when admin is mounted, below.
const publicDir = path.join(__dirname, 'public');

// Health check endpoint (no auth)
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Admin routes and the dashboard (admin secret, not JWT; absent without ADMIN_SECRET)
mountAdmin(app, { secret: config.admin.secret, publicDir });

// Auth routes (no auth middleware)
app.use('/auth', authRouter);
app.use('/integrations', integrationOauthCallbackRouter);

// Protected routes
app.use('/content', authMiddleware, contentRouter);
app.use('/goals', authMiddleware, goalsRouter);
app.use('/pipeline', authMiddleware, pipelineRouter);
app.use('/podcasts', authMiddleware, podcastsRouter);
app.use('/profile', authMiddleware, profileRouter);
app.use('/claude', authMiddleware, claudeRouter);
app.use('/speech', authMiddleware, speechRouter);
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
    captureException(err, { path: _req.path, method: _req.method });
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

applyServerTimeouts(server);

export default app;
