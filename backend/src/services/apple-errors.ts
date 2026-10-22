/**
 * Which failures of verifyAppleIdentityToken mean "this token is no good"
 * (the caller's fault: 401) rather than "we couldn't check it" (ours: 500).
 *
 * Matched on jose's stable error codes rather than its classes, so this module
 * doesn't load jose (ESM-only) just to classify an error. A failure to fetch
 * Apple's keys (ERR_JWKS_TIMEOUT, network errors) is not listed: that is a 500.
 */
const REJECTED_TOKEN_CODES: ReadonlySet<string> = new Set([
  'ERR_JWT_EXPIRED',
  'ERR_JWS_SIGNATURE_VERIFICATION_FAILED',
  'ERR_JWT_CLAIM_VALIDATION_FAILED',
  'ERR_JWKS_NO_MATCHING_KEY',
  // Malformed tokens: not a JWT at all, or a JWS that doesn't parse.
  'ERR_JWT_INVALID',
  'ERR_JWS_INVALID',
  // An algorithm Apple never uses (alg "none", HS256): a forged or foreign token.
  // jwtVerify's `algorithms: ['RS256']` refuses them with ERR_JOSE_ALG_NOT_ALLOWED.
  'ERR_JOSE_NOT_SUPPORTED',
  'ERR_JOSE_ALG_NOT_ALLOWED',
]);

export function isRejectedAppleToken(err: unknown): boolean {
  const code = (err as { code?: unknown } | null)?.code;
  return typeof code === 'string' && REJECTED_TOKEN_CODES.has(code);
}

export const INVALID_APPLE_TOKEN = { success: false, error: 'Invalid Apple identity token' } as const;
