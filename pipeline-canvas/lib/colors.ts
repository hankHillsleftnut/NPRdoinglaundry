import type { Health, RegionId } from './types';

export const HEALTH_COLOR: Record<Health, string> = {
  ok: 'var(--ok)',
  degraded: 'var(--degraded)',
  failed: 'var(--failed)',
  idle: 'var(--idle)',
  never: 'var(--never)',
  notInstrumented: 'var(--blind)',
  unknown: 'var(--unknown)',
};

/** The sentence a person would say about this state. */
export const HEALTH_LABEL: Record<Health, string> = {
  ok: 'working',
  degraded: 'working, with failures',
  failed: 'failing',
  idle: 'quiet — has run before',
  never: 'never run',
  notInstrumented: 'not recorded',
  unknown: 'cannot tell',
};

export const HEALTH_BLURB: Record<Health, string> = {
  ok: 'Ran recently and nothing failed.',
  degraded: 'Ran, but some of what went through it failed.',
  failed: 'Most of what went through this failed.',
  idle: 'Has history, but nothing inside the current window.',
  never: 'This table has never held a row. The step has not run, ever.',
  notInstrumented: 'Nothing anywhere records this step. Its colour is not a health claim.',
  unknown: 'The read failed, so nothing here is known. Not to be read as healthy.',
};

export const REGION_COLOR: Record<RegionId, string> = {
  capture: 'var(--region-capture)',
  api: 'var(--region-api)',
  integrations: 'var(--region-integrations)',
  ingest: 'var(--region-ingest)',
  brain: 'var(--region-brain)',
  podcast: 'var(--region-podcast)',
  sinks: 'var(--region-sinks)',
};

/** Two or three characters for the zoomed-out mosaic tier. */
export function glyph(title: string): string {
  const words = title.replace(/[^\w\s]/g, ' ').split(/\s+/).filter(Boolean);
  if (words.length === 1) return words[0].slice(0, 2).toUpperCase();
  return words.slice(0, 2).map((w) => w[0].toUpperCase()).join('');
}

// ---------------------------------------------------------------------------
// The path ramp.
//
// When a card is clicked, the chain it sits on is picked out in greys that get
// darker with every hop away from it. Greys rather than a colour because the
// colours on this board already mean something -- health on the dots, region on
// the frames -- and a coloured highlight would compete with the very thing it is
// meant to help you read.
// ---------------------------------------------------------------------------

const PATH_EDGE = ['#ededed', '#b2b2b2', '#8a8a8a', '#686868', '#525252', '#414141'];
const PATH_FILL = ['#2f2f2f', '#292929', '#242424', '#202020', '#1d1d1d', '#1a1a1a'];

export function pathGrey(depth: number): string {
  return PATH_EDGE[Math.min(depth, PATH_EDGE.length - 1)];
}

export function pathFill(depth: number): string {
  return PATH_FILL[Math.min(depth, PATH_FILL.length - 1)];
}

/**
 * The dot's shape class. In a single-hue palette lightness cannot carry seven
 * states on its own, so shape does the disambiguating: a halo for failure, a
 * hollow ring for idle, a dashed ring for "nothing records this".
 */
export const HEALTH_DOT_CLASS: Record<Health, string> = {
  ok: 'h-ok',
  degraded: 'h-degraded',
  failed: 'h-failed',
  idle: 'h-idle',
  never: 'h-never',
  notInstrumented: 'h-blind',
  unknown: 'h-unknown',
};

// ---------------------------------------------------------------------------
// The status badge.
//
// The one place colour is allowed back in, because a pass/fail verdict is
// exactly the thing worth spending an accent on. Green check and red cross are
// reserved for the two states where success or failure is actually KNOWN.
// Everything else gets a neutral mark: a dash for "nothing happened", a query
// for "nothing was measured". Putting a green check on a step no one records
// would be the single most damaging thing this board could do.
// ---------------------------------------------------------------------------

export type BadgeMark = 'check' | 'cross' | 'dash' | 'bang' | 'query';
export type Badge = { mark: BadgeMark; bg: string; fg: string; border?: string };

export const HEALTH_BADGE: Record<Health, Badge> = {
  ok:              { mark: 'check', bg: '#2ea043', fg: '#ffffff' },
  degraded:        { mark: 'bang',  bg: '#c28b1b', fg: '#ffffff' },
  failed:          { mark: 'cross', bg: '#da3633', fg: '#ffffff' },
  idle:            { mark: 'dash',  bg: '#4d4d4d', fg: '#d6d6d6' },
  never:           { mark: 'dash',  bg: '#333333', fg: '#8a8a8a' },
  notInstrumented: { mark: 'query', bg: 'transparent', fg: '#8a8a8a', border: '#575757' },
  unknown:         { mark: 'query', bg: '#8a8a8a', fg: '#1a1a1a' },
};
