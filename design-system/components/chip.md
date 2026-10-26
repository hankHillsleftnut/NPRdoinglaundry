---
name: chip
kind: component
platform: iOS (SwiftUI)
drawn: Paper · components · 01 actions and controls (rest, states) · 05 states, dark and access
---

# chip

A small object you can tap: a source ("calendar"), a filter ("this week"), a person ("maya").

## Use when
- The thing is a noun the person might want to open, filter by or fix.
- Several of them sit together in a row that may wrap or scroll.

## Don't use when
- It only describes something and does nothing: use a [tag](./tag.md). A tag never looks tappable; a chip always does.
- It is the next step on the screen: use a [button](./button.md).
- It changes a setting: use a [switch](./switch.md) in a [settings row](./settings-row.md).

## Anatomy (bottom to top)
1. **hit area**: 44pt tall, the 32pt visual centred in it. The frame is padded, never the visual.
2. **cast**: warm `0 2 4 −1` (`depth.shadow.cast`, card tier). **contact**: warm `0 1 1.5` (`depth.shadow.contact`).
3. **outer hairline**: 0.5pt warm (`depth.stroke.outer`).
4. **body**: 32 tall, radius 16 (a true pill), `background.raised`.
5. **inner stroke**: 1pt white 85%, brighter along the top (`depth.stroke.inner`, `depth.stroke.innerTop`). Lit from above.
6. **leading icon well** (optional): 20 round-rect, radius 10 (concentric: 16 − 6 padding), holding a 14pt icon from the set or a source logo.
7. **label**: mono 13, `text.primary`, lowercase; centred on the x-height (nudged down 0.5pt when it has no descenders).
8. **status dot** (sources only): 6pt, 6pt after the label, in `source.connected`, `source.syncing`, `source.problem` or `source.unavailable`, always paired with words in the row's subline (colour is never the only signal).

Padding 6 on the icon side, 12 on the other (asymmetric: the icon's soft edge reads as space).

## Rules
1. **MUST** keep 44pt of hit area. *Because* 32pt chips in a row are otherwise missed and mis-tapped.
2. **MUST** say what it is in words; a logo or dot alone is not enough. *Because* colour and logos fail for many people.
3. **NEVER** put more than one chip in a selected state in a single-choice row. *Because* that is a [segmented](./segmented.md) control's job.
4. **SHOULD** keep labels to one or two words; the full name goes in the accessible label.

## States
| State | What changes | Motion | Haptic |
|---|---|---|---|
| rest | as above | none | none |
| pressed | scale 0.94 (small things press deeper), body to `surface.controlPressed`, cast collapses to contact | in 80ms, out 240ms | none |
| selected (filters) | body `ink.default`, label `text.inverse`, no cast; a check from the set replaces the icon | 200ms cross-fade | `haptic.select` |
| focused | 2pt `border.focus` ring 2pt outside | none | none |
| disabled | `opacity.disabled`, no shadow; the reason is said in the row (e.g. "coming soon") | none | none |
| pending (connecting) | the dot becomes a 6pt ring turning (`spin`) | 900ms loop | none |
| error | dot `source.problem`; label unchanged; the subline says what to do | none | `haptic.warning` once, when it first fails |
| empty, loading, offline | a chip has no data of its own; the row it sits in shows these | — | — |
| dark | body `background.raised` (dark value), inner stroke white 8%, cast black 45% | — | — |

## Accessibility
- [ ] VoiceOver: "calendar, connected, button"; filters add "selected".
- [ ] Dynamic Type (accessibility 3): label grows; the chip grows in height (min 32) and the row wraps rather than truncating.
- [ ] Increase Contrast: the hairline becomes a 1pt `border.control` ring at 100%.
- [ ] Reduce Motion: no scale on press; colour change only.
- [ ] Reduce Transparency: no change (opaque).
- [ ] Contrast: label 15 : 1 on `background.raised`; the 1pt ring with Increase Contrast 3.3 : 1.

## Taken out
- No counts on chips ("calendar · 12"): the number belongs in the source's own sheet.
- The status dot is only for sources; filters and people have none.

## Edge cases
- Long name ("google calendar · work") → ellipsis after 18 characters; full name read aloud.
- Many chips → the row scrolls horizontally with the eased fade at the trailing edge, never a hard cut.
- Double tap → the second tap is ignored while pressed.

## Tokens
`background.raised`, `surface.controlPressed`, `ink.default`, `text.primary/inverse`, `border.focus/control`, `source.connected/syncing/problem/unavailable`, `depth.stroke.inner/innerTop/outer`, `depth.shadow.contact/cast`, `radius.control`, `size.touchTarget`, `motion.duration.pressIn/pressOut/spin`, `opacity.disabled`, `haptic.select/warning`, `font.family.mono`.

## Raised pill: Paper look vs today's look (SH.composer, 26 Oct)
`RPill(style: .raised | .action, look: .current | .paper)`. `.current` (default) is `rSecondary`: SwiftUI shadows with the spreads dropped, and the outer hairline centred. `.paper` is `rSecondaryPaper`: tokens `depth.boxShadow.pill.raised.rest` (Paper c:pill/raised/rest D9Z-0: three strokes, 0 1 1.5 contact, 0 4 6 −2 cast) and `.pressed` (DA6-0: 0 0.5 1, 0 1 2 −1), drawn with `rBoxShadows`. At 4x it is 1.6% of pixels off Paper (today: 14%). The `+ connect` pill on ON-6 is the first user. See `principles/surfaces.md`, "Drawing shadows exactly".
