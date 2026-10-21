---
name: button
kind: component
platform: iOS (SwiftUI)
drawn: Paper · components · 01 actions and controls
---

# button

Starts an action: subscribe, continue, send, delete.

## Use when
- The screen has one next step that should be found in a second (primary).
- There is a real alternative to it (secondary, the cream button).
- Something will be destroyed, inside a confirmation (destructive).

## Don't use when
- It turns a setting on or off at once: use [switch](./switch.md).
- It picks one of two to five views: use [segmented](./segmented.md).
- It moves to another screen as navigation: use a row with a chevron, or a link.

## Variants
| Variant | Size | Use |
|---|---|---|
| primary | 345 × 60, radius 29 (`size.control.hero`) | the one next step on the screen |
| primary compact | height 48, radius 24, optional trailing icon | the next step inside a card or a teaser |
| secondary | 345 × 60, cream | the real alternative (yearly plan, not now) |
| destructive | 345 × 60 | only on the confirming button inside a dialog |
| bubble | 44 round (`size.control.default`) | an icon action: share, like, more |
| link | text only, SF Pro body medium, `text.link`, 44pt hit area | restore, privacy, terms, not now, later |

## Anatomy: primary (bottom to top)
1. **cast**: `0 10 18 −6` in `depth.tint.primary` (its own sky, not grey). Lifts it off the page.
2. **contact**: `0 2 2` black 22%. Seats it.
3. **halo**: `0 0 16` `glow.primary.halo`. The sky light around it.
4. **outer ring**: 2pt outside, `glow.primary.ring`. Separates it from the page.
5. **body**: `gradient.glowPrimary`, five OKLCH-eased stops.
6. **inner bloom**: inset `0 0 12` `glow.primary.bloom`. Light inside the body.
7. **lower edge**: three insets `0 -0.5 1`, `0 -1 2`, `0 -1.5 3` in `glow.primary.edge`. The rounded underside.
8. **inner hairline**: inset 1pt white 10%.
9. **top rim**: inset `0 1 0` white 50%, masked to fade downward.
10. **grain**: noise, seed 19, size 0.5, intensity `material.grain.primary` (20%), soft light. Invisible alone, but it stops the gradient banding.
11. **label**: SF Pro body semibold (`RType.buttonLabel`), `glow.primary.foreground`, text shadow `0 1 1` black 20%. (Was mono 14; changed to match the approved boards and the founder's rule that mono is only for figures, 20 Oct.)
12. **lit layer** (hidden at rest): highlight gradients (top 38% white to 0 by 48%; a radial at 22% 0; a radial from below), the lit gradient, and lit edges and bloom. Fades in over `motion.duration.litFade` when focused.

Secondary: cream body (`surface.secondaryAction`), 1pt white inner border with a brighter top, 2pt `border.secondaryRing` outside plus a 0.5pt warm hairline, warm contact `0 1 1.5` and warm cast `0 4 6 −2`, grain seed 239 at 4.5%, SF Pro body medium label in `text.primary` (approved ON-12 plan buttons). Destructive: the primary stack in the danger glow set, casting its own red (`depth.tint.danger`).

## Rules
1. **MUST** use one primary per screen. *Because* two lit buttons leave the person guessing which one is the next step.
2. **NEVER** put the glow on anything but primary and destructive. *Because* the glow means "this is next"; a glowing share competes with continue.
3. **MUST** keep the label while pending; show the dots over it and keep the width. *Because* a new label changes the width and what VoiceOver reads mid-press.
4. **MUST** use destructive only on the confirming button in a dialog; the trigger is a bubble or a row. *Because* red before anything is at stake alarms and takes weight from the real moment.
5. **MUST** say why a button is disabled, in text beside it. *Because* a dead button with no reason reads as broken.
6. **SHOULD** label with a verb and its object, lowercase: "continue", "delete everything", "$4.99 a month".
7. **SHOULD** put a price in the label only on the paywall; elsewhere, beside it.
8. **NEVER** set a fill, height or radius by hand on a call site. *Because* it skips the states, the dark values and the checked contrast.

## States
| State | What changes | Motion | Haptic |
|---|---|---|---|
| rest | the full stack | none | none |
| pressed | body takes the pressed gradient; lit layer off; halo to 10, cast to `0 2 3` | scale 0.98 in 80ms, back in 240ms (spring) | `haptic.press` on touch down |
| focused | lit layer on; 2pt `border.focus` outline 4pt outside | lit fade 200ms | none |
| pending | dots over the kept label, presses blocked | dots pulse 900ms | none |
| disabled | no glow at all: control fill, 1pt white 70% inner edge, `text.disabled` label | none | none |
| error | returns to rest; the reason appears in one line under it in `status.dangerText` ("couldn't reach the app store, try again") | 200ms blur-in of the line | `haptic.error` |
| offline | disabled look; the line under it says "needs a connection" | none | none |
| empty, loading | not applicable: a button with nothing to do is not shown; the screen shows its own loading | — | — |
| dark | every glow token's dark value; the cast deepens to black 45%; secondary takes the dark cream | — | — |

## Accessibility
- [ ] The whole 60pt height is the hit area; never less than 44.
- [ ] VoiceOver: the label as written; pending adds "busy"; disabled reads the reason after.
- [ ] Dynamic Type (to accessibility 3): the label grows; the height stays 60 and the label ends in an ellipsis rather than wrapping.
- [ ] Increase Contrast: ring at 100%, label white without shadow.
- [ ] Reduce Motion: no scale; the lit layer switches without a fade.
- [ ] Reduce Transparency: no change (it is opaque).
- [ ] White on every glow stop passes 4.5:1 in light and dark (check when the sky is tuned).

## Sign-in buttons (founder, 20 Oct)
- **Apple:** Apple's standard black button (white in dark mode), radius 27 (a true pill at 54), SF Pro Text medium 17.
- **Google:** white, raised: a 0.5 warm hairline, a warm contact and soft cast; never Google's dark grey stroke (the founder disliked dark borders). Dark mode: Google's dark style (#131314) with a 1pt `border.subtle`.
- Stacked, 12 apart, at the bottom of the splash; a one-line terms · privacy link under them in mono 11.

## Taken out
- No icons on the hero buttons and no arrows ("continue →"): the glow already says "next".
- The lit layer appears only on focus, not at rest: one level of light is enough to be found.
- No subtitle inside a button: a price or reason goes beside it.

## Edge cases
- Long label → never wraps; ellipsis; the full label is the accessible name.
- Double tap → pending blocks the second.
- Slow purchase → pending stays; after 20s a line under it says it's still working.
- Small phone (SE) → width is the screen minus 2 × `space.screenMargin`, never fixed at 345.
- Dark → every glow token has a dark value; the cast deepens to black 45%.

## Tokens
`glow.primary.*`, `glow.danger.*`, `surface.secondaryAction`, `border.secondaryRing`, `surface.control`, `text.disabled`, `text.label`, `border.focus`, `size.control.hero`, `radius.control`, `font.family.mono`, `motion.scale.press`, `motion.duration.pressIn/pressOut/litFade`, `haptic.press`, `material.grain.*`.

## Surface and contrast (20 Oct pass)
- **Surface level:** primary, compact and destructive are *lit* (level 5); secondary is *raised* (2); bubbles are *wash* (0.5): a translucent `surface.wash` tint, no shadow; links are *page* (0).
- **Bubble icons** come from the icon set (`design-system/icons`), 20pt, stroke 1.75, centred by mass.
- **Contrast:** secondary label 5 : 1; links 6.2 : 1; the lit label is **open** (white on sky 2.6 : 1 fails AA): option b (deeper sky, 4.9 : 1) or c (deep-sky ink label, 7 : 1, recommended).
- **Dark, Increase Contrast and largest text** are drawn in Paper, c5 and c6.
