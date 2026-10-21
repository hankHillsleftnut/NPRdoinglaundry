---
name: guess-card
kind: component
platform: iOS (SwiftUI)
drawn: Paper · components · 06 conversation, you and system
---

# guess card

Something Retrospect thinks about you, shown as a guess you can confirm or correct.

## Use when
- Retrospect has inferred something (a pattern, a goal, a person's role) and wants it checked.

## Don't use when
- It is a fact the person told it: show it plainly, no card.
- More than one at a time: one guess per turn.

## Anatomy (bottom to top)
1. **card**: radius 20, padding 16, `inference.surface`, a 1pt *dashed* `inference.border` (dash `size.inference.dash`), *wash* level: it is not yet a solid object, so it has no shadow. It solidifies only when confirmed.
2. **guess tag**: the [tag](./tag.md) "a guess" at the top left.
3. **the guess**: text 17/24 `text.primary`: "you think best walking, not sitting".
4. **why**: mono 12 `text.label`, "from 9 entries · steps" with icon `guess`; tap → sources.
5. **confidence**: the word only, after the why line ("fairly sure"). Dots beside the word said it twice.
6. **actions**: two *wash* pills, 36 tall in 44 hit areas: "that's right" (icon `check`) · "not quite" (icon `correct`).

## Rules
1. **MUST** look unfinished (dashed, no shadow) until confirmed. *Because* guesses must never look like facts.
2. **MUST** show where it came from.
3. **MUST** accept a correction in the person's words (not quite → the composer opens with "actually…").
4. **NEVER** guess about health, sexuality, religion or money unasked.

## States
| State | What it looks like | Motion | Haptic |
|---|---|---|---|
| rest | as above | arrives with blur-in | — |
| pressed (pill) | pill 0.94 | 80 / 240 | — |
| confirmed | dash becomes solid 0.5 hairline, the card gains card-tier shadows, the tag fades out, "kept" in mono | 320ms (it settles down onto the page) | `haptic.confirm` |
| corrected | the card dims to 55%, strikes nothing; the composer opens | 200ms | `haptic.select` |
| pending | the chosen pill shows the turning ring | `spin` | — |
| error | "couldn't save that · try again" | blur-in | `haptic.error` |
| focused | 2pt `border.focus` | — | — |
| disabled | after an answer, pills disappear (not greyed) | — | — |
| empty, loading | not applicable: a guess card only exists with a guess | — | — |
| offline | answers queue; "saved on this phone" | — | — |
| dark | `inference.surface` dark; dashes at 3 : 1 on dark | — | — |

## Accessibility
- [ ] "a guess: you think best walking, not sitting. fairly sure. from 9 entries and steps." Actions: that's right, not quite.
- [ ] Dynamic Type (accessibility 3): pills stack.
- [ ] Increase Contrast: dash 1.5pt; confidence word `text.primary`.
- [ ] Reduce Motion: confirm without the settle.
- [ ] Reduce Transparency: no change.
- [ ] Contrast: dashed border 3.1 : 1; why line 5.2 : 1.

## Taken out
- Confidence dots: the word says it.
- No shadow until confirmed: weight comes with being true.

## Edge cases
- The person ignores it → after the conversation ends it waits in You as an open guess; never repeated more than twice.

## Tokens
`inference.surface/border/marker`, `size.inference.dash`, `text.primary/label`, `surface.wash`, `depth.shadow.contact/cast`, `status.dangerText`, `border.focus`, `motion.duration.spin`, `haptic.confirm/select/error`, `font.family.text/mono`.
