---
name: segmented
kind: component
platform: iOS (SwiftUI)
drawn: Paper · components · 01 actions and controls · 05 states, dark and access
---

# segmented

Picks one of two to five options that change what you see: monthly / yearly; week / month.

## Use when
- The options are views of the same thing and switching is instant.

## Don't use when
- More than five options, or they need words to explain: use a sheet.
- The page title can carry the switch (podcasts ⇅): use the [title menu](./title-menu.md).
- It is a setting that persists elsewhere: use a [switch](./switch.md).

## Anatomy (bottom to top)
1. **track**: height 36, radius 18, 3pt padding, *sunken*: `surface.control` with the inner shade (`depth.shadow.sunken`).
2. **thumb**: radius 15 (concentric: 18 − 3), *raised*: `background.raised`, double stroke (`depth.stroke.inner`, `depth.stroke.outer`), warm contact and a small warm cast.
3. **labels**: mono 12 lowercase; selected `text.primary`, others `text.label`; centred on the x-height.
4. **hit area**: each segment is at least 44pt tall (the frame grows; the visual stays 36).

## Rules
1. **MUST** keep labels to one word or a short phrase. *Because* the segments are equal width and long labels squeeze.
2. **NEVER** use for more than five.
3. **MUST** apply the change at once (no "done").
4. **NEVER** use a second colour for the selected segment. *Because* the raised thumb already says "this one"; colour would compete with the lit action.

## States
| State | What changes | Motion | Haptic |
|---|---|---|---|
| rest | as above | none | none |
| pressed | the touched segment's label dims to `opacity.pressed`; if dragging, the thumb follows the finger | thumb follows 1:1 | none |
| selected change | thumb slides; labels cross-fade with a short blur | spring (`motion.spring.sheet` feel, 0.3 / 0.85) | `haptic.select` |
| focused | 2pt `border.focus` ring around the track | none | none |
| disabled | `opacity.disabled`; the reason in text nearby | none | none |
| pending, error, empty, loading, offline | not applicable: it switches views; the view below shows these | — | — |
| dark | track `surface.control` (dark), thumb `background.raised` (dark) with a white 8% inner stroke | — | — |

## Accessibility
- [ ] A tab group: "monthly, selected, 1 of 2".
- [ ] Dynamic Type (accessibility 3): labels grow; if they no longer fit, it becomes a stacked list of rows with checks.
- [ ] Increase Contrast: thumb gets a 1pt `border.control` ring.
- [ ] Reduce Motion: the thumb jumps; labels cross-fade 140ms.
- [ ] Reduce Transparency: no change.
- [ ] Contrast: selected 15 : 1, others 5 : 1 on the track.

## Taken out
- No icons in segments and no colour for the selected one: the raised thumb carries selection.

## Edge cases
- Drag across segments → selects on release where the finger is; haptic on each crossing.
- RTL languages → order reverses; the selected index stays the same option.

## Tokens
`surface.control`, `background.raised`, `depth.shadow.sunken/contact`, `depth.stroke.inner/outer`, `text.primary/label`, `border.focus/control`, `opacity.pressed/disabled`, `motion.spring.sheet`, `haptic.select`, `font.family.mono`.
