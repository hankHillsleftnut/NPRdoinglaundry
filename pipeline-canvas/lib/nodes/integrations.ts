import type { NodeSpec } from '../types';

// ---------------------------------------------------------------------------
// INTEGRATIONS -- the connector subsystem in the agent.
//
// Expect this whole region to read "no rows, ever". integration_jobs,
// integration_sync_runs, integration_test_runs, source_payloads, source_items
// and analysis_units are all empty in production. That is a true statement
// about the product, not a gap in the dashboard, and it is the single most
// useful thing this region says on day one.
//
// Note the contradiction it exposes: 332 google_docs rows exist in raw_content
// while every table in this region is empty. That content reached the bank
// without passing through any of these steps.
// ---------------------------------------------------------------------------

export const integrationNodes: NodeSpec[] = [
  {
    id: 'int.connection',
    title: 'Connection',
    purpose: 'A live grant to read someone’s outside account.',
    region: 'integrations',
    column: 0,
    order: 0,
    source: 'backend/src/routes/integrations.ts',
    probe: { kind: 'rollup', source: 'integration_connections' },
  },
  {
    id: 'int.vault',
    title: 'Credential vault',
    purpose: 'Holds provider tokens encrypted with AES-256-GCM under KMS.',
    region: 'integrations',
    column: 0,
    order: 1,
    source: 'retrospect-agent/src/services/credential-vault.ts',
    probe: {
      kind: 'notInstrumented',
      reason: 'Deliberately not read by this dashboard, not even for a count.',
      wouldNeed: 'Nothing. This one stays dark on purpose.',
    },
  },
  {
    id: 'int.scheduler',
    title: 'Scheduler',
    purpose: 'Decides when each connector should next go and fetch.',
    region: 'integrations',
    column: 0,
    order: 2,
    source: 'retrospect-agent/src/jobs/integration-scheduler.ts',
    probe: {
      kind: 'notInstrumented',
      reason: 'The scheduler tick goes to stdout and is never persisted.',
      wouldNeed: 'A row per tick, so a stopped scheduler is visible.',
    },
  },
  {
    id: 'int.jobs',
    title: 'Job queue',
    purpose: 'Work waiting to be picked up, leased and retried.',
    region: 'integrations',
    column: 1,
    order: 0,
    source: 'retrospect-agent/src/services/integration-queue.ts',
    probe: { kind: 'rollup', source: 'integration_jobs' },
  },
  {
    id: 'int.worker',
    title: 'Worker loop',
    purpose: 'The process that actually claims jobs and runs them.',
    region: 'integrations',
    column: 1,
    order: 1,
    source: 'retrospect-agent/src/jobs/integration-worker.ts',
    probe: {
      kind: 'notInstrumented',
      reason: 'There is no heartbeat table; a dead worker looks exactly like an idle one.',
      wouldNeed: 'A worker heartbeat row, or expose lease age from /health/metrics.',
    },
  },
  {
    id: 'int.sync_run',
    title: 'Sync run',
    purpose: 'One attempt to pull new material from a connected account.',
    region: 'integrations',
    column: 1,
    order: 2,
    source: 'retrospect-agent/src/connectors/connector.ts',
    probe: { kind: 'rollup', source: 'integration_sync_runs' },
    caveat: 'job_id is never populated, so a run cannot be traced back to its job.',
  },
  {
    id: 'int.payloads',
    title: 'Source payloads',
    purpose: 'The raw response from the provider, kept exactly as received.',
    region: 'integrations',
    column: 2,
    order: 0,
    source: 'retrospect-agent/src/pipelines/graph-v2.ts',
    probe: { kind: 'rollup', source: 'source_payloads' },
  },
  {
    id: 'int.items',
    title: 'Source items',
    purpose: 'That payload split into individual documents or events.',
    region: 'integrations',
    column: 2,
    order: 1,
    source: 'retrospect-agent/src/pipelines/graph-v2.ts',
    probe: { kind: 'rollup', source: 'source_items' },
  },
  {
    id: 'int.analysis_units',
    title: 'Analysis units',
    purpose: 'Items cut into pieces small enough to reason about.',
    region: 'integrations',
    column: 2,
    order: 2,
    source: 'retrospect-agent/src/pipelines/graph-v2.ts',
    probe: { kind: 'rollup', source: 'analysis_units' },
  },
  {
    id: 'int.tests',
    title: 'Integration self-tests',
    purpose: 'Eight named checks that prove a connector’s whole path still works.',
    region: 'integrations',
    column: 2,
    order: 3,
    source: 'retrospect-agent/src/pipelines/integration-tests.ts:73',
    probe: { kind: 'rollup', source: 'integration_test_runs' },
  },
];
