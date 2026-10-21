---
name: voice-composer
kind: component
platform: iOS (SwiftUI)
drawn: Paper · 04 · onboarding flow
---

# voice composer

The bar at the bottom of a conversation turn: you answer by talking, and can type at any moment. Voice is on by default; a mute button on the trailing edge turns it into a plain text field.

## Use when
- Onboarding turns (one question per screen) and any Retro conversation where talking is the main way in.

## Don't use when
- A journal entry or a search where typing is the main way in: use the [composer](./composer.md).
- The answer is one of a few choices: offer [chips](./chip.md) or a [segmented](./segmented.md) control above it.

## Anatomy (bottom to top)
Matches the current app's onboarding text-question bar (`VoiceGoalsPage.inputBar`, the "what should I call you?" step), restyled with tokens and made voice-first.
1. **bar**: a pill at rest, 56 tall (a 32 control plus a 12 inset above and below), `radius.composer` (28, concentric with the 32 button at a 12 inset). It grows upward as words wrap; the button stays in the bottom-trailing corner. `background.raised`, a 1pt hairline (`border.subtle`, `voice.listening` while listening), a soft drop shadow (`0 4 8`, `depth.shadow.cast`).
2. **words**: typed words only (text 17 `text.primary`, 20pt from the leading edge). Spoken words appear on the page, not in the bar (see [onboarding question](./onboarding-question.md)); the bar shows its state as the placeholder in `text.tertiary` ("listening…", "retro is speaking…", "type your answer").
3. **level**: five bars before the words while someone is speaking (`voice.listening` or `voice.speaking`); hidden when muted.
4. **corner button**: 32 round (`size.control.small`). While voice is on it is **mute** (`surface.control`, icon `mic-off`); muted, it shows `mic`; with typed words it becomes **send**, lit (`glow.primary` recipe, icon in `glow.primary.foreground`; founder, 20 Oct: "this button needs color").
## Rules
1. **MUST** start listening on its own when it's your turn (unless muted). *Because* the conversation is voice-first; a tap to start would make every turn a chore.
2. **MUST** keep the mute well in the same place in every state. *Because* switching to typing has to be one reliable tap, without looking.
3. **MUST** give a haptic at each hand-over: `listenStart` when it starts listening, `listenStop` when you stop, `turn` when Retro hands back. *Because* in a voice conversation you often aren't looking.
4. **NEVER** cut someone off for a short silence: wait 1.4s of quiet, then show "still listening".
5. **MUST** show your words as you say them. *Because* seeing yourself heard is the proof it's listening; a waveform alone isn't.
6. **NEVER** glow the bar; listening lights only its 1pt hairline in `voice.listening`. *Because* the question is the content of the screen, not the input.

## States
| State | What it looks like | Motion | Haptic |
|---|---|---|---|
| listening (your turn) | ring 1.5pt `voice.listening`; level bars in `voice.listening`; your words stream in | words blur in 5 → 0 per word | `haptic.listenStart` |
| thinking (pending) | bars settle into three dots; words stay | `typing` 900ms | `haptic.listenStop` |
| speaking (Retro) | no ring; bars in `voice.speaking`; placeholder "retro is speaking"; tap anywhere to interrupt | bars only | `haptic.turn` when it ends |
| muted, empty | no bars; placeholder "type your answer"; well shows `mic`; keyboard up | cross-fade 160ms | `haptic.select` |
| muted, typing | text 17/24; send well rises in | `motion.spring.popover` | — |
| pressed (wells) | 0.94 | 80 / 240 | `haptic.press` |
| focused | 2pt `border.focus` ring around the field | — | — |
| disabled (no mic permission) | muted look; state words "type, or allow the mic in settings" | — | — |
| error (didn't catch that) | words cleared; state words "I didn't catch that, try again" | blur-in | `haptic.warning` |
| offline | voice off ("needs a connection to talk"); typing still sends later | — | — |
| empty, loading | listening with no words is the empty state; loading not applicable | — | — |
| dark | field `background.field` dark, inner shade black 30%, hairline white 6% | — | — |

## Accessibility
- [ ] "answer field, listening"; mute "stop listening, type instead"; mic "talk instead"; send "send".
- [ ] Dynamic Type (accessibility 3): words grow and the field grows to 40% of the screen before scrolling.
- [ ] Reduce Motion: words appear without blur; bars become one level meter.
- [ ] Reduce Transparency: no change. Increase Contrast: 1pt `border.control` ring at rest.

## Taken out
- The big 72pt talk button, the separate "type" bubble, the mono state line, and then the 120pt card: the founder pointed at the onboarding text-question bar (20 Oct), so it is that pill, with the corner button doing mute and send.
- No timer while listening: a clock makes people hurry.
- No attach or emoji buttons.

## Edge cases
- Headphones with a mic → same bar; the haptics matter more.
- Phone call while listening → stops, keeps the words, state "paused".
- Over 2 minutes of talking → "still listening" at 1:45, ends at 2:00 keeping what was heard.

## Tokens
`background.field/raised`, `depth.shadow.sunken`, `depth.stroke.inner/outer`, `voice.listening/speaking`, `size.voice.barWidth/barGap`, `size.composer.minHeight/maxHeight`, `surface.wash`, `text.primary/tertiary/label`, `border.focus/control`, `radius.control`, `motion.spring.popover`, `haptic.listenStart/listenStop/turn/select/press/warning`.

> Founder, 20 Oct: "the blue inside the card doesnt feel good." Listening and thinking keep the bar raised white inside; the signal is the 1.5 `voice.listening` hairline, the 4pt `glow.primary.ring` and the soft `glow.primary.halo` outside, plus the blue level bars. No sky wash inside the bar.
> Founder, 20 Oct: "make this whole active listening state more elegant." The hard 4pt `glow.primary.ring` is gone and the hairline is 1pt `voice.listening` (was 1.5). The only glow is a soft `glow.primary.halo` cast below the bar (0 10 28 −10). Thinking uses the same look.
> Founder, 20 Oct (third pass): "the blue to show off that it is listening is good, but I want it to be more elegant." No solid outline: the edge is a fine 0.5pt `glow.primary.ring` and the light is an even `glow.primary.halo` all round (0 0 24 −6), not a shadow dropped below. The level bars are lower and quieter (6/10/14/9/5). Thinking uses the same look.
