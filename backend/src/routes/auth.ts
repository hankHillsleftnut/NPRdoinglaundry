import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { generateToken, getOrCreateUser } from '../middleware/auth.js';
import { verifyAppleIdentityToken } from '../services/apple-auth.js';
import { resolveFlagsForUser, EMPTY_FLAGS } from '../services/feature-flags.js';
import { getAccountType } from '../services/accounts.js';
import type { AuthUser } from '../types/index.js';

export const authRouter = Router();

/**
 * The single /auth/* success payload:
 *   { token, user: { id, email }, accountType, flags }
 * `flags` is the SAME resolved map the server uses for this user's requests,
 * so the iOS client branches on identical values. Additive only — `token` and
 * `user` keep their existing shape.
 */
async function authPayload(user: AuthUser, token: string) {
  const [accountType, flags] = await Promise.all([
    getAccountType(user.id),
    resolveFlagsForUser(user.id).catch(() => EMPTY_FLAGS),
  ]);

  return {
    token,
    user: {
      id: user.id,
      email: user.email,
    },
    accountType,
    flags,
  };
}

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
      data: await authPayload(user, token),
    });
  } catch (error) {
    console.error('Sign in error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to sign in',
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
      data: await authPayload(user, token),
    });
  } catch (error) {
    console.error('Token refresh error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to refresh token',
    });
  }
});
