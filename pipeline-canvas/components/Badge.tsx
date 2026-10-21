'use client';

import type { Health } from '@/lib/types';
import { HEALTH_BADGE, type BadgeMark } from '@/lib/colors';

// Drawn as SVG rather than typed as text. The obvious characters for these
// marks -- U+2715, U+2713, U+2013 -- carry their own font metrics, so they sit
// off-centre in a circle and render at whatever weight the face decides. Paths
// are centred by construction and keep the same weight at every badge size.

function Mark({ mark }: { mark: BadgeMark }) {
  const common = {
    fill: 'none',
    stroke: 'currentColor',
    strokeWidth: 2.1,
    strokeLinecap: 'round' as const,
    strokeLinejoin: 'round' as const,
  };

  return (
    <svg viewBox="0 0 16 16" width="100%" height="100%" aria-hidden>
      {mark === 'check' && <path d="M4.6 8.3 L6.9 10.7 L11.4 5.4" {...common} />}
      {mark === 'cross' && (
        <>
          <path d="M5.2 5.2 L10.8 10.8" {...common} />
          <path d="M10.8 5.2 L5.2 10.8" {...common} />
        </>
      )}
      {mark === 'dash' && <path d="M4.6 8 L11.4 8" {...common} />}
      {mark === 'bang' && (
        <>
          <path d="M8 4.2 L8 9" {...common} />
          <path d="M8 11.6 L8 11.6" {...common} strokeWidth={2.4} />
        </>
      )}
      {mark === 'query' && (
        <>
          <path d="M5.9 6.1 A2.15 2.15 0 1 1 8 9.1 L8 10" {...common} strokeWidth={1.9} />
          <path d="M8 12.2 L8 12.2" {...common} strokeWidth={2.2} />
        </>
      )}
    </svg>
  );
}

/** The pass/fail mark. One component so the card, the legend and the drawer can
 *  never drift apart on what a given state looks like. */
export function Badge({ health, className = '' }: { health: Health; className?: string }) {
  const b = HEALTH_BADGE[health];
  return (
    <span
      className={`badge ${b.border ? 'dashed' : ''} ${className}`}
      style={{ background: b.bg, color: b.fg, borderColor: b.border }}
      aria-hidden
    >
      <Mark mark={b.mark} />
    </span>
  );
}
