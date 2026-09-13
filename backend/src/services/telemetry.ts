import * as Sentry from '@sentry/node';
import { isTestAccount } from './accounts.js';

if (process.env.SENTRY_DSN) {
  Sentry.init({
    dsn: process.env.SENTRY_DSN,
    environment: process.env.RETROSPECT_ENV ?? process.env.NODE_ENV ?? 'development',
    release: process.env.RENDER_GIT_COMMIT,
    tracesSampleRate: Number(process.env.SENTRY_TRACES_SAMPLE_RATE ?? 0.1),
    sendDefaultPii: false,
  });
}

export function captureException(error: unknown, context?: Record<string, unknown>): void {
  Sentry.captureException(error, { extra: context });
}

/**
 * Capture an error that belongs to a specific user.
 *
 * Test-account errors are DROPPED rather than reported. Sentry issue counts,
 * error-rate alerts and release-health are aggregates over users, and a founder
 * deliberately breaking things on a test account in production must not move
 * those numbers or page anyone.
 *
 * Errors with no user attached still report — infrastructure failures are not
 * attributable to an account and must never be silently swallowed.
 */
export function captureExceptionForUser(
  error: unknown,
  user: { id?: string; accountType?: unknown; account_type?: unknown } | null | undefined,
  context?: Record<string, unknown>
): void {
  if (isTestAccount(user)) {
    console.warn('[telemetry] suppressed error from test account:', error);
    return;
  }

  Sentry.captureException(error, {
    extra: context,
    // 'unknown' rather than 'real' when no user is attached — infra and
    // unauthenticated errors are not attributable to an account, and labelling
    // them 'real' would quietly inflate whatever you filter on.
    tags: { account_type: user?.id ? 'real' : 'unknown' },
    user: user?.id ? { id: user.id } : undefined,
  });
}
