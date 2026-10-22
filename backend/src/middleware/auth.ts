import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { config } from '../utils/config.js';
import { supabaseAdmin, Tables } from '../utils/supabase.js';
import type { AuthUser, JWTPayload } from '../types/index.js';
import { getOrCreateUserWith, type UsersClient } from '../services/users.js';

// Extend Express Request type to include user
declare global {
  namespace Express {
    interface Request {
      user?: AuthUser;
    }
  }
}

export async function authMiddleware(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({
        success: false,
        error: 'Missing or invalid authorization header',
      });
      return;
    }

    const token = authHeader.substring(7);

    // Verify JWT
    let payload: JWTPayload;
    try {
      payload = jwt.verify(token, config.jwt.secret) as JWTPayload;
    } catch {
      res.status(401).json({
        success: false,
        error: 'Invalid or expired token',
      });
      return;
    }

    // Fetch user from database
    const { data: user, error } = await supabaseAdmin
      .from(Tables.USERS)
      .select('id, apple_user_id, email')
      .eq('id', payload.userId)
      .single();

    if (error || !user) {
      res.status(401).json({
        success: false,
        error: 'User not found',
      });
      return;
    }

    req.user = {
      id: user.id,
      appleUserId: user.apple_user_id,
      email: user.email ?? undefined,
    };

    next();
  } catch (error) {
    console.error('Auth middleware error:', error);
    res.status(500).json({
      success: false,
      error: 'Authentication error',
    });
  }
}

// Generate JWT for a user
export function generateToken(user: AuthUser): string {
  const payload: Omit<JWTPayload, 'iat' | 'exp'> = {
    userId: user.id,
    appleUserId: user.appleUserId,
  };

  return jwt.sign(payload, config.jwt.secret, {
    expiresIn: config.jwt.expiresIn,
  });
}

// Create or get user from Apple Sign In (race-safe; see services/users.ts)
export async function getOrCreateUser(
  appleUserId: string,
  email?: string
): Promise<AuthUser> {
  return getOrCreateUserWith(supabaseAdmin as unknown as UsersClient, Tables.USERS, appleUserId, email);
}
