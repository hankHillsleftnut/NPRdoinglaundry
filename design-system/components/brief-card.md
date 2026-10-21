---
name: brief-card
kind: component
platform: iOS (SwiftUI)
drawn: Paper · components · 03 player pieces (not started, playing) · 05 states, dark and access (played, quiet, making, dark)
---

# brief card

Today's brief at the top of Journal: press play, it briefs you, and it keeps playing when you close the app.

## Use when
- The person has the daily brief on, at the top of Journal, once a day.

## Don't use when
- The weekly episode: it opens from Podcasts and the mini-player, not as a card.
- The brief is off: show nothing (no "turn on your brief" card).

## Anatomy (bottom to top)
1. **cast**: warm `0 6 16 −8` (`depth.shadow.cast`); **contact**: warm `0 1 1.5` (`depth.shadow.contact`). *card* tier.
2. **outer hairline**: 0.5 warm (`depth.stroke.outer`).
3. **body**: screen width minus margins (342 on a 390 phone), radius 20 (`radius.card`), padding 18, `background.raised`, a 2% top light.
4. **inner stroke**: white 85%, brighter top (`depth.stroke.inner/innerTop`).
5. **top line**: mono 12 `text.label`: "today's brief · tue 21 oct" left, "2 min" right (tabular).
6. **headline**: display serif 22/27, inky (`font.exposure.card`, tracking `font.tracking.card`), lowercase, up to three lines.
7. **play**: 44 round, the *compact glow* (gradient, lower edge, inner bloom, 1.5pt ring, no halo, grain), icon `play` 1.5pt right of centre. The screen's one lit object. Concentric with the card: 20 − 18 padding is under the 22 radius of the play, so the play sits as its own object, never tucked into the corner.
8. **what's in it**: one line, text 14 `text.secondary`.

## Rules
1. **MUST** keep playing in the background and on the lock screen.
2. **MUST** say what it's made of when opened ("why it's here").
3. **NEVER** show the card when the brief is off. *Because* an empty card nags.
4. **MUST** turn the play glow off while playing. *Because* the glow means "start", not "running".

## States
| State | What it looks like | Motion | Haptic |
|---|---|---|---|
| rest (not started) | as above | none | none |
| pressed (play) | 0.94, pressed gradient; the card itself does not move | 80 / 240 | `haptic.press` |
| pressed (card body) | card 0.98 | 80 / 240 | none |
| playing | the card does not change (founder, 20 Oct: "I still prefer this" over a card that morphs); the mini-player and the player sheet show playback | — | none |
| played | headline `text.secondary`; the artwork corner reads "played" (Geist 500 12); the play becomes a raised replay well (`retry`), no glow | 200ms | none |
| quiet day (empty) | one line in the serif ("nothing much moved. enjoy the quiet."), no play, no bars | — | — |
| making (loading) | a compact row, not the full card (founder, 20 Oct: "much smaller"): a 40 `surface.skeleton` well (`radius.panel`) with the `brief` glyph in `icon.muted`, then "today's brief" (Geist 500 14) over "being made · ready by 8:30" (Geist 12 `text.label`); no play; it grows into the full card when the brief exists | shimmer on the well | none |
| pending (starting audio) | the play shows a ring turning; the card stays | `spin` | none |
| error | "couldn't load today's brief" in Geist 500 12 `status.dangerText`; a neutral pill "try again" with `retry`; the artwork panel is a plain wash | blur-in 220ms | `haptic.error` |
| offline | plays if downloaded; otherwise "it'll be here when you're back online", no play | — | — |
| focused | drawn by iOS (Full Keyboard Access); the play is a separate focus stop; not drawn on boards (founder, 20 Oct) | — | — |
| disabled | not applicable: a card that can't play shows quiet, making, error or offline instead | — | — |
| dark | body `background.raised` (dark), inner stroke white 8%, casts black 45%; the sky ring stays 4 : 1 on dark | — | — |

## Accessibility
- [ ] Two elements: the card ("today's brief, the week you kept choosing the river, 2 minutes; double-tap to open") and play ("play today's brief").
- [x] Dynamic Type (accessibility 3): every line grows (headline `type.ax3.xl` 44/52, subline `type.ax3.md` 36/43, label `type.ax3.sm`); the play stays 44 and moves under the text. Drawn in 02b part 03.
- [x] Reduce Motion: cross-fades 140ms (motion only; nothing to draw).
- [x] Reduce Transparency: no change (opaque).
- [x] Increase Contrast: a 1pt `border.control` ring replaces the stroke stack; played headline stays `text.primary`. Drawn.
- [ ] Contrast: top line 5.2 : 1; headline 15 : 1; playing ring 4 : 1.

## Taken out
- While playing it had a ring, coloured text, a rolling time *and* three segment bars: now the ring and "playing · 2 of 3". The bars and the time said the same thing again.
- The check beside "played": the word is enough.

## Edge cases
- Very long headline → three lines, then ellipsis; the full line in the player.
- Played on another device → shows played.
- Midnight passes while open → the card stays until the next pull or app open; it never swaps under the person's finger.

## Tokens
`background.raised`, `depth.stroke.inner/innerTop/outer`, `depth.shadow.contact/cast`, `depth.tint.primary`, `accent.border/text`, `glow.primary.*`, `surface.wash/skeleton/track`, `player.progress`, `text.primary/secondary/label`, `status.dangerText`, `border.focus/control`, `font.family.display/text/mono`, `font.exposure.card`, `font.tracking.card`, `radius.card`, `size.briefCard.minHeight`, `motion.duration.shimmer/spin`, `haptic.press/error`.
