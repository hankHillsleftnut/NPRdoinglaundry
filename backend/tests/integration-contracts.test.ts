import assert from 'node:assert/strict';
import test from 'node:test';
import { INTEGRATION_CATALOG } from '../src/services/integration-catalog.js';
import {
  buildOAuthAuthorizationUrl, buildOAuthTokenRequest, getOAuthProvider, listOAuthProviderReadiness,
} from '../src/services/oauth-providers.js';

/**
 * Ported from tests/integration-contracts.test.js, a Jest file `npm test` never
 * ran (BE0.2). Provider ids and secrets are the placeholders in tests/support/env.ts.
 */
const env = (name: string) => process.env[name] ?? '';
const provider = (id: string) => {
  const p = getOAuthProvider(id);
  assert.ok(p, `${id} is a provider`);
  return p;
};

test('consumer export-only providers are not exposed as continuous OAuth sources', () => {
  const byId = Object.fromEntries(INTEGRATION_CATALOG.map((entry) => [entry.id, entry]));
  for (const id of ['chatgpt', 'claude', 'grok', 'netflix']) {
    assert.equal(byId[id]?.collectionMode, 'data_export', id);
    assert.equal(byId[id]?.availability, 'export_import', id);
  }
  for (const id of ['tiktok', 'linkedin', 'x']) assert.equal(byId[id]?.collectionMode, 'oauth_api', id);
});

test('continuous OAuth providers declare provider-specific token auth and PKCE behavior', () => {
  const expected: Record<string, Record<string, unknown>> = {
    google_docs: { tokenAuth: 'body', supportsPkce: true },
    gmail: { tokenAuth: 'body', supportsPkce: true },
    youtube: { tokenAuth: 'body', supportsPkce: true },
    spotify: { tokenAuth: 'basic', supportsPkce: true },
    reddit: { tokenAuth: 'basic', supportsPkce: false },
    pinterest: { tokenAuth: 'basic', supportsPkce: false },
    tiktok: { tokenAuth: 'body', supportsPkce: false, authorizationClientIdParam: 'client_key' },
    linkedin: { tokenAuth: 'body', supportsPkce: false, scopes: ['openid', 'profile', 'email'] },
    x: { tokenAuth: 'basic', supportsPkce: true },
  };
  for (const [id, fields] of Object.entries(expected)) {
    const p = provider(id) as unknown as Record<string, unknown>;
    for (const [key, value] of Object.entries(fields)) assert.deepEqual(p[key], value, `${id}.${key}`);
  }
});

test('authorization URLs preserve provider-specific parameters for tap-to-sign-in', () => {
  const redirectUri = 'https://api.example.com/integrations/provider/connect/callback';

  const tiktok = buildOAuthAuthorizationUrl(provider('tiktok'), { redirectUri, state: 'state' });
  assert.equal(tiktok.origin + tiktok.pathname, 'https://www.tiktok.com/v2/auth/authorize/');
  assert.equal(tiktok.searchParams.get('client_key'), env('TIKTOK_CLIENT_KEY'));
  assert.equal(tiktok.searchParams.has('client_id'), false);
  assert.equal(tiktok.searchParams.get('scope'), 'user.info.basic,user.info.profile,user.info.stats,video.list');

  const linkedin = buildOAuthAuthorizationUrl(provider('linkedin'), { redirectUri, state: 'state' });
  assert.equal(linkedin.searchParams.get('client_id'), env('LINKEDIN_CLIENT_ID'));
  assert.equal(linkedin.searchParams.get('scope'), 'openid profile email');

  const x = buildOAuthAuthorizationUrl(provider('x'), { redirectUri, state: 'state', codeChallenge: 'challenge' });
  assert.equal(x.origin + x.pathname, 'https://api.x.com/2/oauth2/authorize');
  assert.ok(x.searchParams.get('scope')?.includes('offline.access'));
  assert.equal(x.searchParams.get('code_challenge'), 'challenge');
  assert.equal(x.searchParams.get('code_challenge_method'), 'S256');
});

test('token exchange bodies preserve TikTok client_key and X basic auth contracts', () => {
  const redirectUri = 'https://api.example.com/integrations/provider/connect/callback';

  const tiktok = buildOAuthTokenRequest(provider('tiktok'), { code: 'code', redirectUri });
  assert.equal(tiktok.body.get('client_key'), env('TIKTOK_CLIENT_KEY'));
  assert.equal(tiktok.body.get('client_id'), null);
  assert.equal(tiktok.body.get('client_secret'), env('TIKTOK_CLIENT_SECRET'));
  assert.equal(tiktok.headers.Authorization, undefined);

  const x = buildOAuthTokenRequest(provider('x'), { code: 'code', redirectUri, codeVerifier: 'verifier' });
  assert.equal(x.body.get('code_verifier'), 'verifier');
  assert.equal(x.body.get('client_id'), null);
  assert.equal(x.headers.Authorization, `Basic ${Buffer.from(`${env('X_CLIENT_ID')}:${env('X_CLIENT_SECRET')}`).toString('base64')}`);
});

test('OAuth readiness reports all connectable providers without leaking secrets', () => {
  const byId = Object.fromEntries(listOAuthProviderReadiness().map((entry) => [entry.providerId, entry]));
  for (const id of ['google_docs', 'gmail', 'youtube', 'spotify', 'reddit', 'pinterest', 'tiktok', 'linkedin', 'x']) {
    const entry = byId[id] as unknown as Record<string, unknown> | undefined;
    assert.ok(entry, id);
    assert.equal(entry.configured, true, id);
    assert.deepEqual(entry.missing, [], id);
    assert.equal('clientSecret' in entry, false, id);
    assert.equal('clientId' in entry, false, id);
  }
});
