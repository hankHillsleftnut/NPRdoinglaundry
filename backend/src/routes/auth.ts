import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { generateToken, getOrCreateUser } from '../middleware/auth.js';

export const authRouter = Router();

// Sign in with Apple request schema
const SignInSchema = z.object({
  appleUserId: z.string().min(1),
  email: z.string().email().optional(),
  identityToken: z.string().optional(), // For future verification
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

    const { appleUserId, email } = validationResult.data;

    // TODO: Verify Apple identity token in production
    // For now, we trust the appleUserId from the iOS app

    const user = await getOrCreateUser(appleUserId, email);
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

// POST /auth/refresh - Refresh token
authRouter.post('/refresh', async (req: Request, res: Response) => {
  try {
    const { appleUserId } = req.body;

    if (!appleUserId) {
      res.status(400).json({
        success: false,
        error: 'Missing appleUserId',
      });
      return;
    }

    const user = await getOrCreateUser(appleUserId);
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
