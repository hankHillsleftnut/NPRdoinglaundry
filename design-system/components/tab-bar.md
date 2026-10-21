---
name: tab-bar
kind: component
platform: iOS (SwiftUI)
drawn: Paper · components · 03 player pieces · 05 states, dark and access
---

# tab bar

The four places: journal · podcasts · goals · you.

## Use when
- Always at the root of the app, once onboarding is done.

## Don't use when
- Onboarding, the paywall, the full player or any sheet: they cover it.
- For actions ("new entry"): actions live on the page.

## Anatomy
- **bar**: 49 + the home-indicator inset (`size.tabBar`); no plate and no line. Under it, a **progressive blur** that starts 90pt above the tabs and ramps 0.5 → 8pt, under a canvas tint, so content dissolves before it can crowd the labels (founder, 20 Oct: "it should never obstruct the options"). Built as one layer: a single backdrop blur (10pt) whose strength is graded by a gradient mask, plus the canvas tint. No stacked bands; they show seams (founder: "make sure it's the real deal"). SwiftUI: a variable blur (iOS 26 soft scroll edge; on iOS 18, the content blurred once and masked in). Paper can't mask a backdrop blur, so the board draws the same result with the thread twice: sharp and masked out, blurred 6 and masked in. The floating-pill versions were drawn and archived (02b · archive).
- **items**: four equal slots of 72; each a 22pt icon from the set (icon `journal`, icon `podcasts`, icon `goals`, icon `you`) over a Geist 11 lowercase label, 2pt apart; the pair centred by mass in its slot.
- **selected**: icon at `icon.weightEmphasis` (2.2) and label Geist 500 in `text.primary`. **others**: the shipped 1.75 outline in `icon.muted`, label Geist 400 `text.label`. The icons ship as single outlines, so the 2.2 emphasis is the outline grown 0.225 on each side (ink joins grow with it); export both weights per tab icon.
- **mini-player** floats 12pt above it, never inside it.

## Rules
1. **MUST** stay four tabs. *Because* one feature per page; a fifth tab means a feature hasn't found its home.
2. **NEVER** put a badge count on a tab. *Because* counts nag; if something waits for you, its page says so.
3. **MUST** change weight, not colour, to show selection. *Because* the accent is reserved for the one lit action.
4. **MUST** scroll the page to the top when its selected tab is tapped again.

## States
| State | What changes | Motion | Haptic |
|---|---|---|---|
| rest / selected | weights as above | none | none |
| pressed | icon and label dim to `opacity.pressed` | instant, back 240ms | none |
| change | old weight down, new weight up; the page cross-fades | 140ms | `haptic.tab` |
| focused | 2pt `border.focus` ring around the slot | none | none |
| disabled, pending, error, empty, loading | not applicable: tabs always lead somewhere; the page shows its own states | — | — |
| offline | no change to the bar; pages say what is unavailable | — | — |
| dark | `material.bar` dark; selected `text.primary` (dark); others 3.3 : 1 | — | — |

## Accessibility
- [ ] "journal, tab, 1 of 4, selected".
- [ ] Dynamic Type (accessibility 3): labels hide and a long press shows the large-content viewer (iOS behaviour); icons stay 22.
- [ ] Increase Contrast: inactive icons to `text.secondary`.
- [ ] Reduce Transparency: `material.reducedTransparency` (solid).
- [ ] Reduce Motion: weight change without the cross-fade.
- [ ] Contrast: inactive icon 3.3 : 1; inactive label 5.2 : 1.

## Taken out
- No badges and no colour selection: weight alone shows where you are.
- Labels kept: four icons alone are ambiguous (goals vs you), so the word is not repetition here.

## Edge cases
- Small phone (SE) → slots shrink to fit; never fewer than 64 wide.
- Something playing → mini-player sits above; content insets by both.

## Tokens
`material.bar`, `material.reducedTransparency`, `border.subtle/focus`, `text.primary/label/secondary`, `icon.muted`, `icon.weight/weightEmphasis`, `size.tabBar`, `opacity.pressed`, `haptic.tab`, `font.family.label`.
