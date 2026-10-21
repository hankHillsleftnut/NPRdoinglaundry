---
name: goal
kind: component
platform: iOS (SwiftUI)
drawn: Paper · components · 06 conversation, you and system
---

# goal

One goal, showing what you said against what you did.

## Use when
- The Goals tab; a goal mentioned in an episode.

## Don't use when
- A to-do: Retrospect doesn't track tasks.

## Anatomy
- **row card**: radius 20, padding 18, *card* tier.
- **title**: text 17 semibold, the person's words, lowercase only if they wrote it so.
- **said vs did**: two bars on one 4pt track pair: said (`goal.said`, how often you mentioned it) above, did (`goal.did`, evidence it happened) below; labelled "said" and "did" in mono 11 before each bar, the count after it ("6 times", "2"). The words and the bars are one line each, not a bar plus a sentence repeating it.
- **one line** from Retrospect, text 15 `text.secondary`: "you talk about running most on sundays."

## Rules
1. **MUST** show both said and did with words. *Because* the gap is the insight and colour alone fails.
2. **NEVER** shame: no red, no streaks, no "failed".
3. **MUST** let the person end a goal (quitting is a choice, not a failure).

## States
| State | What it looks like | Motion | Haptic |
|---|---|---|---|
| rest | as above | bars fill once on first view | — |
| pressed | card 0.98 | 80 / 240 | — |
| focused | 2pt `border.focus` | — | — |
| guess (a goal Retrospect inferred) | dashed like a [guess card](./guess-card.md) until confirmed | — | — |
| empty (no evidence yet) | bars hidden; "nothing to compare yet" | — | — |
| loading | skeleton bars | shimmer | — |
| ended | moves to "ended" at the bottom, `text.secondary`, no bars | 280ms | `haptic.confirm` |
| pending, error, offline | ending a goal: pending ring; error line; offline queues | — | — |
| disabled | not applicable | — | — |
| dark | goal tokens' dark values | — | — |

## Accessibility
- [ ] "run twice a week. said 6 times, did 2. you talk about running most on sundays."
- [ ] Dynamic Type (accessibility 3): bars go full width under the text.
- [ ] Reduce Motion: bars appear filled. Reduce Transparency: no change. Increase Contrast: bar tracks get a 1pt ring.

## Taken out
- No percentage, no ring chart: two bars and two numbers say it.
- No streaks or calendars: they turn reflection into scorekeeping.
- No summary line under the bars ("said 6 · did 2"): the counts sit at the bar ends.

## Edge cases
- Did exceeds said → fine; the line notices it ("you do this more than you mention it").

## Tokens
`goal.said/did`, `size.goal.ring/ringStroke`, `text.primary/secondary/label`, `border.focus`, `background.raised`, `depth.shadow.contact/cast`, `haptic.confirm`.
