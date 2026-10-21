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

Drawn in Paper: f3b · type: tracking and ink.
