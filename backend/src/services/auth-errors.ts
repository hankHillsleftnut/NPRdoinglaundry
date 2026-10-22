/**
 * Sign-in failures in plain words, with a code the app can act on.
 *
 * The app used to show "Server error: HTTP 500: {"success":false,"error":"Failed
 * to sign in"}" (19 October 2026) when the real cause was an out-of-date app
 * copy. Every sign-in failure now says what happened and what to do.
 */

export type AuthErrorCode =
  | 'app_out_of_date'
  | 'sign_in_expired'
  | 'sign_in_not_confirmed'
  | 'provider_unavailable'
  | 'session_ended'
  | 'account_in_use'
  | 'bad_request'
  | 'server_error';

export interface AuthFailure {
  status: number;
  code: AuthErrorCode;
  message: string;
}

export type ProviderName = 'Apple' | 'Google';

// jose tags every "this token is not acceptable" failure with one of these.
const INVALID_TOKEN_CODES = new Set([
  'ERR_JWT_EXPIRED',
  'ERR_JWT_INVALID',
  'ERR_JWT_CLAIM_VALIDATION_FAILED',
  'ERR_JWS_INVALID',
  'ERR_JWS_SIGNATURE_VERIFICATION_FAILED',
  'ERR_JWKS_NO_MATCHING_KEY',
  'ERR_JWKS_MULTIPLE_MATCHING_KEYS',
]);

export const AUTH_MESSAGES: Record<AuthErrorCode, (provider: ProviderName) => string> = {
  app_out_of_date: () => 'This version of Retrospect is out of date. Please install the latest version, then sign in again.',
  sign_in_expired: (p) => `Your ${p} sign-in took too long to reach us. Please try again.`,
  sign_in_not_confirmed: (p) => `We couldn't confirm your ${p} sign-in. Please try again.`,
  provider_unavailable: (p) => `${p}'s sign-in service didn't respond. Please try again in a moment.`,
  session_ended: () => 'You were signed out. Please sign in again.',
  account_in_use: (p) => `That ${p} account is already connected to a different Retrospect account.`,
  bad_request: () => 'Something was missing from the sign-in request. Please update the app and try again.',
  server_error: () => "Something went wrong on our side. Please try again; if it keeps happening, let us know.",
};

export function authFailureFor(code: AuthErrorCode, provider: ProviderName = 'Apple'): AuthFailure {
  const status: Record<AuthErrorCode, number> = {
    app_out_of_date: 401,
    sign_in_expired: 401,
    sign_in_not_confirmed: 401,
    provider_unavailable: 503,
    session_ended: 401,
    account_in_use: 409,
    bad_request: 400,
    server_error: 500,
  };
  return { status: status[code], code, message: AUTH_MESSAGES[code](provider) };
}

/** Classify a thrown error from verifying a provider's token. */
export function classifyTokenError(error: unknown, provider: ProviderName = 'Apple'): AuthFailure {
  const e = (error ?? {}) as { code?: unknown; claim?: unknown; name?: unknown; message?: unknown };
  const code = typeof e.code === 'string' ? e.code : '';
  // The token was issued for a different app ID: an old copy of the app.
  if (code === 'ERR_JWT_CLAIM_VALIDATION_FAILED' && e.claim === 'aud') return authFailureFor('app_out_of_date', provider);
  if (code === 'ERR_JWT_EXPIRED') return authFailureFor('sign_in_expired', provider);
  if (INVALID_TOKEN_CODES.has(code)) return authFailureFor('sign_in_not_confirmed', provider);
  if (e.name === 'IdentityLinkConflictError') return authFailureFor('account_in_use', provider);
  // A token with no subject is a bad token, not an outage.
  if (typeof e.message === 'string' && e.message.includes('subject')) return authFailureFor('sign_in_not_confirmed', provider);
  // No jose code at all: we never got a verdict (network, key fetch).
  if (!code && (e.name === 'TypeError' || /fetch|network|timeout|ECONN/i.test(String(e.message ?? '')))) {
    return authFailureFor('provider_unavailable', provider);
  }
  return authFailureFor('server_error', provider);
}

/** Keep jose diagnostics, excluding the parsed payload and arbitrary error details. */
export function tokenErrorSummary(error: unknown): Record<string, string> {
  const summary: Record<string, string> = {};
  if (error && typeof error === 'object') {
    for (const field of ['code', 'claim', 'reason'] as const) {
      const value = (error as Record<string, unknown>)[field];
      if (typeof value === 'string') summary[field] = value;
    }
  }
  return summary;
}

/** The JSON body for a failure: `error` stays human-readable for older app builds. */
export function failureBody(f: AuthFailure) {
  return { success: false, error: f.message, code: f.code };
}
