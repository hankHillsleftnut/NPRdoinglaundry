---
name: onboarding-question
kind: pattern
platform: iOS (SwiftUI)
drawn: Paper · components · 06 conversation, you and system
---

# onboarding question

One turn of the onboarding conversation: Retrospect asks the question that teaches it the most, you answer by talking, typing or tapping.

## Use when
- Onboarding, after sign-in, until Retrospect knows enough (6–14 turns).

## Don't use when
- Later conversations: those use [message](./message.md) and the [composer](./composer.md) in Journal.

## Anatomy (top to bottom)
1. **the question**: display serif 30/34, inky (`font.exposure.title`), lowercase, at the top third. It is the content.
2. **why it asks**: removed (the one-title rule; no line above or below the question).
3. **quick answers** (when the question has likely ones): up to five pills (36 tall in 44, `surface.wash`, Geist medium), wrap, 8 apart. Tapping one lifts it: `background.raised` with the raised depth stack (inner-top, 0.5 outer stroke, contact, a small cast) and a 14 check from the set before the word in `text.primary` (founder 20 Oct, c-6gtmpz: "this black select state is a bit weird… more subtle"; was solid `ink.default`) and adds its words to the composer, which shows the lit send (muted-typing state). Part 42, 20 Oct.
4. **answer**: the [voice composer](./voice-composer.md) at the bottom: voice on by default, mute on its trailing edge to type.
5. **your words**, live: as you speak they appear on the page under the question, in the inky face at 28 (`font.family.displayInky`, `font.size.2xl`, `font.weight.inkCard`), `text.secondary`. Each new word **blurs in**: blur 4 → 0 and opacity 0 → 1 over 200ms, words staggered as they arrive (`motion.spring.popover` feel); the composer below just says "listening…". *Because* seeing your own words land, softly, is the proof it heard you (founder, 20 Oct: "a nice blur in").

## Rules
1. **MUST** ask one question per screen, as one title. **NEVER** put a subtitle or lead-in line above the title. *Because* the founder wants one thing to read per screen (20 Oct: "no subtitle then title, just one").
2. **MUST** show one global onboarding progress bar under the status bar (3pt, `surface.track` with an `ink.default` fill) that creeps forward each turn and jumps at each stage; **NEVER** a count like "3 of 10". *Because* the founder wants a sense of how far along you are (20 Oct), and the number of turns adapts, so a count would lie.
3. **MUST** allow "skip" (Geist medium 14, `text.secondary`, top trailing, 44 tall; not mono, per the almost-no-mono rule).
4. **MUST** fold privacy and integrations into the conversation as purpose displays, still asking questions.

## States
| State | What it looks like | Motion | Haptic |
|---|---|---|---|
| asking (rest) | question lines blur in one by one | 240ms per line | — |
| listening / thinking / speaking | see [talk button](./talk-button.md) | — | per talk button |
| answered | your answer above; the next question replaces this one, old words blurring out upward | exit 180ms, enter 240ms | `haptic.turn` |
| pressed | per chip / talk button | — | — |
| pending | thinking | — | — |
| error | "I didn't catch that" under the button | — | `haptic.warning` |
| offline | "you're offline · we'll pick up here" | — | — |
| focused | per control | — | — |
| disabled, empty, loading | loading: the first question waits on a blank page with the mark (no spinner under 400ms); disabled, empty: not applicable | — | — |
| dark | canvas dark; question `text.primary` dark | — | — |

## Accessibility
- [ ] The question is a heading and is read first on each turn.
- [ ] Dynamic Type (accessibility 3): the question wraps; chips stack; the button stays in reach.
- [ ] Reduce Motion: questions cross-fade 140ms. Reduce Transparency: no change. Increase Contrast: why line `text.secondary`.

## Taken out
- No step dots and no count. (A quiet back button and a smooth progress bar were added back by the founder, 20 Oct.)
- No illustration: the question is the picture.

## Edge cases
- The person gives a very long answer → kept whole; the next question may follow up on it.

## Tokens
`font.family.display`, `font.exposure.title`, `text.primary/label/secondary`, `background.canvas`, `haptic.turn/warning`.
