import { Router, Request, Response } from 'express';
import { z } from 'zod';
import {
  authMiddleware,
  issueToken,
  signOutEverywhere,
  getOrCreateUser,
  linkAuthIdentity,
  verifyProviderIdentityToken,
  IdentityLinkConflictError,
} from '../middleware/auth.js';
import type { AuthIdentityInput } from '../middleware/auth.js';
import { verifyAppleIdentityToken } from '../services/apple-auth.js';
import { authFailureFor, classifyTokenError, failureBody } from '../services/auth-errors.js';
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
      res.status(400).json({ ...failureBody(authFailureFor('bad_request')), details: validationResult.error.errors });
      return;
    }

    const { appleUserId, email, identityToken } = validationResult.data;
    let verified: Awaited<ReturnType<typeof verifyAppleIdentityToken>>;
    try {
      verified = await verifyAppleIdentityToken(identityToken);
    } catch (verifyError) {
      const f = classifyTokenError(verifyError, 'Apple');
      console.error(`Sign in error (${f.code}):`, verifyError);
      res.status(f.status).json(failureBody(f));
      return;
    }
    if (verified.appleUserId !== appleUserId) {
      res.status(401).json(failureBody(authFailureFor('sign_in_not_confirmed', 'Apple')));
      return;
    }

    const user = await getOrCreateUser({
      provider: 'apple',
      subject: verified.appleUserId,
      email: verified.email ?? email,
    });
    const token = await issueToken(user);

    res.json({
      success: true,
      data: await authPayload(user, token),
    });
  } catch (error) {
    console.error('Sign in error:', error);
    res.status(500).json(failureBody(authFailureFor('server_error')));
  }
});

// POST /auth/refresh - Refresh token
authRouter.post('/refresh', async (req: Request, res: Response) => {
  try {
    const parsed = SignInSchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json(failureBody(authFailureFor('bad_request')));
      return;
    }
    let verified: Awaited<ReturnType<typeof verifyAppleIdentityToken>>;
    try {
      verified = await verifyAppleIdentityToken(parsed.data.identityToken);
    } catch (verifyError) {
      const f = classifyTokenError(verifyError, 'Apple');
      console.error(`Token refresh error (${f.code}):`, verifyError);
      res.status(f.status).json(failureBody(f));
      return;
    }
    if (verified.appleUserId !== parsed.data.appleUserId) {
      res.status(401).json(failureBody(authFailureFor('sign_in_not_confirmed', 'Apple')));
      return;
    }
    const user = await getOrCreateUser({
      provider: 'apple',
      subject: verified.appleUserId,
      email: verified.email ?? parsed.data.email,
    });
    const token = await issueToken(user);

    res.json({
      success: true,
      data: await authPayload(user, token),
    });
  } catch (error) {
    console.error('Token refresh error:', error);
    res.status(500).json(failureBody(authFailureFor('server_error')));
  }
});

// POST /auth/sign-out-everywhere - End every session for this account,
// including this one. The app signs in again afterwards.
authRouter.post('/sign-out-everywhere', authMiddleware, async (req: Request, res: Response) => {
  try {
    await signOutEverywhere(req.user!.id);
    res.json({ success: true, data: { message: 'Signed out on every device. Please sign in again.' } });
  } catch (error) {
    console.error('Sign out everywhere error:', error);
    res.status(500).json(failureBody(authFailureFor('server_error')));
  }
});

// Link an additional sign-in method to the account that is already signed in.
// To support another provider, add it here and to the switch in
// verifyProviderIdentityToken.
const LinkIdentitySchema = z.object({
  provider: z.enum(['apple']),
  identityToken: z.string().min(1),
});

// jose tags every "this token is not acceptable" failure with a JWT/JWS/JWK
// error code; transport failures (JWKS fetch) arrive without one.
const INVALID_TOKEN_CODES = new Set([
  'ERR_JWT_EXPIRED',
  'ERR_JWT_INVALID',
  'ERR_JWT_CLAIM_VALIDATION_FAILED',
  'ERR_JWS_INVALID',
  'ERR_JWS_SIGNATURE_VERIFICATION_FAILED',
  'ERR_JWKS_NO_MATCHING_KEY',
  'ERR_JWKS_MULTIPLE_MATCHING_KEYS',
]);

function isInvalidTokenError(error: unknown): boolean {
  if (!error || typeof error !== 'object' || !('code' in error)) {
    // e.g. the plain Error thrown for a token with no `sub`.
    return error instanceof Error && error.message.includes('subject');
  }
  return INVALID_TOKEN_CODES.has(String((error as { code?: unknown }).code));
}

// POST /auth/link - Attach a verified provider credential to req.user.id
authRouter.post('/link', authMiddleware, async (req: Request, res: Response) => {
  try {
    const parsed = LinkIdentitySchema.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({
        success: false,
        error: 'Invalid request body',
        details: parsed.error.errors,
      });
      return;
    }

    const userId = req.user?.id;
    if (!userId) {
      res.status(401).json({ success: false, error: 'Not authenticated' });
      return;
    }

    // The subject is taken only from the verified token, never from the body:
    // otherwise any signed-in caller could claim someone else's credential.
    let identity: AuthIdentityInput;
    try {
      identity = await verifyProviderIdentityToken(
        parsed.data.provider,
        parsed.data.identityToken
      );
    } catch (verifyError) {
      // Only a genuinely bad token is the client's fault. A JWKS fetch failure
      // during an Apple outage must not look like "your credentials are bad",
      // or clients will sign the user out over a network blip.
      if (isInvalidTokenError(verifyError)) {
        res.status(401).json({
          success: false,
          error: 'Invalid or expired identity token',
        });
        return;
      }
      console.error('Identity token verification unavailable:', verifyError);
      res.status(503).json({
        success: false,
        error: 'Identity provider unavailable, please try again',
      });
      return;
    }

    const { alreadyLinked } = await linkAuthIdentity(userId, identity);

    res.json({
      success: true,
      data: {
        provider: parsed.data.provider,
        linked: true,
        alreadyLinked,
      },
    });
  } catch (error) {
    if (error instanceof IdentityLinkConflictError) {
      res.status(409).json({
        success: false,
        error: error.message,
        code: error.code,
      });
      return;
    }
    console.error('Identity link error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to link identity',
    });
  }
});
