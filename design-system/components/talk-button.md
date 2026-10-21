---
name: talk-button
kind: component
platform: iOS (SwiftUI)
drawn: Paper · components · 01 actions and controls (talk row) · 05 states, dark and access
---

# talk button

Talk to Retrospect: in onboarding, in Journal, anywhere it asks a question.

## Use when
- It is the person's turn in a spoken conversation.

## Don't use when
- Recording a voice note with no reply: use the journal's record control.
- Somewhere a primary [button](./button.md) is already lit: one lit object per screen.

## Anatomy
- **body**: 72 round (`size.voice.button`), the primary glow stack: eased OKLCH body (`gradient.glowPrimary`), lower edge, inner bloom, 2pt ring, halo 16, its own sky cast (`depth.tint.primary`), grain (`material.grain.primary`).
- **glyph**: icon `mic`, 28pt, white, centred by mass (the capsule, not the stand).
- **typing alternative**: beside it, a 44 *wash* bubble with icon `keyboard` and the word "type" under it in mono 11.
- **hit area**: 88 round.

## Rules
1. **MUST** give a haptic at each turn: `listenStart`, `listenStop`, and `turn` when it hands back. *Because* in a voice conversation you often aren't looking.
2. **MUST** always offer typing beside it. *Because* not everyone can or wants to speak right now.
3. **NEVER** cut someone off for a short silence: wait 1.4s of quiet, then show "still listening".
4. **MUST** show the state in words under it ("your turn", "listening", "thinking", "speaking"). *Because* the glow alone does not say whose turn it is.

## States
| State | What it looks like | Motion | Haptic |
|---|---|---|---|
| rest (your turn) | as above | none | none |
| pressed | 0.94, pressed gradient | 80 in / 240 out | `haptic.press` |
| listening | lit gradient; five white bars (3 wide, 2 apart, up to 32) follow your voice; one 88pt 1pt ring at 25% breathes out | `voicePulse` 1200ms | `haptic.listenStart` |
| thinking (pending) | bars settle into three dots; halo at half | `typing` 900ms | `haptic.listenStop` |
| speaking | the body turns ink (`voice.speaking`), no glow; the bars follow *its* voice; tap to interrupt | bars only | `haptic.turn` when it ends |
| focused | 2pt `border.focus` ring 4pt outside the halo | none | none |
| disabled (no mic permission) | `surface.control`, icon `mic-off` in `text.label`; "type instead · allow the mic in settings" under it | none | none |
| error (didn't catch that) | returns to rest; under it: "I didn't catch that, try again" | 200ms | `haptic.warning` |
| offline | disabled look; "needs a connection to talk; you can still type" | none | none |
| empty, loading | not applicable (the conversation shows its own loading) | — | — |
| dark | glow tokens' dark values; speaking uses the dark ink (lighter); bars stay white | — | — |

## Accessibility
- [ ] "talk" / "stop listening" / "interrupt"; announces "listening" and "your turn".
- [ ] Dynamic Type (accessibility 3): the button keeps 72; the words under it grow and wrap.
- [ ] Reduce Motion: the rings don't breathe; the bars become one level meter.
- [ ] Reduce Transparency: no change (no wash to remove).
- [ ] Increase Contrast: speaking-state ring at 100%; state words in `text.primary`.
- [ ] Contrast: the white glyph on sky is the same open decision as the lit label (see [button](./button.md)).

## Taken out
- Listening had two breathing rings and a wash: now one ring. The moving bars already say "I hear you".
- No timer while listening: a clock makes people hurry.

## Edge cases
- Headphones with a mic → still the same button; the haptics matter more.
- Phone call during listening → stops, keeps what was heard, shows "paused".
- Very long answer (over 2 minutes) → "still listening" at 1:45, ends at 2:00 with what was heard kept.

## Tokens
`glow.primary.*`, `gradient.glowPrimary`, `depth.tint.primary`, `material.grain.primary`, `voice.listening/speaking/waveIdle`, `size.voice.button/barWidth/barGap/barMax`, `surface.wash/control`, `text.label/primary`, `border.focus`, `motion.duration.voicePulse/typing`, `haptic.press/listenStart/listenStop/turn/warning`.
