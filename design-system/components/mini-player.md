---
name: mini-player
kind: component
platform: iOS (SwiftUI)
drawn: Paper · components · 03 player pieces (rest) · 05 states, dark and access (pressed, buffering, failed, dark)
---

# mini-player

Keeps what's playing within reach while you use the rest of the app.

## Use when
- Something is loaded (playing or paused) and the full [player](./player.md) is closed.

## Don't use when
- Onboarding, the full player, the paywall (it has its own small variant below), any full-screen sheet.

## Variants
- **floating** (the app): screen width − 2 × screen margin (354 on 402) × 64, radius.control, floats 12pt above the tab bar (part 45, 20 Oct: sits on the 24 margins).
- **paywall** (as built today): 286 × 42, radius 20, `#F9F7F5`, 0.5 white inner border, `0 1 4` black 12%; elapsed in mono 14, a 150-wide 3pt scrubber, play. Kept; it is where the paywall reveals from.

## Anatomy (floating, bottom to top)
1. **soft edge above the tab bar**: content scrolling under it passes through a progressive blur (0 → 1.5pt) and the eased fade (`gradient.fadeToCanvas`). On iOS 26 via `safeAreaBar`.
2. **shadows**: *floating* tier: a wide warm `0 10 30 −10` 30%, a mid `0 4 10 −4`, and a contact `0 1 1.5` (`depth.shadow.ambient/cast/contact`).
3. **body**: `background.raised` at 92% over `material.bar`; 0.5 warm hairline outside, 1pt white inner stroke brighter on top.
4. **artwork**: 44, radius 22 (concentric: 32 − 10), mesh (`gradient.meshMorning` etc.) with grain, casting its own colour (`depth.tint.artwork`).
5. **title**: text 14 semibold, one line, ellipsis; **subline**: Geist 12 `text.label` "chapter 2 · the standup · 8 min left" (not mono: the almost-no-mono rule).
6. **play well**: 44, *wash* (`surface.wash`), icon `play` / `pause`.
7. **progress hairline**: 2pt along the bottom inside edge, `player.progress`, clipped by the radius.

## Rules
1. **MUST** open the full player on tap, with the title morphing into the sheet's title.
2. **MUST** stay visible on every tab while something is loaded.
3. **NEVER** cover content without the soft edge. *Because* text under a floating control looks broken.
4. **NEVER** glow. *Because* the play here continues something; it isn't the screen's next step.
5. **MUST** be the only control for what's playing: while its episode plays, the hero tile on Podcasts drops its lit play (part 45, 20 Oct). *Because* two plays for one episode is a puzzle.

## States
| State | What it looks like | Motion | Haptic |
|---|---|---|---|
| rest (paused) | as above, play shown | none | none |
| playing | pause shown; hairline advances | `playMorph` | none |
| pressed (body) | 0.98; shadows tighten toward contact | 80 / 240 | none |
| pressed (play well) | 0.94; well to `surface.washPressed` | 80 / 240 | `haptic.press` |
| pending (buffering) | the play well shows a 2pt ring turning; time holds | `spin` 900ms | none |
| error (failed) | subline "couldn't play · tap to retry" in `status.dangerText`; play becomes icon `retry` | blur-in 220ms | `haptic.error` |
| offline | plays if downloaded; otherwise failed with "offline" | — | — |
| focused | 2pt `border.focus` around the pill | — | — |
| disabled, empty, loading | not applicable: it only exists when something is loaded | — | — |
| dark | body dark `background.raised` at 92%, inner stroke white 8%, shadows black 45%; artwork unchanged | — | — |

## Motion
- Appears: rises 12pt and fades in (standard curve, 280ms) the first time something plays.
- Swipe left / right on it: skips back / forward 15, content shifting 4pt and returning.
- Swipe down: hides it (it stays in Podcasts); `haptic.select`.
- Tab change: it does not move; everything changes under it.

## Lock screen and background
Now-playing shows the episode title, "retrospect" as the artist, the artwork, skip 15 / 30, and the chapter as the subtitle. Audio continues when the app closes (the brief included).

## Accessibility
- [ ] One element: "now playing, the week you kept choosing the river, 4 minutes 12 seconds in; double-tap to open"; custom actions: play/pause, skip back 15.
- [ ] Dynamic Type (accessibility 3): grows to 80 tall; the subline hides (it is in the accessible label); title wraps to two lines.
- [ ] Reduce Motion: appears with a fade only; no swipe shift.
- [ ] Reduce Transparency: body fully opaque; the scroll edge becomes a solid band.
- [ ] Increase Contrast: hairline becomes 1pt `border.control`; progress 2 → 3pt.
- [ ] Contrast: subline 5.2 : 1; play icon 5.8 : 1 on wash.

## Taken out
- The skip-back button: a swipe does it, and one control is calmer than two.
- The rolling time in the subline: the progress hairline already shows where you are.

## Edge cases
- Long title → ellipsis; full in VoiceOver and the player.
- Two things queued → shows the current one only; the queue lives in the player.
- Small phone → width is screen − 2 × 20; artwork stays 44.

## Tokens
`background.raised`, `material.bar`, `material.reducedTransparency`, `depth.stroke.inner/innerTop/outer`, `depth.shadow.ambient/cast/contact`, `depth.tint.artwork`, `gradient.meshMorning/meshEvening/meshQuiet/fadeToCanvas`, `surface.wash/washPressed`, `player.progress`, `text.primary/label`, `status.dangerText`, `border.focus/control`, `size.miniPlayer`, `radius.control`, `motion.duration.playMorph/spin`, `haptic.press/select/error`.
