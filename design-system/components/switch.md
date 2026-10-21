---
name: switch
kind: component
platform: iOS (SwiftUI)
drawn: Paper · components · 01 actions and controls · 05 states, dark and access
---

# switch

Turns a setting on or off, at once.

## Use when
- One setting, two states, and the change applies immediately.

## Don't use when
- The change needs confirming or saving: use a [button](./button.md).
- More than two choices: use [segmented](./segmented.md) or a value row.

## Anatomy (bottom to top)
1. **track**: 51 × 31, radius 16, 2pt padding, *sunken*. Off: `surface.track` with the inner shade (`depth.shadow.sunken`) and a 4% hairline. On: `control.switchOn` (the sky glow body, eased) with an inset `0 1 1` black 8% so it still reads as a channel.
2. **thumb**: 27 round (concentric: 16 − 2 ≈ 14), `surface.thumb`, *raised*: `elevation.thumb` (`0 2 5` 10% + `0 1 1` 7%) and an inset `0 −1 0` black 3% underside.
3. **hit area**: the whole row; at least 44 × 51 on its own.

## Rules
1. **MUST** apply immediately; never pair with a save button.
2. **MUST** sit at the trailing edge of a row whose title says what it controls and whose subline says what "on" means.
3. **NEVER** use the switch's colour as the only "on" signal. *Because* the thumb position carries it; Increase Contrast adds the system on/off labels.

## States
| State | What changes | Motion | Haptic |
|---|---|---|---|
| off (rest) / on | as above | thumb on a spring (0.3 / 0.75); track colour cross-fades 200ms | `haptic.select` |
| pressed (held) | thumb stretches to 33 wide toward its travel | follows touch-down | none |
| focused | 2pt `border.focus` ring 2pt outside the track | none | none |
| pending (setting needs the network) | thumb shows a 12pt ring turning; the switch is not interactive | `spin` 900ms | none |
| error | snaps back; the row's subline says why ("couldn't reach calendar") | spring back | `haptic.error` |
| disabled | `opacity.disabled`; the reason in the subline | none | none |
| empty, loading, offline | not applicable alone; offline settings that need the network show disabled with "needs a connection" | — | — |
| dark | off track `surface.track` (dark); thumb white with black 45% shadows | — | — |

## Accessibility
- [ ] "autoplay the next episode, switch, on".
- [ ] Dynamic Type (accessibility 3): the switch keeps its size; the row's text wraps above it.
- [ ] Increase Contrast: off track gets a 1pt `border.control` ring; system on/off labels shown (I / O).
- [ ] Reduce Motion: thumb moves without the spring overshoot.
- [ ] Reduce Transparency: no change.
- [ ] Contrast: off track edge 3.3 : 1 with the ring.

## Taken out
- No on/off text by default (Increase Contrast adds it): the thumb position already says it.
- No icons inside the thumb.

## Edge cases
- Rapid toggling → the last state wins; requests are coalesced.
- A setting that changes elsewhere (e.g. on the web) → the switch animates to the new state when the row appears.

## Tokens
`control.switchOn`, `surface.track/thumb`, `elevation.thumb`, `depth.shadow.sunken`, `border.focus/control`, `opacity.disabled`, `motion.duration.spin`, `haptic.select/error`.
