'use client';

// The corner mark: "n" for the second-brain machinery, "o" for what it
// supersedes.
//
// Drawn as SVG for the same reason as the status marks. Flex-centring a letter
// centres its LINE BOX, not the letter itself, and a lowercase glyph occupies
// only the x-height slice of that box -- so it renders visibly off-centre. In
// SVG the `y` coordinate IS the baseline, so the ink can be placed exactly.
//
// Measured for this font at weight 700: ink ascent 0.549em, descent 0.011em, so
// the ink's centre sits 0.269em above the baseline. To put that centre on the
// box centre (8 of 16), the baseline goes at 8 + 0.269 * 11 = 10.96.
const FONT_SIZE = 11;
const BASELINE = 10.96;

export function CornerTag({ letter, kind }: { letter: 'n' | 'o'; kind: 'new' | 'old' }) {
  return (
    <span className={kind === 'new' ? 'chip-new' : 'chip-old'} aria-hidden>
      <svg viewBox="0 0 16 16" width="100%" height="100%">
        <text
          x="8"
          y={BASELINE}
          textAnchor="middle"
          fontSize={FONT_SIZE}
          fontWeight={700}
          fill="currentColor"
          fontFamily="var(--font)"
        >
          {letter}
        </text>
      </svg>
    </span>
  );
}
