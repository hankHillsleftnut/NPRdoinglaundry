const requiredEnv = {
  SUPABASE_URL: 'https://example.supabase.co',
  SUPABASE_SERVICE_KEY: 'service-key',
  SUPABASE_ANON_KEY: 'anon-key',
  ANTHROPIC_API_KEY: 'anthropic-key',
  OPENAI_API_KEY: 'openai-key',
  JWT_SECRET: 'jwt-secret',
  AGENT_SERVICE_URL: 'https://agent.example.com',
  INTERNAL_API_SECRET: 'internal-secret',
  GOOGLE_OAUTH_CLIENT_ID: 'google-client',
  GOOGLE_OAUTH_CLIENT_SECRET: 'google-secret',
  SPOTIFY_CLIENT_ID: 'spotify-client',
  SPOTIFY_CLIENT_SECRET: 'spotify-secret',
  REDDIT_CLIENT_ID: 'reddit-client',
  REDDIT_CLIENT_SECRET: 'reddit-secret',
  PINTEREST_CLIENT_ID: 'pinterest-client',
  PINTEREST_CLIENT_SECRET: 'pinterest-secret',
  TIKTOK_CLIENT_KEY: 'tiktok-client-key',
  TIKTOK_CLIENT_SECRET: 'tiktok-secret',
  LINKEDIN_CLIENT_ID: 'linkedin-client',
  LINKEDIN_CLIENT_SECRET: 'linkedin-secret',
  X_CLIENT_ID: 'x-client',
  X_CLIENT_SECRET: 'x-secret',
};

for (const [key, value] of Object.entries(requiredEnv)) {
  process.env[key] = process.env[key] || value;
}

describe('integration catalog and OAuth contracts', () => {
  test('consumer export-only providers are not exposed as continuous OAuth sources', () => {
    const { INTEGRATION_CATALOG } = require('../dist/services/integration-catalog.js');
    const byId = Object.fromEntries(INTEGRATION_CATALOG.map((entry) => [entry.id, entry]));

    for (const providerId of ['chatgpt', 'claude', 'grok', 'netflix']) {
      expect(byId[providerId]).toBeDefined();
      expect(byId[providerId].collectionMode).toBe('data_export');
      expect(byId[providerId].availability).toBe('export_import');
    }

    for (const providerId of ['tiktok', 'linkedin', 'x']) {
      expect(byId[providerId]).toBeDefined();
      expect(byId[providerId].collectionMode).toBe('oauth_api');
    }
  });

  test('continuous OAuth providers declare provider-specific token auth and PKCE behavior', () => {
    const { getOAuthProvider } = require('../dist/services/oauth-providers.js');
    expect(getOAuthProvider('google_docs')).toMatchObject({ tokenAuth: 'body', supportsPkce: true });
    expect(getOAuthProvider('gmail')).toMatchObject({ tokenAuth: 'body', supportsPkce: true });
    expect(getOAuthProvider('youtube')).toMatchObject({ tokenAuth: 'body', supportsPkce: true });
    expect(getOAuthProvider('spotify')).toMatchObject({ tokenAuth: 'basic', supportsPkce: true });
    expect(getOAuthProvider('reddit')).toMatchObject({ tokenAuth: 'basic', supportsPkce: false });
    expect(getOAuthProvider('pinterest')).toMatchObject({ tokenAuth: 'basic', supportsPkce: false });
    expect(getOAuthProvider('tiktok')).toMatchObject({ tokenAuth: 'body', supportsPkce: false, authorizationClientIdParam: 'client_key' });
    expect(getOAuthProvider('linkedin')).toMatchObject({ tokenAuth: 'body', supportsPkce: false, scopes: ['openid', 'profile', 'email'] });
    expect(getOAuthProvider('x')).toMatchObject({ tokenAuth: 'basic', supportsPkce: true });
  });

  test('authorization URLs preserve provider-specific parameters for tap-to-sign-in', () => {
    const { buildOAuthAuthorizationUrl, getOAuthProvider } = require('../dist/services/oauth-providers.js');
    const redirectUri = 'https://api.example.com/integrations/provider/connect/callback';

    const tiktokUrl = buildOAuthAuthorizationUrl(getOAuthProvider('tiktok'), { redirectUri, state: 'state' });
    expect(tiktokUrl.origin + tiktokUrl.pathname).toBe('https://www.tiktok.com/v2/auth/authorize/');
    expect(tiktokUrl.searchParams.get('client_key')).toBe('tiktok-client-key');
    expect(tiktokUrl.searchParams.has('client_id')).toBe(false);
    expect(tiktokUrl.searchParams.get('scope')).toBe('user.info.basic,user.info.profile,user.info.stats,video.list');

    const linkedinUrl = buildOAuthAuthorizationUrl(getOAuthProvider('linkedin'), { redirectUri, state: 'state' });
    expect(linkedinUrl.searchParams.get('client_id')).toBe('linkedin-client');
    expect(linkedinUrl.searchParams.get('scope')).toBe('openid profile email');

    const xUrl = buildOAuthAuthorizationUrl(getOAuthProvider('x'), {
      redirectUri,
      state: 'state',
      codeChallenge: 'challenge',
    });
    expect(xUrl.origin + xUrl.pathname).toBe('https://api.x.com/2/oauth2/authorize');
    expect(xUrl.searchParams.get('scope')).toContain('offline.access');
    expect(xUrl.searchParams.get('code_challenge')).toBe('challenge');
    expect(xUrl.searchParams.get('code_challenge_method')).toBe('S256');
  });

  test('token exchange bodies preserve TikTok client_key and X basic auth contracts', () => {
    const { buildOAuthTokenRequest, getOAuthProvider } = require('../dist/services/oauth-providers.js');
    const redirectUri = 'https://api.example.com/integrations/provider/connect/callback';

    const tiktok = buildOAuthTokenRequest(getOAuthProvider('tiktok'), { code: 'code', redirectUri });
    expect(tiktok.body.get('client_key')).toBe('tiktok-client-key');
    expect(tiktok.body.get('client_id')).toBeNull();
    expect(tiktok.body.get('client_secret')).toBe('tiktok-secret');
    expect(tiktok.headers.Authorization).toBeUndefined();

    const x = buildOAuthTokenRequest(getOAuthProvider('x'), {
      code: 'code',
      redirectUri,
      codeVerifier: 'verifier',
    });
    expect(x.body.get('code_verifier')).toBe('verifier');
    expect(x.body.get('client_id')).toBeNull();
    expect(x.headers.Authorization).toBe(`Basic ${Buffer.from('x-client:x-secret').toString('base64')}`);
  });

  test('OAuth readiness reports all connectable providers without leaking secrets', () => {
    const { listOAuthProviderReadiness } = require('../dist/services/oauth-providers.js');
    const readiness = listOAuthProviderReadiness();
    const byId = Object.fromEntries(readiness.map((entry) => [entry.providerId, entry]));

    for (const providerId of ['google_docs', 'gmail', 'youtube', 'spotify', 'reddit', 'pinterest', 'tiktok', 'linkedin', 'x']) {
      expect(byId[providerId]).toBeDefined();
      expect(byId[providerId].configured).toBe(true);
      expect(byId[providerId].missing).toEqual([]);
      expect(byId[providerId]).not.toHaveProperty('clientSecret');
      expect(byId[providerId]).not.toHaveProperty('clientId');
    }
  });
});
