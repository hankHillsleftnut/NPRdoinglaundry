---
name: tag
kind: component
platform: iOS (SwiftUI)
drawn: Paper · components · 01 actions and controls · 05 states, dark and access
---

# tag

A short label that describes something and does nothing: "today", "new", "a guess".

## Use when
- Something needs a one-word status beside it (an episode is from today, a brief is new).
- Retrospect is showing a guess, not a fact (the guess tag is required there).

## Don't use when
- Tapping it should do something: use a [chip](./chip.md).
- The status needs a sentence: put the sentence in the row's subline.

## Variants
| Variant | Look | Use |
|---|---|---|
| status | `accent.subtle` fill, `accent.text`, mono 11 | today, new, playing |
| quiet | `surface.wash` fill, `text.label`, mono 11 | 2 min, saved |
| guess | no fill; 1pt *dashed* `inference.border` (dash `size.inference.dash`); a 6pt `inference.marker` dot; mono 11 "a guess" | anything Retrospect inferred |

## Anatomy
- height 22, radius 11 (a true pill); padding 8 (6 on the dot side); the dot sits on the x-height centre of the label.
- *wash* level: no shadow, no stroke (it is part of the surface it sits on, not an object on it).

## Rules
1. **NEVER** make a tag tappable. *Because* if it looks like a chip people tap it and nothing happens.
2. **MUST** mark every inference with the guess tag, dashed *and* labelled. *Because* guesses must never look like facts (goal 11), and the dash plus the word works without colour.
3. **MUST** be lowercase, one or two words.
4. **NEVER** use more than one tag on a line. *Because* a row of labels reads as noise.

## States
A tag has no interactive states: rest only. pressed, focused, pending, disabled: not applicable (never tappable). error, empty, loading, offline: not applicable (it describes its parent; the parent shows those). dark: `accent.subtle` and `inference.*` have dark values; the dashed border stays at 3 : 1.

## Accessibility
- [ ] Read as part of its parent: "the week you kept choosing the river, today". The guess tag reads "a guess".
- [ ] Dynamic Type (accessibility 3): grows with the label; height follows (min 22).
- [ ] Increase Contrast: guess dash 1.5pt; status fill one step deeper.
- [ ] Reduce Motion, Reduce Transparency: nothing moves or blurs; no change.
- [ ] Contrast: status 6.5 : 1, quiet 5.2 : 1, guess label 5.2 : 1.

## Taken out
- No icons except the guess dot. A tag is a word; an icon would make it look tappable.

## Edge cases
- Translation longer than the slot → the tag truncates never; the row gives it room first.
- A guess that the person confirms → the tag is removed (fades 200ms); it never turns into a fact-looking tag.

## Tokens
`accent.subtle/text`, `surface.wash`, `text.label`, `inference.border/marker`, `size.inference.dash`, `font.family.mono`.
