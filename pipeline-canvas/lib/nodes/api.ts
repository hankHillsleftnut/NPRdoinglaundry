import type { NodeSpec } from '../types';

// ---------------------------------------------------------------------------
// API -- the Express service on Render.
//
// This layer is almost entirely uninstrumented, and that is the honest finding.
// There is no request log table, so "did POST /content accept anything today?"
// can only be answered indirectly, by whether rows appeared downstream. Each
// card below says which of the two it is.
// ---------------------------------------------------------------------------

export const apiNodes: NodeSpec[] = [
  {
    id: 'api.signin',
    title: 'POST /auth/signin',
    purpose: 'Exchanges an Apple identity token for a Retrospect session.',
    region: 'api',
    column: 0,
    order: 0,
    source: 'backend/src/routes/auth.ts',
    probe: {
      kind: 'notInstrumented',
      reason: 'Sign-ins are not logged; only the resulting user row exists.',
      wouldNeed: 'An auth event table, or a counter exported from the service.',
    },
    caveat: 'Issues its own HS256 token. Supabase Auth is not used anywhere.',
  },
  {
    id: 'api.content',
    title: 'POST /content',
    purpose: 'The front door: accepts an entry and hands it to the agent.',
    region: 'api',
    column: 0,
    order: 1,
    source: 'backend/src/routes/content.ts',
    probe: { kind: 'rollup', source: 'raw_content' },
    caveat:
      'Colour is inferred from rows landing downstream — the endpoint itself is not logged. ' +
      'Returns 202 and forgets; no idempotency key, so a resync duplicates rows.',
  },
  {
    id: 'api.goals',
    title: 'POST /goals/synthesize',
    purpose: 'Turns stated goals into the structure the pipeline compares behaviour against.',
    region: 'api',
    column: 0,
    order: 2,
    source: 'backend/src/routes/goals.ts',
    probe: {
      kind: 'notInstrumented',
      reason: 'Goal synthesis writes goals but records no run of its own.',
      wouldNeed: 'A trace row, or a synthesized_at stamp on the goal.',
    },
  },
  {
    id: 'api.podcast',
    title: 'POST /podcasts/generate',
    purpose: 'Asks the agent to produce an episode.',
    region: 'api',
    column: 0,
    order: 3,
    source: 'backend/src/routes/podcasts.ts',
    probe: { kind: 'rollup', source: 'podcast_episodes' },
    caveat: 'Inferred from episodes appearing, not from the request itself.',
  },
  {
    id: 'api.oauth_start',
    title: 'OAuth start',
    purpose: 'Begins connecting an outside account such as Google.',
    region: 'api',
    column: 1,
    order: 0,
    source: 'backend/src/routes/integrations.ts',
    probe: { kind: 'rollup', source: 'integration_connections' },
    caveat: 'Inferred from connections existing, not from the request itself.',
  },
  {
    id: 'api.oauth_callback',
    title: 'OAuth callback',
    purpose: 'Receives the provider’s redirect and stores the grant.',
    region: 'api',
    column: 1,
    order: 1,
    source: 'backend/src/routes/integrations.ts',
    probe: {
      kind: 'notInstrumented',
      reason: 'Callback outcomes are not logged; only a successful connection leaves a row.',
      wouldNeed: 'Record failed callbacks — the ones worth seeing leave nothing today.',
    },
  },
  {
    id: 'api.device_batches',
    title: 'POST /device-batches',
    purpose: 'Bulk upload path for on-device sources like Health and Screen Time.',
    region: 'api',
    column: 1,
    order: 2,
    source: 'backend/src/routes/integrations.ts',
    probe: {
      kind: 'rollup',
      source: 'raw_content',
      bucket: ['healthkit', 'screen_time', 'calendar', 'apple_music', 'photos', 'contacts'],
    },
    caveat: 'Inferred from device rows arriving. Dominated by HealthKit, which is the bulk of them.',
  },
  {
    id: 'api.imports',
    title: 'POST /imports',
    purpose: 'Accepts bulk history such as an Apple Notes export.',
    region: 'api',
    column: 1,
    order: 3,
    source: 'backend/src/routes/integrations.ts',
    probe: {
      kind: 'notInstrumented',
      reason: 'Imports land as ordinary rows with nothing marking them as an import.',
      wouldNeed: 'An import batch id on raw_content.',
    },
  },
  {
    id: 'api.agent_client',
    title: 'Agent client',
    purpose: 'The backend’s HTTP call into the private agent service.',
    region: 'api',
    column: 1,
    order: 4,
    source: 'backend/src/services/agent-client.ts',
    probe: {
      kind: 'notInstrumented',
      reason: 'Calls into the agent are not recorded on either side of the hop.',
      wouldNeed: 'Log the call and its outcome; a timeout here is currently invisible.',
    },
    caveat: 'Retries on 429 only. 450s timeout — other failures are dropped silently.',
  },
];
