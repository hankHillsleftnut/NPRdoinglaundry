import { Router } from 'express';
import { createHash, randomBytes, randomUUID } from 'crypto';
import { INTEGRATION_CATALOG } from '../services/integration-catalog.js';
import { supabaseAdmin, Tables } from '../utils/supabase.js';
import { IngestIntegrationItemsSchema } from '../types/index.js';
import {
  enqueueAgentIntegrationBatch,
  queueAgentIntegrationImport,
  requestAgentIntegrationDataDeletion,
  requestAgentIntegrationSync,
  storeAgentIntegrationCredentials,
} from '../services/agent-client.js';
import {
  buildOAuthAuthorizationUrl,
  buildOAuthTokenRequest,
  getOAuthProvider,
  getOAuthProviderReadiness,
  listOAuthProviderReadiness,
} from '../services/oauth-providers.js';
import { config } from '../utils/config.js';

export const integrationsRouter = Router();
export const integrationOauthCallbackRouter = Router();

function sha256(value: string): string {
  return createHash('sha256').update(value).digest('hex');
}

function base64url(bytes: Buffer): string {
  return bytes.toString('base64url');
}

async function ensureConnection(userId: string, providerId: string, collectionMode: string, status = 'action_required') {
  const now = new Date().toISOString();
  const { data: existing, error: existingError } = await supabaseAdmin
    .from(Tables.INTEGRATION_CONNECTIONS)
    .select('id')
    .eq('user_id', userId)
    .eq('provider_id', providerId)
    .maybeSingle();
  if (existingError) throw new Error(`Failed to load integration connection: ${existingError.message}`);
  if (existing) {
    const { data, error } = await supabaseAdmin.from(Tables.INTEGRATION_CONNECTIONS)
      .update({ collection_mode: collectionMode, disconnected_at: null })
      .eq('id', existing.id)
      .select('id')
      .single();
    if (error || !data) throw new Error(`Failed to update integration connection: ${error?.message ?? 'no row'}`);
    return data;
  }
  const { data, error } = await supabaseAdmin
    .from(Tables.INTEGRATION_CONNECTIONS)
    .insert({
      user_id: userId,
      provider_id: providerId,
      collection_mode: collectionMode,
      status,
      connected_at: now,
      last_verified_at: status === 'connected' ? now : null,
      disconnected_at: null,
    })
    .select('id')
    .single();
  if (error || !data) throw new Error(`Failed to create integration connection: ${error?.message ?? 'no row'}`);
  return data;
}

integrationsRouter.get('/catalog', (_req, res) => {
  res.json({
    success: true,
    data: INTEGRATION_CATALOG,
  });
});

integrationsRouter.get('/', async (req, res) => {
  try {
    const { data, error } = await supabaseAdmin
      .from(Tables.INTEGRATION_CONNECTIONS)
      .select('id, provider_id, collection_mode, status, granted_scopes, provider_account_label, connected_at, last_verified_at, metadata')
      .eq('user_id', req.user!.id);

    if (error) throw error;

    const connections = new Map((data ?? []).map((row) => [row.provider_id, row]));
    res.json({
      success: true,
      data: INTEGRATION_CATALOG.map((provider) => ({
        ...provider,
        connection: connections.get(provider.id) ?? null,
      })),
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      error: err instanceof Error ? err.message : 'Failed to load integrations',
    });
  }
});

integrationsRouter.get('/connections', async (req, res) => {
  try {
    const { data, error } = await supabaseAdmin
      .from(Tables.INTEGRATION_CONNECTIONS)
      .select('id,provider_id,collection_mode,status,granted_scopes,provider_account_label,connected_at,last_verified_at,metadata,integration_sync_states(last_attempt_at,last_success_at,last_error,consecutive_failures),integration_jobs(id,status,job_type,created_at,completed_at)')
      .eq('user_id', req.user!.id);
    if (error) throw error;
    res.json({ success: true, data: data ?? [] });
  } catch (err) {
    res.status(500).json({ success: false, error: err instanceof Error ? err.message : 'Failed to load connections' });
  }
});

integrationsRouter.get('/readiness', (_req, res) => {
  res.json({ success: true, data: listOAuthProviderReadiness() });
});

integrationsRouter.post('/:providerId/native-connected', async (req, res) => {
  try {
    const provider = INTEGRATION_CATALOG.find((entry) => entry.id === req.params.providerId);
    if (!provider || provider.collectionMode !== 'native_ios') {
      res.status(400).json({ success: false, error: 'Provider is not a native integration' });
      return;
    }

    const now = new Date().toISOString();
    const { data, error } = await supabaseAdmin
      .from(Tables.INTEGRATION_CONNECTIONS)
      .upsert({
        user_id: req.user!.id,
        provider_id: provider.id,
        collection_mode: provider.collectionMode,
        status: 'action_required',
        connected_at: now,
        last_verified_at: now,
        disconnected_at: null,
        metadata: req.body?.metadata ?? {},
      }, { onConflict: 'user_id,provider_id' })
      .select('id, provider_id, collection_mode, status, connected_at, last_verified_at')
      .single();

    if (error) throw error;
    res.json({ success: true, data });
  } catch (err) {
    res.status(500).json({
      success: false,
      error: err instanceof Error ? err.message : 'Failed to record native integration',
    });
  }
});

integrationsRouter.delete('/:providerId', async (req, res) => {
  try {
    const { error } = await supabaseAdmin
      .from(Tables.INTEGRATION_CONNECTIONS)
      .update({
        status: 'disconnected',
        disconnected_at: new Date().toISOString(),
      })
      .eq('user_id', req.user!.id)
      .eq('provider_id', req.params.providerId);

    if (error) throw error;
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({
      success: false,
      error: err instanceof Error ? err.message : 'Failed to disconnect integration',
    });
  }
});

integrationsRouter.delete('/connections/:connectionId', async (req, res) => {
  try {
    const { error } = await supabaseAdmin.from(Tables.INTEGRATION_CONNECTIONS).update({
      status: 'disconnected',
      disconnected_at: new Date().toISOString(),
    }).eq('id', req.params.connectionId).eq('user_id', req.user!.id);
    if (error) throw error;
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err instanceof Error ? err.message : 'Failed to disconnect integration' });
  }
});

integrationsRouter.post('/:providerId/items', async (req, res) => {
  const provider = INTEGRATION_CATALOG.find((entry) => entry.id === req.params.providerId);
  if (!provider) {
    res.status(404).json({ success: false, error: 'Unknown integration provider' });
    return;
  }

  const validation = IngestIntegrationItemsSchema.safeParse(req.body);
  if (!validation.success) {
    res.status(400).json({
      success: false,
      error: 'Invalid integration item batch',
      details: validation.error.errors,
    });
    return;
  }

  try {
    const idempotencyKey = validation.data.idempotencyKey
      ?? `legacy:${sha256(JSON.stringify({ providerId: provider.id, body: validation.data }))}`;
    const result = await enqueueAgentIntegrationBatch({
      userId: req.user!.id,
      providerId: provider.id,
      collectionMode: provider.collectionMode,
      idempotencyKey,
      ...validation.data,
    });
    res.status(202).json({
      success: true,
      data: result,
    });
  } catch (err) {
    res.status(500).json({
      success: false,
      error: err instanceof Error ? err.message : 'Failed to ingest integration items',
    });
  }
});

integrationsRouter.post('/:providerId/device-batches', async (req, res) => {
  const provider = INTEGRATION_CATALOG.find((entry) => entry.id === req.params.providerId);
  if (!provider || provider.collectionMode !== 'native_ios') {
    res.status(400).json({ success: false, error: 'Provider is not a native iOS integration' });
    return;
  }
  const validation = IngestIntegrationItemsSchema.safeParse(req.body);
  if (!validation.success) {
    res.status(400).json({ success: false, error: 'Invalid integration item batch', details: validation.error.errors });
    return;
  }
  try {
    const idempotencyKey = validation.data.idempotencyKey
      ?? `device:${sha256(JSON.stringify({ providerId: provider.id, body: validation.data }))}`;
    const result = await enqueueAgentIntegrationBatch({
      userId: req.user!.id,
      providerId: provider.id,
      collectionMode: 'native_ios',
      idempotencyKey,
      ...validation.data,
    });
    res.status(202).json({ success: true, data: result });
  } catch (err) {
    res.status(500).json({ success: false, error: err instanceof Error ? err.message : 'Failed to queue device batch' });
  }
});

integrationsRouter.post('/:providerId/imports', async (req, res) => {
  const provider = INTEGRATION_CATALOG.find((entry) => entry.id === req.params.providerId);
  if (!provider) {
    res.status(404).json({ success: false, error: 'Unknown integration provider' });
    return;
  }
  const filename = typeof req.body?.filename === 'string' ? req.body.filename : '';
  const contentType = typeof req.body?.contentType === 'string' ? req.body.contentType : 'application/octet-stream';
  const byteSize = Number(req.body?.byteSize ?? 0);
  if (!filename || !Number.isFinite(byteSize) || byteSize <= 0 || byteSize > 1024 * 1024 * 1024) {
    res.status(400).json({ success: false, error: 'A filename and byteSize between 1 byte and 1 GB are required' });
    return;
  }
  try {
    const connection = await ensureConnection(req.user!.id, provider.id, 'data_export', 'action_required');
    const importId = randomUUID();
    const extension = filename.includes('.') ? filename.slice(filename.lastIndexOf('.')).toLowerCase() : '';
    const storagePath = `${req.user!.id}/${provider.id}/${importId}${extension}`;
    const { data: signed, error: signedError } = await supabaseAdmin.storage
      .from('integration-imports')
      .createSignedUploadUrl(storagePath);
    if (signedError || !signed) throw new Error(`Failed to create upload URL: ${signedError?.message ?? 'no URL'}`);
    const { error } = await supabaseAdmin.from(Tables.INTEGRATION_IMPORTS).insert({
      id: importId,
      user_id: req.user!.id,
      connection_id: connection.id,
      storage_path: storagePath,
      original_filename: filename,
      content_type: contentType,
      byte_size: byteSize,
      status: 'awaiting_upload',
    });
    if (error) throw error;
    res.status(201).json({ success: true, data: { importId, storagePath, uploadToken: signed.token, signedUrl: signed.signedUrl } });
  } catch (err) {
    res.status(500).json({ success: false, error: err instanceof Error ? err.message : 'Failed to create import' });
  }
});

integrationsRouter.post('/:providerId/assets', async (req, res) => {
  const provider = INTEGRATION_CATALOG.find((entry) => entry.id === req.params.providerId);
  const providerObjectType = typeof req.body?.providerObjectType === 'string' ? req.body.providerObjectType : '';
  const providerObjectId = typeof req.body?.providerObjectId === 'string' ? req.body.providerObjectId : '';
  const assetRole = typeof req.body?.assetRole === 'string' ? req.body.assetRole : 'original';
  const byteSize = Number(req.body?.byteSize ?? 0);
  const contentType = typeof req.body?.contentType === 'string' ? req.body.contentType : 'application/octet-stream';
  const digest = typeof req.body?.sha256 === 'string' ? req.body.sha256.toLowerCase() : '';
  if (!provider || !providerObjectType || !providerObjectId || !Number.isFinite(byteSize) || byteSize <= 0 || byteSize > 5 * 1024 * 1024 * 1024) {
    res.status(400).json({ success: false, error: 'Invalid source asset request' });
    return;
  }
  if (digest && !/^[a-f0-9]{64}$/.test(digest)) {
    res.status(400).json({ success: false, error: 'A valid SHA-256 digest is required' });
    return;
  }
  try {
    const connection = await ensureConnection(req.user!.id, provider.id, provider.collectionMode);
    const assetId = randomUUID();
    const storagePath = `${req.user!.id}/${provider.id}/${assetId}`;
    const { data: signed, error: signedError } = await supabaseAdmin.storage.from('integration-media').createSignedUploadUrl(storagePath);
    if (signedError || !signed) throw new Error(`Failed to create asset upload URL: ${signedError?.message ?? 'no URL'}`);
    const { error } = await supabaseAdmin.from(Tables.SOURCE_ASSETS).insert({
      id: assetId,
      user_id: req.user!.id,
      connection_id: connection.id,
      provider_object_type: providerObjectType,
      provider_object_id: providerObjectId,
      asset_role: assetRole,
      storage_path: storagePath,
      content_type: contentType,
      byte_size: byteSize,
      sha256: digest || null,
      status: 'awaiting_upload',
    });
    if (error?.code === '23505') {
      res.status(409).json({ success: false, error: 'This source asset has already been uploaded' });
      return;
    }
    if (error) throw error;
    res.status(201).json({ success: true, data: { assetId, signedUrl: signed.signedUrl, uploadToken: signed.token } });
  } catch (err) {
    res.status(500).json({ success: false, error: err instanceof Error ? err.message : 'Failed to create source asset' });
  }
});

integrationsRouter.post('/assets/:assetId/complete', async (req, res) => {
  try {
    const digest = typeof req.body?.sha256 === 'string' ? req.body.sha256.toLowerCase() : '';
    if (!/^[a-f0-9]{64}$/.test(digest)) {
      res.status(400).json({ success: false, error: 'A valid SHA-256 digest is required' });
      return;
    }
    const { data, error } = await supabaseAdmin.from(Tables.SOURCE_ASSETS).update({
      status: 'uploaded',
      uploaded_at: new Date().toISOString(),
      sha256: digest,
    }).eq('id', req.params.assetId).eq('user_id', req.user!.id).select('id').single();
    if (error || !data) {
      res.status(404).json({ success: false, error: 'Source asset not found' });
      return;
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err instanceof Error ? err.message : 'Failed to complete source asset' });
  }
});

integrationsRouter.post('/imports/:importId/complete', async (req, res) => {
  try {
    const digest = typeof req.body?.sha256 === 'string' ? req.body.sha256.toLowerCase() : '';
    if (!/^[a-f0-9]{64}$/.test(digest)) {
      res.status(400).json({ success: false, error: 'A valid SHA-256 digest is required' });
      return;
    }
    const { data: importRow, error } = await supabaseAdmin
      .from(Tables.INTEGRATION_IMPORTS)
      .select('id,connection_id,integration_connections(provider_id)')
      .eq('id', req.params.importId)
      .eq('user_id', req.user!.id)
      .single();
    if (error || !importRow) {
      res.status(404).json({ success: false, error: 'Import not found' });
      return;
    }
    const { error: updateError } = await supabaseAdmin.from(Tables.INTEGRATION_IMPORTS).update({
      status: 'uploaded',
      uploaded_at: new Date().toISOString(),
      sha256: digest,
    }).eq('id', importRow.id);
    if (updateError?.code === '23505') {
      res.status(409).json({ success: false, error: 'This archive has already been imported for this source' });
      return;
    }
    if (updateError) throw updateError;
    const relation = importRow.integration_connections as unknown as { provider_id: string } | { provider_id: string }[];
    const providerId = Array.isArray(relation) ? relation[0]?.provider_id : relation.provider_id;
    const job = await queueAgentIntegrationImport({
      userId: req.user!.id,
      providerId,
      importId: importRow.id,
      idempotencyKey: `archive:${importRow.id}`,
    });
    res.status(202).json({ success: true, data: job });
  } catch (err) {
    res.status(500).json({ success: false, error: err instanceof Error ? err.message : 'Failed to queue import' });
  }
});

integrationsRouter.post('/:providerId/connect/start', async (req, res) => {
  try {
    const provider = getOAuthProvider(req.params.providerId);
    const state = base64url(randomBytes(32));
    const verifier = base64url(randomBytes(64));
    const challenge = base64url(createHash('sha256').update(verifier).digest());
    const redirectUri = `${config.integrations.oauthCallbackBaseUrl.replace(/\/+$/, '')}/integrations/${provider.id}/connect/callback`;
    const { error } = await supabaseAdmin.from(Tables.INTEGRATION_OAUTH_STATES).insert({
      user_id: req.user!.id,
      provider_id: provider.id,
      state_hash: sha256(state),
      code_verifier: verifier,
      redirect_uri: redirectUri,
      expires_at: new Date(Date.now() + 10 * 60_000).toISOString(),
    });
    if (error) throw error;
    const url = buildOAuthAuthorizationUrl(provider, { redirectUri, state, codeChallenge: challenge });
    res.json({ success: true, data: { authorizationUrl: url.toString() } });
  } catch (err) {
    res.status(400).json({
      success: false,
      error: err instanceof Error ? err.message : 'Could not start OAuth connection',
      readiness: getOAuthProviderReadiness(req.params.providerId),
    });
  }
});

integrationsRouter.post('/connections/:connectionId/sync', async (req, res) => {
  try {
    const { data, error } = await supabaseAdmin.from(Tables.INTEGRATION_CONNECTIONS)
      .select('id').eq('id', req.params.connectionId).eq('user_id', req.user!.id).single();
    if (error || !data) {
      res.status(404).json({ success: false, error: 'Connection not found' });
      return;
    }
    const job = await requestAgentIntegrationSync(data.id, req.user!.id);
    res.status(202).json({ success: true, data: job });
  } catch (err) {
    res.status(500).json({ success: false, error: err instanceof Error ? err.message : 'Failed to queue sync' });
  }
});

integrationsRouter.post('/connections/:connectionId/reconnect', async (req, res) => {
  try {
    const { error } = await supabaseAdmin.from(Tables.INTEGRATION_CONNECTIONS).update({
      status: 'action_required',
      disconnected_at: null,
    }).eq('id', req.params.connectionId).eq('user_id', req.user!.id);
    if (error) throw error;
    const job = await requestAgentIntegrationSync(req.params.connectionId, req.user!.id);
    res.status(202).json({ success: true, data: job });
  } catch (err) {
    res.status(500).json({ success: false, error: err instanceof Error ? err.message : 'Failed to reconnect' });
  }
});

integrationsRouter.delete('/connections/:connectionId/data', async (req, res) => {
  try {
    const { data, error } = await supabaseAdmin.from(Tables.INTEGRATION_CONNECTIONS)
      .select('id').eq('id', req.params.connectionId).eq('user_id', req.user!.id).single();
    if (error || !data) {
      res.status(404).json({ success: false, error: 'Connection not found' });
      return;
    }
    const job = await requestAgentIntegrationDataDeletion(data.id, req.user!.id);
    res.status(202).json({ success: true, data: job });
  } catch (err) {
    res.status(500).json({ success: false, error: err instanceof Error ? err.message : 'Failed to queue data deletion' });
  }
});

integrationOauthCallbackRouter.get('/:providerId/connect/callback', async (req, res) => {
  const state = typeof req.query.state === 'string' ? req.query.state : '';
  const code = typeof req.query.code === 'string' ? req.query.code : '';
  if (!state || !code) {
    res.status(400).send('Missing OAuth state or code');
    return;
  }
  try {
    const provider = getOAuthProvider(req.params.providerId);
    const { data: oauthState, error } = await supabaseAdmin
      .from(Tables.INTEGRATION_OAUTH_STATES)
      .select('*')
      .eq('state_hash', sha256(state))
      .eq('provider_id', provider.id)
      .is('consumed_at', null)
      .gt('expires_at', new Date().toISOString())
      .single();
    if (error || !oauthState) {
      res.status(400).send('OAuth state is invalid or expired');
      return;
    }

    const { headers: tokenHeaders, body } = buildOAuthTokenRequest(provider, {
      code,
      redirectUri: oauthState.redirect_uri,
      codeVerifier: oauthState.code_verifier,
    });
    const tokenResponse = await fetch(provider.tokenUrl, {
      method: 'POST',
      headers: tokenHeaders,
      body,
    });
    const tokens = await tokenResponse.json() as Record<string, unknown>;
    if (!tokenResponse.ok) throw new Error(`Provider token exchange failed (${tokenResponse.status})`);
    const connection = await ensureConnection(oauthState.user_id, provider.id, 'oauth_api');
    const expiresIn = typeof tokens.expires_in === 'number' ? tokens.expires_in : null;
    await storeAgentIntegrationCredentials(connection.id, {
      userId: oauthState.user_id,
      credentials: tokens,
      expiresAt: expiresIn ? new Date(Date.now() + expiresIn * 1000).toISOString() : undefined,
      metadata: { scopes: provider.scopes },
    });
    await supabaseAdmin.from(Tables.INTEGRATION_OAUTH_STATES).update({ consumed_at: new Date().toISOString() }).eq('id', oauthState.id);
    await requestAgentIntegrationSync(connection.id, oauthState.user_id);
    const redirect = new URL(config.integrations.appRedirectUrl);
    redirect.searchParams.set('provider', provider.id);
    redirect.searchParams.set('status', 'syncing');
    res.redirect(redirect.toString());
  } catch (err) {
    console.error('[integrations] OAuth callback failed:', err instanceof Error ? err.message : err);
    const redirect = new URL(config.integrations.appRedirectUrl);
    redirect.searchParams.set('provider', req.params.providerId);
    redirect.searchParams.set('status', 'error');
    res.redirect(redirect.toString());
  }
});
