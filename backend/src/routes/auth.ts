import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { generateToken, getOrCreateUser } from '../middleware/auth.js';
import { verifyAppleIdentityToken } from '../services/apple-auth.js';
import { INVALID_APPLE_TOKEN, isRejectedAppleToken } from '../services/apple-errors.js';
import { devTestUserHandler } from '../services/dev-test-user.js';
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

  // POST /auth/dev/test-user - DEV ONLY. See services/dev-test-user.ts: off in
  // production (404), and it only ever reaches `dev-test-user:` accounts.
  authRouter.post(
    '/dev/test-user',
    devTestUserHandler({ isProduction: deps.isProduction, getOrCreateUser: deps.getOrCreateUser, generateToken: deps.generateToken }),
  );

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
