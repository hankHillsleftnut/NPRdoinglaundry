import { config } from '../utils/config.js';

export interface OAuthProvider {
  id: string;
  authorizationUrl: string;
  tokenUrl: string;
  clientId: string;
  clientSecret: string;
  scopes: string[];
  tokenAuth: 'body' | 'basic';
  supportsPkce: boolean;
  authorizationClientIdParam?: string;
  authorizationScopeSeparator?: 'space' | 'comma';
  tokenClientIdParam?: string;
  tokenClientSecretParam?: string;
  extraAuthorizationParams?: Record<string, string>;
  extraTokenParams?: Record<string, string>;
  /** Catalog ids that share this provider's single OAuth grant (one consent
   * screen, one token, fanned out into one connection per member). Set only
   * on the aggregate provider itself. */
  memberProviderIds?: readonly string[];
}

interface AuthorizationUrlInput {
  redirectUri: string;
  state: string;
  codeChallenge?: string;
}

interface TokenRequestInput {
  code: string;
  redirectUri: string;
  codeVerifier?: string;
}

const google = {
  authorizationUrl: 'https://accounts.google.com/o/oauth2/v2/auth',
  tokenUrl: 'https://oauth2.googleapis.com/token',
  clientId: config.integrations.googleClientId,
  clientSecret: config.integrations.googleClientSecret,
  extraAuthorizationParams: { access_type: 'offline', prompt: 'consent' },
};

// Members of the combined "google" authorization below. One consent screen
// grants all these scopes at once, so the callback fans a single token out
// into a connection row per member instead of requiring three separate
// user-facing connect taps.
// google_calendar joined 18 October 2026: the founder's decision that Google
// Calendar comes in as part of the Google integration (Apple Calendar is asked
// for separately, on the iPhone). See docs/second-brain/brief-phase-4-calendar.md.
export const GOOGLE_COMBINED_MEMBERS = ['google_docs', 'gmail', 'youtube', 'google_calendar'] as const;

const providers: Record<string, OAuthProvider> = {
  google_docs: {
    id: 'google_docs',
    ...google,
    scopes: ['openid', 'email', 'https://www.googleapis.com/auth/drive.readonly', 'https://www.googleapis.com/auth/documents.readonly'],
    tokenAuth: 'body',
    supportsPkce: true,
  },
  gmail: {
    id: 'gmail',
    ...google,
    scopes: ['openid', 'email', 'https://www.googleapis.com/auth/gmail.readonly'],
    tokenAuth: 'body',
    supportsPkce: true,
  },
  youtube: {
    id: 'youtube',
    ...google,
    scopes: ['openid', 'email', 'https://www.googleapis.com/auth/youtube.readonly'],
    tokenAuth: 'body',
    supportsPkce: true,
  },
  google_calendar: {
    id: 'google_calendar',
    ...google,
    // Read-only. A "sensitive" Google scope: fine for up to 100 test users
    // while the app is unverified; needs Google's review before public launch.
    scopes: ['openid', 'email', 'https://www.googleapis.com/auth/calendar.readonly'],
    tokenAuth: 'body',
    supportsPkce: true,
  },
  google: {
    id: 'google',
    ...google,
    scopes: [
      'openid',
      'email',
      'https://www.googleapis.com/auth/drive.readonly',
      'https://www.googleapis.com/auth/documents.readonly',
      'https://www.googleapis.com/auth/gmail.readonly',
      'https://www.googleapis.com/auth/youtube.readonly',
      'https://www.googleapis.com/auth/calendar.readonly',
    ],
    tokenAuth: 'body',
    supportsPkce: true,
    memberProviderIds: GOOGLE_COMBINED_MEMBERS,
  },
  spotify: {
    id: 'spotify',
    authorizationUrl: 'https://accounts.spotify.com/authorize',
    tokenUrl: 'https://accounts.spotify.com/api/token',
    clientId: config.integrations.spotifyClientId,
    clientSecret: config.integrations.spotifyClientSecret,
    scopes: ['user-read-recently-played', 'user-library-read', 'playlist-read-private', 'user-follow-read'],
    tokenAuth: 'basic',
    supportsPkce: true,
  },
  reddit: {
    id: 'reddit',
    authorizationUrl: 'https://www.reddit.com/api/v1/authorize',
    tokenUrl: 'https://www.reddit.com/api/v1/access_token',
    clientId: config.integrations.redditClientId,
    clientSecret: config.integrations.redditClientSecret,
    scopes: ['identity', 'history', 'mysubreddits', 'read', 'save'],
    tokenAuth: 'basic',
    supportsPkce: false,
    extraAuthorizationParams: { duration: 'permanent' },
  },
  pinterest: {
    id: 'pinterest',
    authorizationUrl: 'https://www.pinterest.com/oauth/',
    tokenUrl: 'https://api.pinterest.com/v5/oauth/token',
    clientId: config.integrations.pinterestClientId,
    clientSecret: config.integrations.pinterestClientSecret,
    scopes: ['boards:read', 'pins:read', 'user_accounts:read'],
    tokenAuth: 'basic',
    supportsPkce: false,
  },
  tiktok: {
    id: 'tiktok',
    authorizationUrl: 'https://www.tiktok.com/v2/auth/authorize/',
    tokenUrl: 'https://open.tiktokapis.com/v2/oauth/token/',
    clientId: config.integrations.tiktokClientKey,
    clientSecret: config.integrations.tiktokClientSecret,
    scopes: ['user.info.basic', 'user.info.profile', 'user.info.stats', 'video.list'],
    tokenAuth: 'body',
    supportsPkce: false,
    authorizationClientIdParam: 'client_key',
    authorizationScopeSeparator: 'comma',
    tokenClientIdParam: 'client_key',
    extraAuthorizationParams: { disable_auto_auth: '0' },
  },
  linkedin: {
    id: 'linkedin',
    authorizationUrl: 'https://www.linkedin.com/oauth/v2/authorization',
    tokenUrl: 'https://www.linkedin.com/oauth/v2/accessToken',
    clientId: config.integrations.linkedinClientId,
    clientSecret: config.integrations.linkedinClientSecret,
    scopes: ['openid', 'profile', 'email'],
    tokenAuth: 'body',
    supportsPkce: false,
  },
  x: {
    id: 'x',
    authorizationUrl: 'https://api.x.com/2/oauth2/authorize',
    tokenUrl: 'https://api.x.com/2/oauth2/token',
    clientId: config.integrations.xClientId,
    clientSecret: config.integrations.xClientSecret,
    scopes: ['tweet.read', 'users.read', 'like.read', 'bookmark.read', 'follows.read', 'offline.access'],
    tokenAuth: 'basic',
    supportsPkce: true,
  },
};

// Derived once from `memberProviderIds`: maps a member catalog id (e.g.
// "gmail") to the key of the provider that actually owns its OAuth grant
// (e.g. "google"). A provider not listed as anyone's member resolves to
// itself. This is the single source of truth for the grouping — anything
// that needs to know whether/how a provider is bundled reads it from here,
// not from a hardcoded id.
const MEMBER_ALIAS: Record<string, string> = Object.fromEntries(
  Object.entries(providers).flatMap(([key, provider]) =>
    (provider.memberProviderIds ?? []).map((memberId) => [memberId, key])
  )
);

function resolveProviderKey(providerId: string): string {
  return MEMBER_ALIAS[providerId] ?? providerId;
}

export function getOAuthProviderReadiness(providerId: string) {
  const provider = providers[resolveProviderKey(providerId)];
  if (!provider) return null;
  const missing: string[] = [];
  if (!provider.clientId) missing.push(provider.authorizationClientIdParam === 'client_key' ? 'client_key' : 'client_id');
  if (!provider.clientSecret) missing.push('client_secret');
  return {
    // The catalog id the caller asked about, not the aggregate provider's id —
    // scopes/configured reflect the real (possibly combined) grant, but the
    // identity stays whatever the client is displaying a row for.
    providerId,
    configured: missing.length === 0,
    missing,
    scopes: provider.scopes,
    supportsPkce: provider.supportsPkce,
    tokenAuth: provider.tokenAuth,
  };
}

export function listOAuthProviderReadiness() {
  return Object.keys(providers)
    .filter((id) => !providers[id]?.memberProviderIds)
    .sort()
    .map(getOAuthProviderReadiness)
    .filter((entry): entry is NonNullable<ReturnType<typeof getOAuthProviderReadiness>> => Boolean(entry));
}

// Resolves a bundled member (e.g. google_docs/gmail/youtube) to the provider
// that actually owns its OAuth grant, so one authorization can cover several
// catalog ids at once. Providers that aren't anyone's member pass through.
//
// The returned object's `id` is always the caller's requested id, not the
// resolved aggregate's — callers (redirect URIs, state rows, the connected/
// error deep link) should identify the specific catalog entry the user
// interacted with, not the shared grant behind it. `memberProviderIds` still
// carries through unchanged, so the fan-out on connect still covers every
// bundled member regardless of which one was requested.
export function getOAuthProvider(providerId: string): OAuthProvider {
  const provider = providers[resolveProviderKey(providerId)];
  if (!provider) throw new Error(`${providerId} does not have a continuous OAuth connector`);
  if (!provider.clientId || !provider.clientSecret) throw new Error(`${providerId} OAuth credentials are not configured`);
  return { ...provider, id: providerId };
}

export function buildOAuthAuthorizationUrl(provider: OAuthProvider, input: AuthorizationUrlInput): URL {
  const url = new URL(provider.authorizationUrl);
  url.searchParams.set(provider.authorizationClientIdParam ?? 'client_id', provider.clientId);
  url.searchParams.set('redirect_uri', input.redirectUri);
  url.searchParams.set('response_type', 'code');
  url.searchParams.set('scope', provider.scopes.join(provider.authorizationScopeSeparator === 'comma' ? ',' : ' '));
  url.searchParams.set('state', input.state);
  if (provider.supportsPkce) {
    if (!input.codeChallenge) throw new Error(`${provider.id} OAuth authorization requires a PKCE code challenge`);
    url.searchParams.set('code_challenge', input.codeChallenge);
    url.searchParams.set('code_challenge_method', 'S256');
  }
  for (const [key, value] of Object.entries(provider.extraAuthorizationParams ?? {})) url.searchParams.set(key, value);
  return url;
}

export function buildOAuthTokenRequest(provider: OAuthProvider, input: TokenRequestInput) {
  const body = new URLSearchParams({
    grant_type: 'authorization_code',
    code: input.code,
    redirect_uri: input.redirectUri,
    ...provider.extraTokenParams,
  });
  const headers: Record<string, string> = {
    'Content-Type': 'application/x-www-form-urlencoded',
    'User-Agent': 'Retrospect/1.0',
  };
  if (provider.tokenAuth === 'basic') {
    headers.Authorization = `Basic ${Buffer.from(`${provider.clientId}:${provider.clientSecret}`).toString('base64')}`;
  } else {
    body.set(provider.tokenClientIdParam ?? 'client_id', provider.clientId);
    body.set(provider.tokenClientSecretParam ?? 'client_secret', provider.clientSecret);
  }
  if (provider.supportsPkce) {
    if (!input.codeVerifier) throw new Error(`${provider.id} OAuth token exchange requires a PKCE verifier`);
    body.set('code_verifier', input.codeVerifier);
  }
  return { headers, body };
}
