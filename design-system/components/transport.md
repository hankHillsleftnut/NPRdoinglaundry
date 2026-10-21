---
name: transport
kind: component
platform: iOS (SwiftUI)
drawn: Paper · components · 02 the player · 05 states, dark and access (playing, paused, buffering, ended, failed, offline)
---

# transport

Play, pause and skip, in one capsule.

## Use when
- The full [player](./player.md).

## Don't use when
- The mini-player and brief card: they carry a single play well.

## Anatomy (bottom to top)
1. **capsule**: height 64, radius 32, *sunken*: `background.sunken` with the inner shade (`depth.shadow.sunken`) and a 0.5 warm hairline. A tray the controls sit in.
2. **skip back / forward**: icon `skip-back-15`, icon `skip-forward-30`, 28pt, `text.secondary`, in 44 frames; the number sits toward the open side of the arrow.
3. **play well**: 48 round, *raised*: `background.raised`, double stroke, warm contact and cast. Concentric: 32 − 8 = 24.
4. **play / pause**: icon `play` (1.5pt right of centre) / icon `pause`, `text.primary`.
5. **outside**: more (icon `more`, 44) on the left; speed (mono 15, tabular, `text.secondary`) on the right.

## Rules
1. **MUST** keep play in the middle and the largest. *Because* 90% of taps are play.
2. **MUST** morph play ↔ pause, never swap.
3. **SHOULD** use 15 back and 30 forward.
4. **NEVER** glow the play. *Because* the player is about listening; the glow is for starting something new.

## States
| State | What it looks like | Motion | Haptic |
|---|---|---|---|
| paused (rest) | play shown | — | — |
| playing | pause shown | `playMorph` | — |
| pressed (play well) | 0.94; the well's cast collapses to contact | 80 / 240 | `haptic.press` |
| pressed (skip) | arrow turns 20° in its direction and back | 160ms | `haptic.skip` |
| pending (buffering) | a 2pt `text.label` ring turns around the play glyph; time holds | `spin` 900ms | — |
| ended | play becomes icon `retry` ("play again"); skip forward disabled | morph | — |
| error (failed) | the well shows icon `retry`; one line above: "couldn't load this episode" | blur-in 220ms | `haptic.error` |
| offline | if downloaded: normal; otherwise skips disabled and the line "offline · download it to listen anywhere" | — | — |
| disabled | a control that can't act (skip forward at the end): `opacity.disabled` | — | — |
| focused | 2pt `border.focus` ring around the focused control | — | — |
| empty, loading | loading: the well shows the buffering ring; empty: not applicable (no audio → no transport) | — | — |
| dark | tray carved, not tinted: the canvas colour (dark) with a deep inner shade at the top (0 3 8 + 0 1 2, `depth.stroke.outer` dark), a 0.5 inner rim, and a 1pt light catch on the bottom lip (`depth.stroke.inner` dark, inside and out). A tray lighter than the canvas reads raised (founder, 20 Oct: "make this recessed feeling better"). Well `background.raised` (dark), inner stroke white 8% | — | — |

## Accessibility
- [ ] "skip back 15 seconds", "play" / "pause", "skip forward 30 seconds", "speed, 1 times".
- [ ] Dynamic Type (accessibility 3): controls keep their size; speed grows and moves under the tray.
- [ ] Reduce Motion: no arrow turn; play/pause cross-fade 140ms.
- [ ] Reduce Transparency: no change.
- [ ] Increase Contrast: tray gets a 1pt `border.control` ring; skip icons `text.primary`.
- [ ] All targets 44pt or more.

## Taken out
- No glow on play; no rewind/fast-forward hold; no shuffle or repeat (an episode isn't a playlist).

## Edge cases
- Brief under a minute → skip forward is 15.
- Speed changes while held → cycles once per tap only.

## Tokens
`background.sunken/raised`, `depth.shadow.sunken/contact/cast`, `depth.stroke.inner/outer`, `text.primary/secondary/label`, `border.focus/control`, `opacity.disabled`, `motion.duration.playMorph/numberTick/spin`, `haptic.press/skip/select/error`, `font.family.mono`.
