import { Router, Request, Response } from 'express';
import { randomUUID } from 'node:crypto';
import { z } from 'zod';
import { generateToken, getOrCreateUser } from '../middleware/auth.js';
import { verifyAppleIdentityToken } from '../services/apple-auth.js';
import { INVALID_APPLE_TOKEN, isRejectedAppleToken } from '../services/apple-errors.js';
import { config } from '../utils/config.js';

export interface AuthRouteDeps {
  verifyAppleIdentityToken: typeof verifyAppleIdentityToken;
  getOrCreateUser: typeof getOrCreateUser;
  generateToken: typeof generateToken;
  isProduction: boolean;
}

/**
 * The auth routes, with Apple verification and the user store passed in so the
 * error paths (a rejected Apple token is a 401) are tested over HTTP.
 */
export function createAuthRouter(deps: AuthRouteDeps): Router {
  const authRouter = Router();

  // Sign in with Apple request schema
  const SignInSchema = z.object({
    appleUserId: z.string().min(1),
    email: z.string().email().optional(),
    identityToken: z.string().min(1),
  });

  // POST /auth/signin - Sign in with Apple
  authRouter.post('/signin', async (req: Request, res: Response) => {
    try {
      const validationResult = SignInSchema.safeParse(req.body);

      if (!validationResult.success) {
        res.status(400).json({
          success: false,
          error: 'Invalid request body',
          details: validationResult.error.errors,
        });
        return;
      }

      const { appleUserId, email, identityToken } = validationResult.data;
      const verified = await deps.verifyAppleIdentityToken(identityToken);
      if (verified.appleUserId !== appleUserId) {
        res.status(401).json({ success: false, error: 'Apple identity token subject mismatch' });
        return;
      }

      const user = await deps.getOrCreateUser(verified.appleUserId, verified.email ?? email);
      const token = deps.generateToken(user);

      res.json({
        success: true,
        data: {
          token,
          user: {
            id: user.id,
            email: user.email,
          },
        },
      });
    } catch (error) {
      if (isRejectedAppleToken(error)) {
        res.status(401).json(INVALID_APPLE_TOKEN);
        return;
      }
      console.error('Sign in error:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to sign in',
      });
    }
  });

  // POST /auth/dev/test-user - DEV ONLY. Mints a real JWT for a brand new throwaway
  // user, so the new-account path (fresh onboarding) can be exercised. Apple returns the
  // same subject for a given Apple ID, so real sign-in always lands on the same account.
  // Disabled outside development: in production the route 404s like any unknown path,
  // and it only ever inserts a new user, so no existing account can be reached with it.
  authRouter.post('/dev/test-user', async (_req: Request, res: Response) => {
    if (deps.isProduction) {
      res.status(404).json({ success: false, error: 'Endpoint not found' });
      return;
    }

    try {
      const handle = randomUUID();
      const user = await deps.getOrCreateUser(
        `dev-test-user:${handle}`,
        `dev+${handle.slice(0, 8)}@retrospect.test`
      );
      const token = deps.generateToken(user);

      console.log(`[dev] issued a test-user token for ${user.id}`);

      res.json({
        success: true,
        data: {
          token,
          user: {
            id: user.id,
            email: user.email,
          },
        },
      });
    } catch (error) {
      console.error('Dev test user error:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to create dev test user',
      });
    }
  });

  // POST /auth/refresh - Refresh token
  authRouter.post('/refresh', async (req: Request, res: Response) => {
    try {
      const parsed = SignInSchema.safeParse(req.body);
      if (!parsed.success) {
        res.status(400).json({
          success: false,
          error: 'A fresh Apple identity token is required',
        });
        return;
      }
      const verified = await deps.verifyAppleIdentityToken(parsed.data.identityToken);
      if (verified.appleUserId !== parsed.data.appleUserId) {
        res.status(401).json({ success: false, error: 'Apple identity token subject mismatch' });
        return;
      }
      const user = await deps.getOrCreateUser(verified.appleUserId, verified.email ?? parsed.data.email);
      const token = deps.generateToken(user);

      res.json({
        success: true,
        data: { token },
      });
    } catch (error) {
      if (isRejectedAppleToken(error)) {
        res.status(401).json(INVALID_APPLE_TOKEN);
        return;
      }
      console.error('Token refresh error:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to refresh token',
      });
    }
  });

  return authRouter;
}

export const authRouter = createAuthRouter({
  verifyAppleIdentityToken,
  getOrCreateUser,
  generateToken,
  isProduction: config.server.isProduction,
});
