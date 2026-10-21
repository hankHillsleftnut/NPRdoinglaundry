# Retrospect tokens v1: proposal

20 October 2026. **Tokens first, then the design system.** This takes the principles from the [Queue study](./queue-reference/tokens.md) and applies them to Retrospect's own identity: warm paper tones and a serif display face. The starting point is the existing `RetroTokens.swift` foundation (branch `design/token-foundation`, bound to Figma file xWR4UGYyQEiWPrQ2SjCRed). Design and brand decisions are yours; each one is marked **▶ your call**, with my recommendation.

---

## Principles (from Queue, kept)

1. **The content carries the colour.** Queue lets podcast artwork colour the screen. For Retrospect, the content is your life: your episode artwork, the people in it, your photos. The UI stays quiet.
2. **One accent, one job.**
3. **A display face with personality, against quiet text.**
4. **Space instead of lines:** generous margins, almost no dividers.
5. **Mono numbers where time ticks.**

---

## 1. Colour

**Today:** five warm surfaces, six text greys (two near-identical blacks, #1E1E1E vs #121212), white hairline strokes, and one dark "ink" accent. No dark mode set.

| Role | Proposed | From today | Note |
|---|---|---|---|
| `bg.canvas` | `#F4F2EE` | `surfaceCard` | one canvas everywhere, like Queue's single #F8F8F8 |
| `bg.raised` | `#F7F3EE` | `surfaceControl` | floating things: search, mini-player |
| `fill.control` | `#EAE7E3` | `surfaceRow` | pills, round buttons |
| `fill.control.pressed` | `#EDE9E4` | `surfaceControlPressed` | |
| `fill.track` | `#E4E4E2` | `surfacePage` | progress tracks, idle bars |
| `text.primary` | `#121212` **or** `#1E1E1E` | the two blacks | **▶ your call:** I'd keep **#121212** (more contrast against warm paper) |
| `text.secondary` | `#7C7975` | `textSecondary` | |
| `text.muted` | `#9E9E9E` | `textMuted` | |
| `text.faint` | `#C3C2BE` | `textFaint` | `textSelected` (#707070) merges into secondary |
| `accent` | **one colour** | `accentInk` (near-black) today | **▶ your call:** Queue's lesson is one accent with one job. Options: (a) keep ink: no colour at all, very calm; (b) one warm accent (e.g. a terracotta or amber) for the single primary action; (c) system blue. I'd recommend **(b)**. It gives the "play your episode" moment a colour without breaking the paper calm |
| `status.success` / `danger` | keep | | used only for status, never decoration |
| **Dark mode** | `bg.canvas.dark` ≈ `#151412` (warm black, like Queue's slightly blue #131418 but warm), `fill.control.dark` ≈ `#2E2C29` | none today | **▶ your call:** do dark mode now, or after v1 |

## 2. Typography

**Today:** a serif display (Apple's New York, via `.serif`) and SF Pro for text. Sizes 11–16 for text; the display sizes are not tokenised.

| Token | Proposed | Note |
|---|---|---|
| `display.xl` | New York Bold, ~40 pt, tight line height (1.1) | the episode title moment, like Queue's 44 pt headline |
| `display.l` | New York Semibold, ~30 pt | screen titles |
| `headline` | SF Pro Semibold 17 pt | list titles |
| `body` | SF Pro Regular 16 pt | as today |
| `subhead` | SF Pro Medium 16 pt | as today (`geistSubheadline`) |
| `caption` | SF Pro Regular 14 pt | as today |
| `small` | SF Pro Regular 13 pt | as today |
| `tab` | SF Pro Medium 11 pt | as today |
| `numeric` | **SF Mono** 12–13 pt | **new:** times in the player, counts in insights |

**▶ your call:** keep the serif display (my recommendation: it's Retrospect's warmth and distinct from every podcast app), or try a condensed sans like Queue's.

## 3. Spacing: from 15 values to 9

A 4-point scale. The four values the foundation flagged as accidental go:

`4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 48`

| Today | Becomes |
|---|---|
| 6, 9, 10 | 8 or 12 (decided per screen, with a before/after) |
| 13, 14, 15 | 12 or 16 |
| 18 | 16 or 20 |
| 28, 35 | 32 |

- `margin.screen`: **24 pt** (today mostly 20). **▶ your call:** Queue uses 34, which reads luxurious but costs width; 24 is the middle ground I'd recommend.
- `gap.row`: **32 pt** between list items, with space instead of dividers.

## 4. Radius: from 10 values to 5

`8 · 12 · 16 · 22 · capsule`, mapped as 2/4 → 8 (or square), 10 → 12, 14 → 16, 20 → 22, 44 → capsule. Artwork is about 20% of its size, as in Queue.

## 5. Elevation: keep the 6, retire the 38 one-offs

The foundation's six recurring shadows stay. The 38 inline one-offs move to the nearest of the six, screen by screen, with a before/after.

---

## What happens after you decide

1. Your four calls: primary black · accent · serif or sans display · margin.
2. I update `RetroTokens.swift` (still the one write site) and the Figma variables to match, keeping old names as aliases so nothing breaks at once.
3. Then the design system: components built only from tokens (episode row, player, pills, mini-player, insights), each a before/after for you to approve.
