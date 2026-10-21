import type { NodeSpec } from '../types';

// ---------------------------------------------------------------------------
// PODCAST -- understanding becomes something the person actually hears.
//
// Three stages, called cooks, each with its own trace kind. The evidence pack
// and transcript guard are built and merged but not yet called from the podcast
// pipeline, so they appear here as honest grey cards rather than being omitted.
// ---------------------------------------------------------------------------

export const podcastNodes: NodeSpec[] = [
  {
    id: 'pod.context',
    title: 'Load context',
    purpose: 'Gathers what is known about the person before any writing starts.',
    region: 'podcast',
    column: 0,
    order: 0,
    source: 'retrospect-agent/src/pipelines/podcast.ts',
    probe: { kind: 'rollup', source: 'user_understanding' },
    caveat: 'Shares its signal with Portrait — it reads that table rather than recording its own run.',
  },
  {
    id: 'pod.evidence',
    isNew: true,
    title: 'Evidence pack',
    purpose: 'Assembles the citable material an episode is allowed to draw on.',
    region: 'podcast',
    column: 0,
    order: 1,
    source: 'retrospect-agent/src/brain/evidence-pack.ts',
    probe: {
      kind: 'notInstrumented',
      reason: 'Written, tested and merged — but the podcast pipeline never calls it.',
      wouldNeed: 'Wire buildEvidencePack into podcast.ts and record what it produced.',
    },
    caveat: 'Not wired in.',
  },
  {
    id: 'pod.cookA',
    title: 'Cook A — outline',
    purpose: 'Decides what this episode is about.',
    region: 'podcast',
    column: 1,
    order: 0,
    source: 'retrospect-agent/src/pipelines/podcast.ts',
    probe: { kind: 'rollup', source: 'pipeline_run_traces', bucket: 'cookA' },
  },
  {
    id: 'pod.cookB',
    title: 'Cook B — enrich',
    purpose: 'Goes and finds the specifics that make the outline concrete.',
    region: 'podcast',
    column: 1,
    order: 1,
    source: 'retrospect-agent/src/pipelines/podcast.ts',
    probe: { kind: 'rollup', source: 'pipeline_run_traces', bucket: 'cookB' },
  },
  {
    id: 'pod.cookC',
    title: 'Cook C — script',
    purpose: 'Writes the words that will be spoken.',
    region: 'podcast',
    column: 1,
    order: 2,
    source: 'retrospect-agent/src/pipelines/podcast.ts',
    probe: { kind: 'rollup', source: 'pipeline_run_traces', bucket: 'cookC' },
  },
  {
    id: 'pod.guard',
    isNew: true,
    title: 'Transcript guard',
    purpose: 'Checks the script never claims more than the evidence supports.',
    region: 'podcast',
    column: 1,
    order: 3,
    source: 'retrospect-agent/src/brain/transcript-guard.ts',
    probe: {
      kind: 'notInstrumented',
      reason: 'Written, tested and merged — but the podcast pipeline never calls it.',
      wouldNeed: 'Wire guardTranscript into podcast.ts before the script is sent to TTS.',
    },
    caveat: 'Not wired in. Nothing currently checks a script before it is voiced.',
  },
  {
    id: 'pod.run',
    title: 'Podcast run',
    purpose: 'The whole generation attempt, end to end.',
    region: 'podcast',
    column: 2,
    order: 0,
    source: 'retrospect-agent/src/pipelines/podcast.ts',
    probe: { kind: 'rollup', source: 'pipeline_run_traces', bucket: 'podcast' },
  },
  {
    id: 'pod.tts',
    title: 'Text to speech',
    purpose: 'Turns the finished script into audio.',
    region: 'podcast',
    column: 2,
    order: 1,
    source: 'retrospect-agent/src/services/elevenlabs.ts',
    probe: {
      kind: 'notInstrumented',
      reason: 'No record of the synthesis call itself; only the resulting file.',
      wouldNeed: 'Record characters synthesised and outcome on the trace.',
    },
  },
  {
    id: 'pod.episode',
    title: 'Episode',
    purpose: 'The finished thing the person can press play on.',
    region: 'podcast',
    column: 2,
    order: 2,
    source: 'retrospect-agent/src/pipelines/podcast.ts',
    probe: { kind: 'rollup', source: 'podcast_episodes' },
  },
];
