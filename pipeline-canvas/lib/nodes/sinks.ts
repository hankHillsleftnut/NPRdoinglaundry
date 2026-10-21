import type { NodeSpec } from '../types';

// ---------------------------------------------------------------------------
// SINKS -- where material stops.
//
// Given a bottom band of their own so the board reads simply: anything below
// the main flow is loss. Some of it is loss by design (a claim without a quote
// *should* be dropped), and some is damage (2,000 entries that failed and were
// never retried). The board shows both, because you cannot tell them apart
// until you can see them.
// ---------------------------------------------------------------------------

export const sinkNodes: NodeSpec[] = [
  {
    id: 'sink.failed_raw',
    title: 'Failed content',
    purpose: 'Entries that were accepted but never successfully processed.',
    region: 'sinks',
    column: 0,
    order: 0,
    source: 'raw_content.processing_status = failed',
    probe: {
      kind: 'rollup',
      source: 'raw_content',
      only: ['failed'],
      okStatuses: [],
      failStatuses: ['failed'],
    },
    caveat: 'Nothing retries these. They stay failed until someone intervenes.',
  },
  {
    id: 'sink.dropped_spans',
    isNew: true,
    title: 'Dropped claims',
    purpose: 'Proposed facts thrown away because their quote was not in the source.',
    region: 'sinks',
    column: 1,
    order: 0,
    source: 'retrospect-agent/src/brain/verify-span.ts',
    probe: {
      kind: 'notInstrumented',
      reason: 'Counted during each run, then discarded. The rate is never stored.',
      wouldNeed: 'Persist candidates-vs-kept per run on pipeline_run_traces.',
    },
    caveat: 'This working correctly and this being broken look identical today.',
  },
  {
    id: 'sink.entity_pending',
    isNew: true,
    title: 'Ambiguous names',
    purpose: 'Mentions held back because it is unclear which person they refer to.',
    region: 'sinks',
    column: 1,
    order: 1,
    source: 'retrospect-agent/src/brain/people.ts',
    probe: {
      kind: 'rollup',
      source: 'entity_resolution_candidates',
      only: ['pending'],
      okStatuses: [],
      warnStatuses: ['pending'],
    },
  },
  {
    id: 'sink.retired_facts',
    isNew: true,
    title: 'Retired facts',
    purpose: 'Facts a later, contradicting fact replaced.',
    region: 'sinks',
    column: 2,
    order: 0,
    source: 'retrospect-agent/src/brain/supersession.ts',
    probe: {
      kind: 'rollup',
      source: 'assertions',
      // Retirement is the system working, not damage -- so `retired` is a warn
      // status here, never a failure.
      only: ['retired'],
      okStatuses: [],
      warnStatuses: ['retired'],
      failStatuses: [],
    },
  },
  {
    id: 'sink.retired_patterns',
    isNew: true,
    title: 'Retired patterns',
    purpose: 'Patterns that stopped recurring and were allowed to die.',
    region: 'sinks',
    column: 2,
    order: 1,
    source: 'retrospect-agent/src/brain/promoter.ts',
    probe: {
      kind: 'rollup',
      source: 'behavior_patterns',
      bucket: 'retired',
      only: ['retired'],
      okStatuses: [],
      warnStatuses: ['retired'],
      failStatuses: [],
    },
  },
  {
    id: 'sink.why_refused',
    isNew: true,
    title: 'Refused explanations',
    purpose: 'Times the system declined to explain a pattern it could not justify.',
    region: 'sinks',
    column: 3,
    order: 0,
    source: 'retrospect-agent/src/brain/why.ts',
    probe: {
      kind: 'notInstrumented',
      reason: 'Refusals are silent. The gate holding the line leaves no evidence.',
      wouldNeed: 'Log every refusal with the reason it was refused.',
    },
  },
  {
    id: 'sink.dead_letter',
    title: 'Dead letter',
    purpose: 'Connector jobs that failed too many times to keep retrying.',
    region: 'sinks',
    column: 3,
    order: 1,
    source: 'retrospect-agent/src/services/integration-queue.ts',
    probe: {
      kind: 'rollup',
      source: 'integration_jobs',
      only: ['dead_letter'],
      okStatuses: [],
      failStatuses: ['dead_letter'],
    },
  },
];
