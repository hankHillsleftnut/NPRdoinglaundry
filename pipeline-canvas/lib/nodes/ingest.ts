import type { NodeSpec } from '../types';

// ---------------------------------------------------------------------------
// INGEST -- raw material becomes verified facts.
//
// The best-instrumented region, and the one that matters most: this is where
// the product's central promise lives. Nothing becomes a fact unless the exact
// words backing it can be pointed at in the source.
// ---------------------------------------------------------------------------

export const ingestNodes: NodeSpec[] = [
  {
    id: 'ing.raw',
    title: 'Raw content',
    purpose: 'Everything the system has ever been given, kept unchanged forever.',
    region: 'ingest',
    column: 0,
    order: 0,
    source: 'retrospect-agent/src/pipelines/ingest.ts',
    probe: { kind: 'rollup', source: 'raw_content' },
  },
  {
    id: 'ing.lease',
    isNew: true,
    title: 'Lease and claim',
    purpose: 'Stops two workers processing the same entry at once.',
    region: 'ingest',
    column: 0,
    order: 1,
    source: 'retrospect-agent/src/brain/lease.ts',
    probe: {
      kind: 'rollup',
      source: 'raw_content',
      failStatuses: ['failed'],
      warnStatuses: ['processing', 'pending'],
    },
    caveat: 'Inferred from raw_content, not measured. Leasing itself is not logged.',
  },
  {
    id: 'ing.run',
    title: 'Ingestion run',
    purpose: 'One pass over a batch of new material.',
    region: 'ingest',
    column: 0,
    order: 2,
    source: 'retrospect-agent/src/pipelines/ingest.ts',
    probe: { kind: 'rollup', source: 'pipeline_run_traces', bucket: 'ingest' },
  },
  {
    id: 'ing.extract',
    isNew: true,
    title: 'Claim extraction',
    purpose: 'The model proposes candidate facts, each with the quote it came from.',
    region: 'ingest',
    column: 1,
    order: 0,
    source: 'retrospect-agent/src/agents/ingestion-agent.ts',
    probe: {
      kind: 'notInstrumented',
      reason: 'Candidates proposed are not counted separately from facts written.',
      wouldNeed: 'Persist candidate count per run so the drop rate becomes visible.',
    },
    caveat: 'Long-form input is capped at 16k characters.',
  },
  {
    id: 'ing.verify',
    isNew: true,
    title: 'Span verification',
    purpose: 'Throws away any claim whose quote cannot be found in the original text.',
    region: 'ingest',
    column: 1,
    order: 1,
    source: 'retrospect-agent/src/brain/verify-span.ts',
    probe: {
      kind: 'notInstrumented',
      reason: 'The drop rate is computed during a run, reported, and never stored.',
      wouldNeed: 'A setStageCounts() on Trace writing candidates vs kept into the trace row.',
    },
    caveat: 'The single most important gate in the product, and it is invisible.',
  },
  {
    id: 'ing.entity',
    isNew: true,
    title: 'Entity resolution',
    purpose: 'Decides whether two mentions of a name are the same person.',
    region: 'ingest',
    column: 1,
    order: 2,
    source: 'retrospect-agent/src/brain/people.ts',
    probe: { kind: 'rollup', source: 'entities' },
  },
  {
    id: 'ing.fact',
    isNew: true,
    title: 'Fact write',
    purpose: 'Stores a verified assertion, keyed so the same entry cannot write it twice.',
    region: 'ingest',
    column: 2,
    order: 0,
    source: 'retrospect-agent/src/brain/write-journal-facts.ts',
    probe: {
      kind: 'rollup',
      source: 'assertions',
      failStatuses: [],
      warnStatuses: ['retired'],
    },
  },
  {
    id: 'ing.evidence',
    isNew: true,
    title: 'Evidence link',
    purpose: 'Ties each fact to the exact character range that proves it.',
    region: 'ingest',
    column: 2,
    order: 1,
    source: 'retrospect-agent/src/pipelines/graph-v2.ts',
    probe: { kind: 'rollup', source: 'assertion_evidence' },
  },
  {
    id: 'ing.supersede',
    isNew: true,
    title: 'Supersession',
    purpose: 'Retires a fact when a newer one contradicts it, by rule rather than by model.',
    region: 'ingest',
    column: 2,
    order: 2,
    source: 'retrospect-agent/src/brain/supersession.ts',
    probe: {
      kind: 'rollup',
      source: 'assertions',
      // Counts RETIREMENTS, not assertions. It previously counted every
      // assertion in the table, which showed a green check for a step that has
      // never actually retired anything -- the board asserting success for work
      // that never happened.
      only: ['retired'],
      failStatuses: [],
      warnStatuses: ['retired'],
    },
    caveat: 'Has never retired a fact. Nothing has contradicted anything yet.',
  },
  {
    id: 'ing.shim',
    isLegacy: true,
    title: 'Observations and insights',
    purpose: 'The older representation, still written so existing features keep working.',
    region: 'ingest',
    column: 2,
    order: 3,
    source: 'retrospect-agent/src/pipelines/graph-v2.ts',
    probe: { kind: 'rollup', source: 'observations' },
  },
];
