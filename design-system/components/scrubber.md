---
name: scrubber
kind: component
platform: iOS (SwiftUI)
drawn: Paper · components · 02 the player · 05 states, dark and access (held)
---

# scrubber

Shows how far through an episode you are, and lets you move through it.

## Use when
- Inside the full [player](./player.md). The mini-player shows a 2pt hairline instead.

## Don't use when
- A value that isn't time (volume, a setting): use the system slider.

## Anatomy (bottom to top)
1. **hit area**: 44pt tall over the whole line.
2. **track**: height 4 (`size.player.scrubber`), radius 2, *sunken*: `surface.track`.
3. **buffered**: same height, `player.buffered`: two steps paler than played, never the accent.
4. **played**: `player.progress` (3.6 : 1 against the track).
5. **chapter ticks**: 2pt gaps cut into the line (`player.chapterMark`). Gaps, not marks, so the line stays one object.
6. **thumb**: 12 round (`size.player.thumb`), white, *raised*: 0.5 white inner edge, 0.5 warm hairline, warm contact `0 1 1.5`, warm cast `0 4 10 −3`.
7. **below**: elapsed (mono 13 `text.label`, tabular) · chapter name (`text.tertiary`) · remaining with a true minus (−07:18).

## Rules
1. **MUST** keep the hit area 44pt tall. *Because* a 4pt line is impossible to grab.
2. **MUST** use tabular mono digits. *Because* proportional digits jitter as they count.
3. **NEVER** colour buffered with the accent. *Because* it would read as played.
4. **SHOULD** show remaining time, not total, on the right.

## States
| State | What changes | Motion | Haptic |
|---|---|---|---|
| rest | as above | none | none |
| pressed (held) | thumb 1.6× (`motion.scale.scrubThumb`), lifts (cast `0 4 10` 16%); a time bubble rises 8pt above: mono 13, `background.inverse` / `text.inverse`, radius 8; the transcript previews that line | `scrubPreview` 120ms | none |
| crossing a chapter | chapter name rolls 6pt | 160ms | `haptic.chapterTick` |
| release | bubble falls and fades; thumb settles | spring 0.3 / 0.8 | none |
| focused | 2pt `border.focus` ring around the thumb | — | — |
| pending (buffering) | buffered edge pulses; the thumb can't pass it | 900ms | none |
| disabled | still-generating audio past the buffered edge; the track there is dashed | — | — |
| error | the line freezes; the player shows the failed state | — | — |
| empty | no audio (transcript-only) → the scrubber is hidden | — | — |
| loading | track only, no played, no thumb | — | — |
| offline | buffered stops where the download ends | — | — |
| dark | track `surface.track` (dark), played `player.progress` (dark, 4.1 : 1), thumb white with black 45% cast | — | — |

## Accessibility
- [ ] Adjustable: "4 minutes 12 seconds of 11 minutes 30"; swipe up/down moves ±15s.
- [ ] Dynamic Type (accessibility 3): times grow and stack under the line (elapsed / remaining on one row, chapter on the next).
- [ ] Increase Contrast: track one step darker; ticks 3pt.
- [ ] Reduce Motion: no bubble rise (it appears); no roll.
- [ ] Reduce Transparency: no change.

## Taken out
- No total time: remaining is the useful number.
- Ticks are gaps, not marks with labels: the chapter name below says which.

## Edge cases
- Under 1 minute → no chapter ticks.
- Dragging off the line vertically → keeps scrubbing (finer as the finger moves further away, like iOS).

## Tokens
`surface.track`, `player.progress/buffered/chapterMark`, `background.raised/inverse`, `text.inverse/label/tertiary`, `border.focus`, `size.player.scrubber/thumb`, `motion.scale.scrubThumb`, `motion.duration.scrubPreview`, `haptic.chapterTick`, `font.family.mono`.
