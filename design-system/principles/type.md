# type

## Tracking by size
The bigger the type, the tighter it sits, so a title reads as one dark shape.

| Role | Size | Tracking | Ink (Exposure) |
|---|---|---|---|
| hero | 64+ | −0.04em | −20 |
| title | 28–40 | −0.035em | −20 |
| card headline, quote | 20–24 | −0.02em | −10 |
| body | 15–17 | 0 | — (SF Pro Text) |
| label | 11–13 | +0.01em | — (Geist 500 for buttons and section labels, 400 for meta) |
| figure | 11–15 | 0 | — (SF Mono, tabular: times, counts, prices) |

## The inky display face (your call)
**Exposure** (205TF), already in the app, has an *exposure* axis from −100 to +100. Checked by rendering, 20 Oct: **negative spreads the ink** (heavier, printed on soft paper); **positive thins it** (overexposed, hairline). The comment in `ExposureFont.swift` had this backwards and has been corrected.
- Recommended: −20 for titles and the hero; −10 for card headlines. −30 and beyond reads as poster-bold and is for one hero word at most.
- Exposure is licensed (founder, 21 Oct).
- Hedvig Letters Serif stays the fallback, tracked in the same way (−0.03em at 40).
- A faux "ink bleed" made with a text shadow reads as bold: don't use it. The ink comes from the font, not an effect.

## Everything else
- Lowercase titles and labels; content keeps its capitals.
- Dynamic Type everywhere; titles wrap to three lines, then ellipsis.
- Labels are **Geist** (founder's call, 20 Oct). Mono is kept only for figures that count or tick: times, durations, prices, citation numbers. Hierarchy comes from size and weight (Geist 500 over 400), and from ink (primary → secondary → label), never from switching to mono.
- Never below 11pt.

## Line height of the ink titles (TYPE.leading, 26 Oct)
Paper sets the ink faces at --leading-tight: 1.1 × size, so 33 at --text-3xl, 30.8 at 2xl, 24.2 at xl, 70.4 at the hero. Exposure's own line box is 1.2 × size (ascent 0.95 + descent 0.25, no line gap), and SwiftUI never sets a line shorter than the font's box (`.lineSpacing` only adds). Before this fix every line after the first sat 0.1 × size lower than Paper: 3pt a line at 30, 9pt by the fourth line, and a four-line title stood 12pt taller.
- **The fix lives in one place.** `RTextModifier` (RType.swift) draws any ink style whose Paper leading is tighter than the font (`RTextStyle.drawsAtPaperPitch`) with `RPaperPitch`: line 1 stays where it was, each later line is one Paper pitch below the one before, and `RPaperPitchLayout` reports the shorter height so what sits below moves up with it.
- **No token changed.** --leading-tight, the sizes and every other style are as they were; the leading values were right, the way they were applied wasn't. Every other face (Hedvig, SF, Geist, mono) keeps `.lineSpacing`.
- Dynamic Type: the pitch is leading × the scaled size, so it scales with the text; at accessibility sizes the ax3 leading still caps it. Glyphs are never clipped: the ascender of line 1 stays inside the font's box and the last line's descender stays inside the reported height.
- Line 1 still sits about 1.5pt (half of 36 − 33) below where CSS centres it in Paper's 33 box. CN.connect (#199, open) adds an opt-in `.environment(\.rPaperLineBoxes, true)` that trims that half-leading too; with both, an opted-in title lands on Paper on every line.

Drawn in Paper: f3b · type: tracking and ink.
