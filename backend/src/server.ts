import './services/telemetry.js';
import { createApp } from './app.js';
import { config } from './utils/config.js';
import { supabaseUserLookup } from './middleware/auth.js';
import { applyServerTimeouts } from './server-settings.js';
import { createAgentDoorClient } from './doors/agent.js';
import { createDiagnosticsStore } from './diagnostics/store.js';
import { supabaseDiagnosticsBackend } from './diagnostics/supabase-backend.js';
import { startDiagnosticsPurge } from './diagnostics/purge.js';
import { captureException } from './services/telemetry.js';
import { supabaseAccessStore, type AccessRpcClient } from './access/store.js';
import { supabaseInviteStore } from './invites/store.js';
import { supabaseEntryStore } from './entries/store.js';
import { supabaseAdmin } from './utils/supabase.js';
import { supabaseDeletionStore } from './account/store.js';
import { createAccountDeletion, createBrainSweep, startDeletionSweeper } from './account/deletion.js';
import { createAppleDeletionTools } from './services/apple-tokens.js';

const diagnostics = createDiagnosticsStore(supabaseDiagnosticsBackend(supabaseAdmin));
const rpc = supabaseAdmin as unknown as AccessRpcClient;

// Account deletion (BE0.7): migration 028's functions, Apple only with
// APPLE_REVOKE_ENABLED on (a bad Apple config stops the start, as for sign-in),
// the brain's sweep over the internal secret.
const appleForDeletion = createAppleDeletionTools({ settings: config.apple });
const account = createAccountDeletion({
  store: supabaseDeletionStore(rpc),
  ...(appleForDeletion ? { apple: appleForDeletion } : {}),
  brain: createBrainSweep({ baseUrl: config.agent.serviceUrl, internalSecret: config.agent.internalSecret }),
  diagnostics,
  now: Date.now,
  report: (err, where) => captureException(err, { job: where }),
});

/** The real server: real dependencies, then listen. `npm start` reaches this through index.ts. */
const app = createApp({
  agent: createAgentDoorClient({ baseUrl: config.agent.serviceUrl, internalSecret: config.agent.internalSecret }),
  now: Date.now,
  users: supabaseUserLookup,
  diagnostics,
  access: supabaseAccessStore(rpc),
  invites: supabaseInviteStore(rpc),
  entries: supabaseEntryStore(rpc),
  account,
});

console.log('Legacy backend crons are disabled. Agent crons own ingestion and podcasts.');

const server = app.listen(config.server.port, () => {
  console.log(`Server running on port ${config.server.port}`);
  console.log(`Environment: ${config.server.nodeEnv}`);
});

applyServerTimeouts(server);

// Diagnostics reports are kept 30 days (DG.1).
startDiagnosticsPurge(diagnostics, { now: Date.now, report: (err) => captureException(err, { job: 'diagnostics.purge' }) });

// Unfinished deletions (a crash or a redeploy after the lock) are finished: at start, then every five minutes.
startDeletionSweeper(account, { report: (err) => captureException(err, { job: 'account.delete.sweep' }) });

export default app;
