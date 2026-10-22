import express, { type Router } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import path from 'path';
import { captureException } from './services/telemetry.js';
import { config } from './utils/config.js';
import { makeAuthMiddleware, type UserLookup } from './middleware/auth.js';
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
import { globalLimiter, trustRenderProxy } from './server-settings.js';
import type { AgentDoorClient } from './doors/agent.js';
import { createDoorKit, type DoorFactory } from './doors/door.js';
import { v2ErrorHandler } from './doors/errors.js';
import { MemoryLimiter, type Limiter } from './doors/limits.js';
import { createV2Router } from './doors/router.js';
import { log, type DoorLogLine } from './utils/log.js';
import { supabaseAdmin } from './utils/supabase.js';
import { createSessionRouter } from './sessions/routes.js';
import { supabaseSessionStore, type RpcClient, type SessionStore } from './sessions/store.js';

/**
 * What the app needs from outside, passed in so tests can build it with a
 * fake agent, an in-memory user table, a fresh limiter and a fixed clock
 * (tests/support/harness.ts). server.ts passes the real ones.
 */
export interface AppDeps {
  agent: AgentDoorClient;
  /** The one per-user limiter every limited route shares; built here unless a test passes its own. */
  limiter?: Limiter;
  now: () => number;
  users: UserLookup;
  log?: { door(line: DoorLogLine): void };
  /** Where sessions live; the database functions of migration 005 by default. */
  sessions?: SessionStore;
  /** Builds the /v2 router from the door kit; the real one by default. */
  v2Router?: (door: DoorFactory) => Router;
}

/**
 * Builds the Express app with every mount, in the order they always had.
 * Importing this file opens no port and needs no live service; server.ts listens.
 */
export function createApp(deps: AppDeps): express.Express {
  const app = express();
  const legacyAuth = makeAuthMiddleware(deps.users, { now: deps.now });
  const limiter = deps.limiter ?? new MemoryLimiter();
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
  app.use('/content', legacyAuth, contentRouter);
  app.use('/goals', legacyAuth, goalsRouter);
  app.use('/pipeline', legacyAuth, pipelineRouter);
  app.use('/podcasts', legacyAuth, podcastsRouter);
  app.use('/profile', legacyAuth, profileRouter);
  app.use('/claude', legacyAuth, claudeRouter);
  app.use('/speech', legacyAuth, speechRouter);
  app.use('/integrations', legacyAuth, integrationsRouter);
  app.use('/graph', legacyAuth, graphRouter);

  // The new app's doors (src/doors). Public /v2 routes are mounted before this in later bytes.
  const door = createDoorKit({
    agent: deps.agent,
    limiter,
    log: deps.log ?? log,
    now: deps.now,
    reportBug: (err, name) => captureException(err, { door: name }),
  });
  const v2Auth = makeAuthMiddleware(deps.users, { envelope: true, now: deps.now });
  // Sign-in and sessions: public (refresh) or checked inside (signout), so before the /v2 auth.
  app.use('/v2/auth', createSessionRouter({
    store: deps.sessions ?? supabaseSessionStore(supabaseAdmin as unknown as RpcClient),
    users: deps.users,
    limiter,
    now: deps.now,
    secret: config.jwt.secret,
    log: deps.log ?? log,
    auth: v2Auth,
    reportBug: (err, name) => captureException(err, { door: name }),
  }));
  app.use('/v2', v2Auth, (deps.v2Router ?? createV2Router)(door));
  app.use('/v2', v2ErrorHandler);

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

  return app;
}
