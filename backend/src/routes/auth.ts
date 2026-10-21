import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { generateToken, getOrCreateUser } from '../middleware/auth.js';
import { verifyAppleIdentityToken } from '../services/apple-auth.js';
import { DevTestUserRequestSchema, devTestIdentity } from '../services/dev-test-user.js';
import { config } from '../utils/config.js';

export const authRouter = Router();

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
    const verified = await verifyAppleIdentityToken(identityToken);
    if (verified.appleUserId !== appleUserId) {
      res.status(401).json({ success: false, error: 'Apple identity token subject mismatch' });
      return;
    }

    const user = await getOrCreateUser(verified.appleUserId, verified.email ?? email);
    const token = generateToken(user);

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
    console.error('Sign in error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to sign in',
    });
  }
});

// POST /auth/dev/test-user - DEV ONLY. Mints a real JWT for a throwaway user: a brand
// new one by default, so the new-account path (fresh onboarding) can be exercised, or
// a seeded staging test account when the body names one (`{ "key": "month" }`).
// Disabled outside development: in production the route 404s like any unknown path,
// and it only ever reaches `dev-test-user:` accounts (see devTestIdentity), never a
// real one.
authRouter.post('/dev/test-user', async (req: Request, res: Response) => {
  if (config.server.isProduction) {
    res.status(404).json({ success: false, error: 'Endpoint not found' });
    return;
  }

  const parsed = DevTestUserRequestSchema.safeParse(req.body ?? {});
  if (!parsed.success) {
    res.status(400).json({ success: false, error: 'key must be 1-32 lowercase letters, digits or dashes' });
    return;
  }

  try {
    const identity = devTestIdentity(parsed.data.key);
    const user = await getOrCreateUser(identity.appleUserId, identity.email);
    const token = generateToken(user);

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
    const verified = await verifyAppleIdentityToken(parsed.data.identityToken);
    if (verified.appleUserId !== parsed.data.appleUserId) {
      res.status(401).json({ success: false, error: 'Apple identity token subject mismatch' });
      return;
    }
    const user = await getOrCreateUser(verified.appleUserId, verified.email ?? parsed.data.email);
    const token = generateToken(user);

    res.json({
      success: true,
      data: { token },
    });
  } catch (error) {
    console.error('Token refresh error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to refresh token',
    });
  }
});
