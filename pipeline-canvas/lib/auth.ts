import { createHmac, timingSafeEqual, randomBytes } from 'node:crypto';

// ---------------------------------------------------------------------------
// The gate.
//
// Supabase Auth has never been used by this product -- public.users.id is a
// fresh uuid from Apple sign-in and has no relationship to auth.users. Bringing
// it in purely to guard one page would add an identity system nothing else
// understands. A password and a signed cookie is the whole requirement.
//
// The service key never reaches the browser: every read happens server-side and
// only computed node states are sent down.
// ---------------------------------------------------------------------------

export const COOKIE_NAME = 'canvas_session';
const MAX_AGE_SECONDS = 60 * 60 * 12;

function secret(): string {
  const s = process.env.CANVAS_SESSION_SECRET;
  if (!s || s.length < 32) {
    throw new Error('CANVAS_SESSION_SECRET must be set to at least 32 characters');
  }
  return s;
}

function hmac(data: string): string {
  return createHmac('sha256', secret()).update(data).digest('base64url');
}

/** Constant-time string compare that does not leak length through early exit. */
function safeEqual(a: string, b: string): boolean {
  const ab = Buffer.from(hmac(a));
  const bb = Buffer.from(hmac(b));
  return ab.length === bb.length && timingSafeEqual(ab, bb);
}

export function checkPassword(supplied: string): boolean {
  const expected = process.env.CANVAS_PASSWORD;
  if (!expected) throw new Error('CANVAS_PASSWORD is not set');
  if (expected === 'change-me-before-deploy' && process.env.NODE_ENV === 'production') {
    throw new Error('CANVAS_PASSWORD is still the placeholder; refusing to run in production');
  }
  return safeEqual(supplied, expected);
}

export function issueToken(): string {
  const payload = JSON.stringify({
    exp: Date.now() + MAX_AGE_SECONDS * 1000,
    jti: randomBytes(8).toString('hex'),
  });
  const body = Buffer.from(payload).toString('base64url');
  return `${body}.${hmac(body)}`;
}

export function verifyToken(token: string | undefined): boolean {
  if (!token) return false;
  const [body, sig] = token.split('.');
  if (!body || !sig) return false;

  const expected = Buffer.from(hmac(body));
  const given = Buffer.from(sig);
  if (expected.length !== given.length || !timingSafeEqual(expected, given)) return false;

  try {
    const { exp } = JSON.parse(Buffer.from(body, 'base64url').toString());
    return typeof exp === 'number' && exp > Date.now();
  } catch {
    return false;
  }
}

export const cookieOptions = {
  httpOnly: true,
  sameSite: 'lax' as const,
  secure: process.env.NODE_ENV === 'production',
  path: '/',
  maxAge: MAX_AGE_SECONDS,
};
