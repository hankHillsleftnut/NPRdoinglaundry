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

// Start server
app.listen(config.server.port, () => {
  console.log(`Server running on port ${config.server.port}`);
  console.log(`Environment: ${config.server.nodeEnv}`);
});

export default app;
