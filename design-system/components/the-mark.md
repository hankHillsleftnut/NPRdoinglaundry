---
name: the mark
kind: component
platform: iOS (SwiftUI)
drawn: Paper · components · 01 actions and controls · 02 the player (header, 22pt)
---

# the mark

Retrospect's sign, lifted on a small cream disc. It says "this is Retrospect speaking".

## Use when
- Something is from Retrospect itself: the player header, the paywall, the widget. Not beside its messages in the conversation (founder, 20 Oct: "not needed").

## Don't use when
- You need a button: the mark never does anything.
- Decoration: never more than one on a screen.

## Sizes
| Size | Where | Shadows |
|---|---|---|
| 38 | paywall, onboarding welcome | `0 6 7` 24% + `0 1 2` 12% (`elevation.mark`) |
| 22 | player header | `0 2 3` + `0 0.5 1` |
| 16 | widget corner | contact only |

## Anatomy (bottom to top)
1. two warm shadows (above).
2. **disc**: round, `surface.secondaryAction` (cream).
3. **ring**: 1pt `border.secondaryRing` at 75%, outside a 1pt white inner border (the double stroke, *raised* tier).
4. **grain**: `material.grain.signature` (seed 7, 6%).
5. **glyph**: `icon.mark` at 35%, inset 9 at 38 (scales with size); centred by mass, not by box.

## Rules
1. **NEVER** use it as a button. *Because* it marks where you are; a tappable logo surprises.
2. **MUST** keep one per screen.
3. **NEVER** recolour it per screen. *Because* it is the one constant.

## States
rest only. pressed, focused, pending, disabled, error: not applicable (never interactive). empty, loading, offline: not applicable. dark: the disc takes the dark `surface.secondaryAction`, shadows black 45%, grain stays.

## Accessibility
- [ ] Decorative: hidden from VoiceOver (`accessibilityHidden`) where a title already says "retrospect"; otherwise "retrospect".
- [ ] Dynamic Type (accessibility 3): fixed size; it is a sign, not text.
- [ ] Increase Contrast: glyph to 60%.
- [ ] Reduce Motion: it never moves. Reduce Transparency: no change.

## Taken out
- No animation and no state: a sign that moves draws the eye from the content.

## Edge cases
- On a dark photo or artwork → never placed there; it sits on a surface.

## Tokens
`surface.secondaryAction`, `border.secondaryRing`, `elevation.mark`, `icon.mark`, `material.grain.signature`, `size.mark`.
